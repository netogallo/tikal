{
  pkgs
, nahual-pkgs
, config
, lib
, tikal
, tikal-secrets
, ...
}:
let
  inherit (lib) types mkIf mkOption;
  inherit (pkgs) openssh;
  key-name = "id_ecdsa";
  tikal-ssh-secret-name = "tikal-ssh";

  gen-key-script =
    ''
    mkdir -p "$public"
    mkdir -p "$private"
    ${openssh}/bin/ssh-keygen -N "" -t ecdsa -f "$private/${key-name}"
    cp "$private/${key-name}.pub" "$public"
    ''
  ;

  tikal-ssh-key = nahual: _config:
    let
      path = tikal-secrets.get-secret-public-path { 
        name = tikal-ssh-secret-name;
        inherit nahual;
      };
    in
      "${path}/${key-name}.pub"
  ;

  tikal-ssh-keys = lib.mapAttrs tikal-ssh-key config.nahuales;

  to-ssh-module = name: _config:
    # This nixos module performs the following actions
    # on each of the nahuales.
    # 1. Enables openssh
    # 2. Adds the public keys of all nahuales to the "authorized_keys" file
    #    of the "tikal" user.
    let
      public-ssh-keys = lib.attrValues tikal-ssh-keys;
    in
      {
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
      secrets.all-nahuales = {
        ${tikal-ssh-secret-name} = {
          text = gen-key-script;
          user = "nixos";
          group = "nixos";
        };
      };
      tikal.build.modules = lib.mapAttrs to-ssh-modules config.nahuales;
    };
  }

