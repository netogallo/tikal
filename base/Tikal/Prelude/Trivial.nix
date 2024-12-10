{
  __description = ''
  This module is mostly wrappers to the <a href="https://ryantm.github.io/nixpkgs/builders/trivial-builders/#trivial-builder-runCommand">trivial builders</a> offered by nix.
  '';
  __functor = _: { nixpkgs, Any, Arrow, Set, String, ... }:
    {
      write-text-file = fn {
        args = {
          name = String;
          text = String;
        };
        result = Any;
        __functor = _: args: nixpkgs.writeTextFile (args._to-nix);
      };
    };
}
