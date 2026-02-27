{
  pkgs,
  nix-crypto,
  ...
}:
let
  inherit (nix-crypto) openssl;
  pk-rsa = openssl.private-key { 
    attrs = {
      vault = "openssl";
      name = "openssl-test-key";
    };
    type = "rsa";
  };
in
  {
    dummy = pk-rsa.public-key-pem;
  }
