{ pkgs, lib, tikal, nahual-config, tikal-foundations, tikal-log, ... }:
let
  inherit (tikal) prelude;
  tikal-key = nahual-config.flake.public.tikal-keys.tikal_main_pub;
  tikal-private-key = nahual-config.flake.public.tikal-keys.tikal_main_pub;
  tikal-paths = tikal-foundations.paths;
  log = tikal-log.log;
  post-decrypt-script-name = "post_decrypt";
  create-secret-folder = name: { script, private ? {} }:
    let
      mk-secret = pkgs.writeScript name script;

      # If a specific user/group is supplied, the
      # decrypted directory's ownership is changed
      # to reflect said user/group combination.
      set-ownership = { user ? null, group ? null }:
        let
          ownership =
            if user != null && group != null
            then [ "${user}:${group}" ]
            else if user != null
            then [ "${user}" ]
            else if group != null
            then [ ":${group}" ]
            else []
          ;
          to-ownership-script = owner: ''
            chown -R ${owner} "$private"
            ${log} --tag=secrets -d "Setting ownership of ${name} to ${owner}" 
          '';
        in
          prelude.do [
            ownership
            "$>" lib.map to-ownership-script
            "|>" lib.concatStringsSep "\n"
          ]
      ;
      post-decrypt = pkgs.writeScript "post-decrypt-${name}" ''
        ${set-ownership private}
        ${log} --tag=secrets -d "Finished running post-decrypt scripts for ${name}"
      '';
    in
      pkgs.runCommandLocal name {} ''
        WORKDIR=$(mktemp -d)
        PUBLIC="$WORKDIR/public"
        PRIVATE="$WORKDIR/private"
        out="$WORKDIR" public="$PUBLIC" private="$PRIVATE" ${mk-secret}
        mkdir -p "$out"
        ${pkgs.gnutar}/bin/tar -cC "$PRIVATE" . | ${pkgs.age}/bin/age -R "${tikal-key}" -o "$out/private" 
        mv "$WORKDIR/public" "$out/public"
        ln -s "${post-decrypt}" "$out/${post-decrypt-script-name}"
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
          else
            (cd "${dest}"; private="${dest}" ${store-path}/${post-decrypt-script-name})
          fi
          ''
      ;
      decrypt-scripts = prelude.do [
        secret-files
        "$>" lib.map mk-decrypt-folder-script
        "|>" lib.concatStringsSep "\n"
      ];
      mk-post-decryption-script = script:
        let
          script-bin = pkgs.writeScriptBin "post-decryption" script;
        in
          "${script-bin}"
      ;
      post-decryption-scripts = prelude.do [
        config.tikal.secrets.post-decryption-scripts
        "$>" lib.map mk-post-decryption-script
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
            default = [];
          };

          tikal.secrets.post-decryption-scripts = mkOption {
            type = types.listOf types.string;
            description = ''
            List of scripts to be run after all files have been
            decrypted. Theese scripts are called as part of the
            nixos "activationScripts", therefore ensure it is
            idempotent.
            '';
            default = [];
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

              # Set the permissions for the secret folder
              chown -R root:users "${tikal-paths.store-secrets}"
              chmod -R 755 "${tikal-paths.store-secrets}"

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
              ${post-decryption-scripts}
            '';
          };
        };
      }
  ;
  secret-folders = folders:
    let
      encrypted = prelude.do [
        folders
        "$>" lib.mapAttrs create-secret-folder
        "|>" lib.mapAttrs (_: drv: "${drv}")
      ];
      module = {
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
  inherit secret-folders secrets-module;
}
