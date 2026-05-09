{ pkgs, ... }:
let
  x = 42;
in
  {
    users.test-user-1 = {
      tikal.security.certificates.user-1 = {

        # Export the private-key of user-1 to
        # the specified locations.
        private-key = [
          ".config/user-1.key"
        ];
      };
    };
  }
