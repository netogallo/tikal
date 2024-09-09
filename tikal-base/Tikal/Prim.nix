{
  __description = ''
    The "Prim" module contains several hand-rolled Tikal values that are then used
    to describe new Tikal values. Even though it looks like a regular Tikal module,
    this module can be loaded with a very limited set of functionality.

    The main export from prim is the Type value, which is then used to
    create new Types.
  '';

  __functor = self: { nixpkgs, value, ... }: {

    Type = value.with-exports {
    };

  };
}
