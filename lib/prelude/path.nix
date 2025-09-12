{ lib, test }:
let
  inherit (lib) lists strings;
  extension-of-checked = options: path:
    let
      name = builtins.baseNameOf path;
    in
      lib.lists.findFirst
      (ext: strings.isSuffixOf ".${ext}" name)
      (throw "The file '${path}' does not have the extensions '${trace.debug-print options}'")
  ;
in
  test.with-tests
  {
    inherit extension-of-checked;
  }
  {
    prelude.path =  {
      "it returns the extension if matches" = { _assert, ... }: _assert.all [
        (_assert.eq "exe" (extension-of-checked [ "jpg" "exe" ] "file.exe"))
        (_assert.eq "exe" (extension-of-checked [ "jpg" "exe" ] "/abs/path/file.exe"))
        (_assert.eq "exe" (extension-of-checked [ "jpg" "exe" ] "rel/path/file.exe"))
      ];

      "it throws error if the extension doesn't match" = { _assert, ... }: _assert.all [
        (_assert.throws (extension-of-checked [ "jpg" "exe" ] "file.exe.not"))
        (_assert.throws (extension-of-checked [ "jpg" "exe" ] "file.notexe"))
      ];
    };
  }
