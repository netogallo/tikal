{
  pkgs,
  tikal,
  tikal-store-lock,
  tikal-log,
  tikal-flake-context,
  tikal-nixos-context,
  ...
}:
let
  inherit (tikal-store-lock.universe) get-resource-path;
  inherit (tikal-log) logger;
  inherit (tikal.store) secrets;
  inherit (tikal.prelude.test) with-tests;
  inherit (tikal-flake-context.tikal-secrets) tikal-public-key;
  inherit (tikal-nixos-context.tikal-secrets) tikal-private-key tikal-secrets-store-directory;

  to-nahual-secret-derivation = { name, nahual, text, user ? null, group ? null }:
    let
      tikal-key = tikal-public-key { inherit nahual; };
    in
      secrets.to-nahual-secret {
        inherit name tikal-key text;
        post-decrypt = [
          (secrets.set-ownership { inherit user group logger; })
        ];
      }
  ;

  get-secret-key = { name, nahual }: {
    module = "tikal-secrets";
    inherit name nahual;
  };

  to-nahual-secret = { name, nahual, text }:
    {
      derive =
        to-nahual-secret-derivation
        { inherit name nahual text; }
      ;
      key = get-secret-key { inherit name nahual; };
    }
  ;

  get-secret-store-path = { name, nahual }@key:
    get-resource-path (get-secret-key secret-key)
  ;

  get-secret-public-path = key:
    "${get-secret-store-path key}/public"
  ;

  get-secret-private-path = { name }@key:
    "${tikal-secrets-store-directory}/name"
  ;

  to-decrypt-script = { name, nahual, ... }:
    lock.to-decrypt-scritp {
      inherit tikal-private-key logger;
      secret = get-secret-store-path { inherit name nahual; };
      dest = get-secret-private-path { inherit name; };
    }
  ;

  secrets-activation-script = secrets:
    let
      decrypt-secret = { key, ... }: to-decrypt-script key;
      decrypt-secrets = do [
        secrets
        "$>" map decrypt-secret
        "|>" lib.concatStringSep "\n"
      ];
      post-decryption-scripts = "";
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
        cp /run/keys/tikal/id_tikal "${tikal-private-key}"
      fi

      ${decrypt-scripts}
      ${post-decryption-scripts}
      ''
  ;
in
  with-tests
  {
    inherit to-nahual-secret get-secret-private-path get-secret-store-path;
  }
  {
    tikal.modules.tikal-secrets = {};
  }

