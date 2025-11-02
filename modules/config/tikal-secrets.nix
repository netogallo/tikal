{ lib, config, tikal-secrets, ... }:
let
  inherit (lib) types mkOption;
  secret = {
    text = mkOption {
      types = types.str;
      description = ''
        This option is a bash program that generates the secret.
        This program will be executed in order to generate the
        secret and then the output will be encrypted using the
        nahual's public key. The following env variables will
        be available durring the execution of the program:
          - $nahual_name: The name of the nahual for which the
            secret is being generated.
          - $out: The output directory. Note that this will
            contain two important directories:
            - private: "$out/private"
            - public: "$out/public"
        The program should place all secrets in the 
        private directory as this will get encrypted
        by the nahual's key before landing on the
        Nix store. The public directory can be used
        to save any public data that might be generated
        alongside the secret (ie. public keys).
      '';
    };
  };
  is-enabled = true;
  nahuales = lib.attrNames config.nahuales;
  config-all-nahuales = config.secrets.all-nahuales;
  to-all-nahuales-secret = name: { text, ... }:
    let
      to-nahual-secret = nahual: {
        ${nahual} = {
          derive =
            tikal-secrets.to-nahual-secret
            { inherit nahual text; }
          ;
          key = {
            module = "tikal-secrets";
            inherit name nahual;
          };
        };
      };
    in
      lib.map to-nahual-secret nahuales
  ;
  locks-all-nahuales = do [
    config-all-nahuales
    "$>" lib.mapAttrs to-all-nahuales-secret)
    "|>" lib.attrValues
    "|>" lib.foldAttrs (item: acc: [item] ++ acc) []
  ];
  to-nahual-secrets-module = name: secrets:
    let
      is-enabled = lib.length secrets > 0;
    in
      {
        config = mkIf is-enabled {
          system.activationScripts.tikal-secrets-activate =
            tikal-secrets.activation-script-for secrets;
        };
      }
  ;
  modules-all-nahuales =
    lib.mapAttrs to-nahual-secrets-module locks-all-nahuales;
  secrets-locks = lib.concat (lib.attrValues locks-all-nahuales);
  secrets-modules = modules-all-nahuales;
in
  {
    options.secrets = {
      all-nahuales = mkOption {
        type = types.attrsOf (types.submodule secret);
        description = ''
          A secret that will be generated for all the nahuales
          in the tikal universe. Note that the secret will be
          unique per nahual, but the logic to derive said
          secret will be shared among all nahuales.
        '';
      };
    };

    config = mkIf is-enabled {
      store-lock.items = secrets-locks;
      tikal.build.modules = secrets-modules;
    };
  }
