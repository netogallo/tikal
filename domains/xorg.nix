{
  tikal,
}:
let
  inherit (tikal) nixpkgs;
  inherit (nixpkgs) bash hexdump libinput;
  inherit (nixpkgs.xorg) twm xinput xauth xinit;
  service-script = nixpkgs.writeShellApplication {
    name = "tikal-xinit";
    runtimeInputs = with nixpkgs; [ xauth hexdump twm xterm xinit ];
    text =''
    startx ${xinit-script}
    '';
  };
  xinit-script = nixpkgs.writeScript "xinitrc"
    ''
    echo "DISPLAY=$DISPLAY"
    echo "XAUTHORITY=$XAUTHORITY"
    twm
    '';
in
tikal.domain.new ({service, ...}: {
  systemd.services."tikal-xinit" = service {
    start = "${xinit-script}/bin/tikal-xinit"; 
  };
};
