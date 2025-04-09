{ writeScript, tikal, ... }:
  let
    inherit (tikal) bash;
    sync-script = with bash.control; bash.script [
      (
        { PWD, ... }:
        let
          tikal-folder = "${PWD}/tikal";
        in
          [ (mkdir "-p" "${tikal-folder}") ]
      )
    ];
  in
    writeScript "sync" 
