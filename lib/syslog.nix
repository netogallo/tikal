{ pkgs, ... }:
let
  with-logger = logger:
    if logger == null
    then "${pkgs.coreutils}/bin/echo"
    else "${logger}/bin/tikal-log"
  ;
in
  {
    inherit with-logger;
  }
