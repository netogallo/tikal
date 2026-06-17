{ ... }:
let
  x = 42;
in
  {
    config = {
      networking.nftables.firewall = {
        enable = true;
        snippets.nnf-common.enable = false;
      };
    };
  }
