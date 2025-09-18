{ pkgs, lib, test, trace, string }:
let
  inherit (lib) lists strings;
  extension-of-checked = options: path:
    let
      name = builtins.baseNameOf path;
    in
      lib.lists.findFirst
      (ext: string.is-suffix-of ".${ext}" name)
      (throw "The file '${path}' does not have the extensions '${trace.debug-print options}'")
      options
  ;
  is-file-reference = file:
    (lib.isPath file || lib.isDerivation file) && lib.pathIsRegularFile file
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
