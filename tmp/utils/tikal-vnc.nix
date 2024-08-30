{
  tikal
}:
let
  inherit (tikal) nixpkgs;
in
nixpkgs.stdenv.mkDerivation rec {
  name = "tikal-vnc";
  src = ./tikal-vnc;
  buildInputs = with nixpkgs; [
    envsubst
    weston
    makeWrapper
    libpam-wrapper
    openssl
  ];
  pamd-file = nixpkgs.writeTextFile {
    name = "weston-remote-access";
    text = ''
    auth       required    ${nixpkgs.libpam-wrapper}/lib/pam_wrapper/pam_matrix.so passdb=$PASSDB
    account    required    ${nixpkgs.libpam-wrapper}/lib/pam_wrapper/pam_matrix.so passdb=$PASSDB
    password   required    ${nixpkgs.libpam-wrapper}/lib/pam_wrapper/pam_matrix.so passdb=$PASSDB
    session    required    ${nixpkgs.libpam-wrapper}/lib/pam_wrapper/pam_matrix.so passdb=$PASSDB
    '';
  };
  buildPhase = "";
  installPhase = ''
  mkdir -p $out/bin
  mkdir -p $out/share

  cp tikal-vnc.sh $out/share
  chmod +x $out/share/tikal-vnc.sh
  makeWrapper $out/share/tikal-vnc.sh $out/bin/tikal-vnc \
  	--prefix PATH : ${nixpkgs.openssl}/bin:${nixpkgs.envsubst}/bin \
  	--prefix LD_LIBRARY_PATH : ${nixpkgs.libpam-wrapper}/lib:${nixpkgs.libpam-wrapper}/lib/pam_wrapper \
	--set PAM_TEMPLATE ${pamd-file} 

  '';
}
