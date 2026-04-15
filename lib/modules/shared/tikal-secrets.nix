{
  pkgs,
  lib,
  tikal,
  tikal-store-lock,
  tikal-flake-context,
  tikal-nixos-context,
  ...
}:
let
  inherit (tikal.hardcoded) tikal-decrypt-master-key-file;
  inherit (tikal-store-lock) get-resource-path;
  inherit (tikal.store) secrets;
  inherit (tikal.prelude) do;
  inherit (tikal.prelude.test) with-tests;
  inherit (tikal-nixos-context.tikal-secrets) tikal-private-key tikal-secrets-store-directory;

  get-secret-key = { name, nahual }: {
    module = "tikal-secrets";
    inherit name nahual;
  };

  get-secret-store-path = key:
    get-resource-path (get-secret-key key)
  ;

  get-secret-public-path = key:
    "${get-secret-store-path key}/public"
  ;

  get-secret-private-path = { name }@key:
    "${tikal-secrets-store-directory}/${name}"
  ;

  to-decrypt-script = { key, secret }:
    let
      inherit (key) name nahual;
      set-ownership = secrets.set-ownership {
        inherit name;
        inherit (secret) user group;
      };
      post-decrypt = [ set-ownership ] ++ secret.post-decrypt;
    in
      secrets.to-decrypt-script {
        inherit tikal-private-key post-decrypt;
        secret = get-secret-store-path { inherit name nahual; };
        dest = get-secret-private-path { inherit name; };
      }
  ;

  secrets-activation-script = secrets:
    let
      decrypt-secrets =
        lib.concatStringsSep "\n" (lib.map to-decrypt-script secrets);
    in
      ''
      # Ensure the secrets folder exits and mount if not
      mkdir -p "${tikal-secrets-store-directory}"
      grep -q "${tikal-secrets-store-directory} ramfs" /proc/mounts ||
      mount -t ramfs none "${tikal-secrets-store-directory}" \
        -o nodev,nosuid,mode=0751

      # Set the permissions for the secret folder
      chown -R root:users "${tikal-secrets-store-directory}"
      chmod -R 755 "${tikal-secrets-store-directory}"

      # We destroy old secrets rather than mantaining "generations" as
      # done by agenix. The Agenix generations are transient and get reset
      # after every reboot anyways. Nixos generations would not be affected
      # as the secrets will remain (encrypted) in the nix-store and therefore
      # restored upon activation of said generation.
      (cd "${tikal-secrets-store-directory}" && rm -rf *)

      if [ ! -f "${tikal-private-key}" ]; then
        echo "Tikal master key is missing, restore it."
        DIR=$(dirname "${tikal-private-key}")
        mkdir -p "$DIR"
        cp "${tikal-decrypt-master-key-file}" "${tikal-private-key}"
      fi

      ${decrypt-secrets}
      ''
  ;
in
  with-tests
  {
    inherit get-secret-key get-secret-private-path
    get-secret-store-path secrets-activation-script
    get-secret-public-path;
  }
  {
    tikal.modules.tikal-secrets = {};
  }

