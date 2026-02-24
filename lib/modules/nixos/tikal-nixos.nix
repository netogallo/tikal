{ tikal, tikal-flake-context, ... }:
let
  inherit (tikal) prelude;
  inherit (tikal-flake-context) flake-root;
  /**
  This function ensures that the given path has been correctly added to the
  universe flake. If the file is not part of the flake, context will be
  added to the error message.
  */
  get-public-file = { path, user, group, mode ? 640 }:
    let
      file-path-unchecked =
        if prelude.is-prefix "${flake-root}" path
        then path
        else "${flake-root}/${path}"
      ;
      error = "The public tikal file '${file-path-unchecked}' was not found in this flake. Did you forget to run 'sync' followed by 'git add .' before generating the nixos image?";
      file-type =
        builtins.addErrorContext error (builtins.readFileType file-path-unchecked);
      file-path =
        if file-type == "regular"
        then file-path-unchecked
        else throw "Expecting '${file-path-unchecked}' to be a file"
      ;
    in
      {
        inherit user group;
        source = file-path;
      }
  ;
in
  {
    inherit get-public-file;
  }
