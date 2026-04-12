{ ... }:
let
  imports = [ ../../shared/remote-access/ssh.nix ];
in
{
  inherit imports;
}
