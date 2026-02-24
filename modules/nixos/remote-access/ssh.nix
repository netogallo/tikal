{ config, lib, tikal-secrets, ... }:
let
  inherit (config.tikal.openssh) key-name;
  inherit (config.tikal.meta) nahuales;
  inherit (config.tikal.meta.nixos-context) tikal-user;
  tikal-ssh-secret-name = config.tikal.openssh.secret-name;

  /**
  Compute the path where the public ssh keys for all nahuales in
  the universe will be available. The keys are generated as part of the
  "sync" script. An ssh key is generated for the "tikal-root" user of
  every nahual. The public key will be availabe in the store. The function
  below recovers the store path for the ssh public key of every nahual.
  */
  tikal-ssh-key = nahual: _config:
    let
      path = tikal-secrets.get-secret-public-path { 
        name = tikal-ssh-secret-name;
        inherit nahual;
      };
    in
      "${path}/${key-name}.pub"
  ;

  tikal-ssh-keys = lib.mapAttrs tikal-ssh-key nahuales;

  public-ssh-keys = lib.attrValues tikal-ssh-keys;
in
  {
    imports = [ ../../shared/remote-access/ssh.nix ];
    config = {
      services.openssh = {
        enable = true;
        settings.PasswordAuthentication = false;
      };
      users.users.${tikal-user}.openssh.authorizedKeys.keyFiles = public-ssh-keys;
    };
  }
