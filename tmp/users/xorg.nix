{
  tikal,
  groupname ? "tikal-xorg"
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
rec {
  meta = {
    inherit groupname;
  };
  users.groups."${groupname}" = {
    gid = 6000;
  };
  systemd.services."tikal-xinit@" = {
    serviceConfig = {
      ExecStart = "${service-script}/bin/tikal-xinit";
      User = "%i";
      Group = "tikal-xorg";
    };
  };
  security.sudo.extraRules = [
    {
      commands = [
      	{
          command = "${service-script}";
	  options = [ "NOPASSWD" ];
	}
      ];
      groups = [ "${groupname}" ];
    }
  ];
  apply = nixos: nixos // {
    users = nixos.users // { groups = nixos.users.groups // users.groups; };
    systemd = nixos.systemd // { services = nixos.systemd.services // systemd.services; };
    security = nixos.security // {
      sudo = nixos.security.sudo // {
        extraRules = nixos.security.sudo.extraRules ++ security.sudo.extraRules;
      };
    };
  };
}
