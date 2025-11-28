{ ... }:
rec {

  # These are the paths used to store the decrypted tikal keys.
  # The tikal activation scripts will check these directories
  # and move the keys in these directories to their corresponding
  # location.
  tikal-decrypt-keys-directory = "/run/keys/tikal";
  tikal-decrypt-master-key-file = "${tikal-decrypt-keys-directory}/id_tikal";
}
