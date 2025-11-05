{ pkgs, lib, test, trace, string }:
let
  inherit (trace) debug-print;
  inherit (lib) lists strings;
  extension-of-checked = options: path:
    let
      name = builtins.baseNameOf path;
    in
      lib.lists.findFirst
      (ext: string.is-suffix-of ".${ext}" name)
      (throw "The file '${path}' does not have the extensions '${debug-print options}'")
      options
  ;
  is-file-reference = file:
    (lib.isPath file || lib.isDerivation file) && lib.pathIsRegularFile file
  ;
  assert-path = lib.makeOverridable(
    { is-file, is-directory, error }: path':
    let
      check =
        (lib.isPath path' || lib.isDerivation path')
        && (lib.pathIsRegularFile path' || !is-file)
        && (lib.pathIsDirectory path' || !is-directory)
      ;
    in
      if check
      then path'
      else throw (error { path = path'; path-as-string = debug-print path'; }))
    {
      is-file = false;
      is-directory = false;
      error = { path, ... }: "The value '${debug-print path}' is not a valid path.";
    }
  ;
in
  test.with-tests
  {
    inherit extension-of-checked is-file-reference;
  }
  {
    prelude.path = {
      extension-of-checked = {
        "it returns the extension if matches" = { _assert, ... }: _assert.all [
          (_assert.eq "exe" (extension-of-checked [ "jpg" "exe" ] "file.exe"))
          (_assert.eq "exe" (extension-of-checked [ "jpg" "exe" ] "/abs/path/file.exe"))
          (_assert.eq "exe" (extension-of-checked [ "jpg" "exe" ] "rel/path/file.exe"))
          (_assert.eq "exe" (extension-of-checked [ "jpg" "exe" ] ./rel/path/file.exe))
        ];

        "it throws error if the extension doesn't match" = { _assert, ... }: _assert.all [
          (_assert.throws (extension-of-checked [ "jpg" "exe" ] "file.exe.not"))
          (_assert.throws (extension-of-checked [ "jpg" "exe" ] "file.notexe"))
        ];
      };

      is-file-reference = {
        "it is a reference to a file" = { _assert, ... }: _assert.all [
          (_assert.true (is-file-reference ./path.nix))
          (_assert.true (is-file-reference (pkgs.writeText "test" "test")))
        ];
      };
    };
  }
