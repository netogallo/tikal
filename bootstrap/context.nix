{ nixpkgs, tikal-meta }: { module-meta, test }:
let

  member-defaults = { fullname }: {
    __override = _: throw "The member '${fullname}' does not allow overriding.";
  };

  context = {
    __description = ''
      Given a specification for a context. It constructs a function that will accept
      a value and enrich said value with the context.
    '';

    __functor = _: spec: rec {
      ${tikal-meta.context-uid} = {
        contexts = [];
      };

      prim = spec;

      fullname = "${module-meta.name}.${spec.name}";

      uid = "${module-meta.name}.${spec.name}";

      members =
        let
          apply-default = key: member: member-defaults { fullname = "${fullname}.${key}"; } // member;
        in
          builtins.mapAttrs apply-default spec.members
      ;

      apply-overrides = initial: final:
        let
          override-member = current-member: new-member:
            {
              __functor = self: current-member.__override { member = new-member; };
              __override = override-args: current-member.__override {
                member = (new-member.__override override-args);
              };
            }
          ;
          apply-override = key: member:
            if key != tikal-meta.context-uid && builtins.hasAttr key initial
            then override-member initial.${key} member final
            else member final
          ;
        in
          builtins.mapAttrs apply-override members
      ;
      __functor = self: value:
        let
          base-ctx = {
            ${tikal-meta.context-uid} = {
              contexts = [ self.uid ];
              ${self.uid} = self;
            };

            prim = (member-defaults { fullname = "${self.fullname}.prim"; } // {
              __functor = _: self: value; 
            }) ctx;
          };
          ctx = base-ctx // apply-overrides base-ctx ctx;
        in
          ctx
      ;
    };

    __tests = {
      "It contains a prim member" = { _assert, ...}:
        let
          ctx = context { name = "prim-test"; members = {}; };
          expected = 42;
        in
          _assert ((ctx expected).prim == expected)
      ;
    };
  };
in
test {
  inherit context;
}
