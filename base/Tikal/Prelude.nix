{
  __functor = _: { prim, context, maybe, test, type, ... }:
    let

      

      fn = {
        __description = ''
        Wrapper that provides some syntax to easily define typed functions.
        '';

      __functor = _: { __functor }@fun-def =
        let
      
        in
          Arrow type fun-def
        ;
      };
    in
      test {}
  ;
}
