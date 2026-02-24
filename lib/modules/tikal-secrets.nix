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
  inherit (tikal-store-lock) get-resource-path;
  inherit (tikal.store) secrets;
  inherit (tikal.prelude) do;
  inherit (tikal.prelude.test) with-tests;
  inherit (tikal-flake-context.tikal-secrets) tikal-public-key;
  inherit (tikal-nixos-context.tikal-secrets) tikal-private-key tikal-secrets-store-directory;

  to-nahual-secret-derivation =
    { name, nahual, text, user ? null, group ? null }:
    let
      tikal-key = tikal-public-key { inherit nahual; };
    in
      secrets.to-nahual-secret {
        inherit name tikal-key text;
        post-decrypt = [
          (secrets.set-ownership { inherit user group; })
        ];
      }
  ;

  get-secret-key = { name, nahual }: {
    module = "tikal-secrets";
    inherit name nahual;
  };

  to-nahual-secret = { name, nahual, text, user ? null, group ? null }:
    {
      derive =
        to-nahual-secret-derivation
        { inherit name nahual text; }
      ;
      key = get-secret-key { inherit name nahual; };
    }
  ;

  get-secret-store-path = key:
    get-resource-path (get-secret-key key)
  ;

  get-secret-public-path = key:
    "${get-secret-store-path key}/public"
  ;

  get-secret-private-path = { name }@key:
    "${tikal-secrets-store-directory}/${name}"
  ;

  to-decrypt-script = { name, nahual, ... }:
    secrets.to-decrypt-script {
      inherit tikal-private-key;
      secret = get-secret-store-path { inherit name nahual; };
      dest = get-secret-private-path { inherit name; };
    }
  ;

  secrets-activation-script = secrets:
    let
      decrypt-secret = { key, ... }: to-decrypt-script key;
      decrypt-secrets =
        lib.concatStringsSep "\n" (map decrypt-secret secrets);
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

      ${decrypt-secrets}
      ${post-decryption-scripts}
      ''
  ;
  locks-all-nahuales = { nahuales, all-nahuales }:
  let
    to-all-nahuales-secret = name: { text, user, group, ... }:
    let
      to-nahual-secret-config = nahual: {
        ${nahual} =
          to-nahual-secret {
            inherit name nahual text user group;
          };
      };
    in
      lib.map to-nahual-secret-config nahuales
    ;
  in
    do [
      all-nahuales
      "$>" lib.mapAttrs to-all-nahuales-secret
      "|>" lib.attrValues
      "|>" lib.concatLists
      "|>" lib.foldAttrs (item: acc: [item] ++ acc) []
    ]
  ;
in
  with-tests
  {
    inherit to-nahual-secret get-secret-private-path
    get-secret-store-path secrets-activation-script
    get-secret-public-path locks-all-nahuales;
  }
  {
    tikal.modules.tikal-secrets = {};
  }

