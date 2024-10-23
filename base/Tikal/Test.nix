{
  __functor = _: { context, test, type, ... }: test {
    inherit context type;
  };
#    let
#      test-ctx = context {
#        name = "test-ctx";
#        members = {};
#      };
#    in
#      { value = test-ctx 42; }
#  ;
}
