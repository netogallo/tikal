{
  pkgs
, nahual-pkgs
, config
, lib
, tikal
, ...
}:
let
  inherit (lib) types mkIf mkOption;
  inherit (pkgs) openssh;
  inherit (nahual-pkgs config.nahuales) tikal-secrets;
  log = tikal.prelude.log.add-context { file = ./ssh.nix; };
  key-name = "id_ecdsa";
  gen-nahual-ssh-keys = name: config:
    let
      log' = log.add-context { nahual = name; function = "nahual-ssh-keys"; };
      ssh-keys = tikal-secrets.${name}.secret-folders {
        tikal = {
          # This generates an ssh key pair. The private key
          # will be encrypted before it is written to the store
          # using the nahual's master public key.
          script = ''
            mkdir -p "$public"
            mkdir -p "$private"
            ${openssh}/bin/ssh-keygen -N "" -t ecdsa -f "$private/${key-name}"
            cp "$private/${key-name}.pub" "$public"
          '';
          
          private = {
            user = "nixos";
            group = "users";
          };
        };
      };
    in
      log'.log-value "ssh keys" ssh-keys
  ;

  nahual-ssh-keys = lib.mapAttrs gen-nahual-ssh-keys config.nahuales;

  to-ssh-module = name: config:
    # This nixos module performs the following actions
    # on each of the nahuales.
    # 1. Enables openssh
    # 2. Adds the public keys of all nahuales to the "authorized_keys" file
    #    of the "tikal" user.
    let
      nahual-ssh-key = nahual-ssh-keys.${name};
      public-ssh-keys =
        lib.mapAttrsFlatten 
        (_: ssh-key: "${ssh-key.secrets.tikal.public}/${key-name}.pub")
        nahual-ssh-keys
      ;
    in
      {
        imports = [ nahual-ssh-key.module ];
        config = {
          services.openssh.enable = true;
          users.users.nixos.openssh.authorizedKeys.keyFiles = public-ssh-keys;
        };
      }
  ;
  to-ssh-modules = name: config: lib.map (mod: mod name config) [to-ssh-module];
  
  tikal-ssh-config = config.remote-access.openssh;
in
  {
    options = {
      remote-access.openssh = {
        enable = mkOption {
          default = false;
          type = types.bool;
          description = "Enable ssh access amongst nahualees.";
        };
      };
    };

    config = mkIf tikal-ssh-config.enable {
      tikal.build.modules = lib.mapAttrs to-ssh-modules config.nahuales;
    };
  }

