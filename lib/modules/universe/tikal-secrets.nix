{ pkgs, lib, tikal, nahual-config, tikal-foundations, tikal-log, ... }:
let
  inherit (tikal) prelude;
  tikal-key = nahual-config.flake.public.tikal-keys.tikal_main_pub;
  tikal-private-key = nahual-config.flake.public.tikal-keys.tikal_main_pub;
  tikal-paths = tikal-foundations.paths;
  log = tikal-log.log;
  create-secret-folder = { name, script }:
    let
      mkSecret = pkgs.writeScript "name" script;
    in
      pkgs.runCommandLocal name {} ''
        WORKDIR=$(mktemp -d)
        PUBLIC="$WORKDIR/public"
        PRIVATE="$WORKDIR/private"
        out="$WORKDIR" public="$PUBLIC" private="$PRIVATE" ${mkSecret}
        mkdir -p "$out"
        ${pkgs.gnutar}/bin/tar -cC "$PRIVATE" . | ${pkgs.age}/bin/age -R "${tikal-key}" -o "$out/private" 
        mv "$WORKDIR/public" "$out/public"
        rm -rf "$WORKDIR"
      ''
  ;
  to-secret-store-path = store-path:
    let
      dest = prelude.drop-store-prefix.override { strict = true; } store-path;
    in
      "${tikal-paths.store-secrets}/${dest}"
  ;

  # The store secrets in tikal is supported by two modules. First we
  # have the general purpose secrets module that implements the logic
  # to decrypt the secrets from the store once a nixos configuration
  # is activated. This module is inspired by agenix. This general
  # purpose module offers a config item where secrets can be listed.
  #
  # The second module is specific to a set of secrets. It relies
  # on the first module to provide the decryption logic and alos
  # relies on the first module's config to enumerate what secrets
  # need to be decrypted.
  secrets-module = { config, lib, pkgs, ... }:
    let
      inherit (lib) types mkOption;
      inherit (pkgs) age gnutar;
      secret-files = config.tikal.secrets.files;
      mk-decrypt-folder-script = store-path:
        let
          dest = to-secret-store-path store-path;
        in
          ''
          rm -rf "${dest}"
          mkdir -p "${dest}"
          ${log} --tag=secrets -d "Decrypging '${dest}' from '${store-path}/private' using '${tikal-paths.tikal-main}'"
          ${age}/bin/age -d -i "${tikal-paths.tikal-main}" "${store-path}/private" | ${gnutar}/bin/tar -xC "${dest}"

          if [ "$?" != 0 ]; then
            DIR=$(dirname "${tikal-paths.tikal-main}")
            ${log} --tag=secrets -e "Decryption failed for '${dest}' using key '${tikal-paths.tikal-main}'"
          fi
          ''
      ;
      decrypt-scripts = prelude.do [
        secret-files
        "$>" lib.map mk-decrypt-folder-script
        "|>" lib.concatStringsSep "\n"
      ];
    in
      {
        options = {
          tikal.secrets.files = mkOption {
            type = types.listOf types.string;
            description = ''
            List of encrypted files in the nix store that will be decrypted
            using the tikal master key on boot.
            '';
          };
        };

        config = {
          # Create a ramfs mount point where the decrypted files
          # are to be stored.
          # Obtained from agenix: https://github.com/ryantm/agenix/blob/531beac616433bac6f9e2a19feb8e99a22a66baf/modules/age.nix#L28 
          system.activationScripts.tikal-secrets-activate = {
            #enable = true;
            text = ''
              # Ensure the secrets folder exits and mount if not
              mkdir -p "${tikal-paths.store-secrets}"
              grep -q "${tikal-paths.store-secrets} ramfs" /proc/mounts ||
              mount -t ramfs none "${tikal-paths.store-secrets}" -o nodev,nosuid,mode=0751

              # We destroy old secrets rather than mantaining "generations" as
              # done by agenix. The Agenix generations are transient and get reset
              # after every reboot anyways. Nixos generations would not be affected
              # as the secrets will remain (encrypted) in the nix-store and therefore
              # restored upon activation of said generation.
              (cd "${tikal-paths.store-secrets}" && rm -rf *)

              if [ ! -f "${tikal-paths.tikal-main}" ]; then
                echo "Tikal master key is missing, restore it."
                DIR=$(dirname "${tikal-paths.tikal-main}")
                mkdir -p "$DIR"
                cp /run/keys/tikal/id_tikal "${tikal-paths.tikal-main}"
              fi

              ${decrypt-scripts}
            '';
          };
        };
      }
  ;
  secret-folders = folders:
    let
      encrypted = prelude.do [
        folders
        "$>" lib.mapAttrs (name: { script }: create-secret-folder { inherit name script; })
        "|>" lib.mapAttrs (_: drv: "${drv}")
      ];
      module = {
        imports = [ secrets-module ];
        config = {
          tikal.secrets.files = lib.attrValues encrypted;
        };
      };
      to-secret = _: path:
        {
          private = to-secret-store-path path;
          public = "${path}/public";
        }
      ;
    in
      {
        inherit module;
        secrets = lib.mapAttrs to-secret encrypted; 
      }
  ;
in
{
  inherit secret-folders;
}
