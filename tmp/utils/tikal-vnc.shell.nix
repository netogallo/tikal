{
  tikal,
  nixpkgs ? tikal.nixpkgs,
  tikal-vnc ? tikal.utils.tikal-vnc
}:
nixpkgs.mkShellNoCC {
  name = "tikal-vnc-shell";
  buildInputs = with nixpkgs; [ novnc tikal-vnc x11vnc ];
}

