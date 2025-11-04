{ pkgs, tikal, tikal-log, tikal-flake-context, ... }:
let
  inherit (tikal-log) logger;
  inherit (tikal.store) secrets;
  inherit (tikal.prelude.test) with-tests;
  inherit (tikal-flake-context) public-key;

  to-nahual-secret = { name, nahual, text, user ? null, group ? null }:
    let
      tikal-key = public-key { inherit nahual; };
    in
      secrets.to-nahual-secret {
        inherit name tikal-key text;
        post-decrypt = [
          (secrets.set-ownership { inherit user group logger; })
        ];
      }
  ;
in
  with-tests
  {
    inherit to-nahual-secret;
  }
  {
    tikal.modules.tikal-secrets = {};
  }

