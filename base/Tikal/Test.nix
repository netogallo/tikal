{
  __functor = _: { context, ... }:
    let
      test-ctx = context {
        name = "test-ctx";
        members = {};
      };
    in
      { value = test-ctx 42; }
  ;
}
