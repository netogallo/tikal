{
  __functor = _: { Arrow, context, Maybe, test, type, Type, Set, ... }:
    let
      AttrMapping = _: "No Mapping";
      Union = _: throw "no union";
      FunDef = Set {
        __functor = _: {};
        args = Maybe (
          Union {
            set = AttrMapping { To = Type; };
          }
        );
      };
      fn = {
        __description = ''
        Wrapper that provides some syntax to easily define typed functions.
        '';

      __functor = _: fun-def:
        let
          x = "";
        in
          Arrow type fun-def
        ;
      };
    in
      test {}
  ;
}
