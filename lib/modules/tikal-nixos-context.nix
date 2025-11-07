# This module contains all the constants relating to Tikal nixos images.
# This usually means hardcoded paths which hold important values related
# to Tikal.
{
  tikal-foundations
}:
{
  tikal-secrets = with tikal-foundations.paths; rec {
    tikal-private-key = tikal-main;
    tikal-secrets-root-directory = store-secrets;
    tikal-secrets-store-directory = "${tikal-secrets-root-directory}/store";
  };
}
