{ ... }:
let
  enable = true;
in
  {
    config = {
      networking.nftables.firewall = {
        inherit enable;
        snippets.nnf-common.enable = true;
      };
    };
  }
