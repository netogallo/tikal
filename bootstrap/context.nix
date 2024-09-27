{ nixpkgs, tikal-meta }: { module-meta, test }:
let
  lib = nixpkgs.lib;
  base-ctx-uid = "${tikal-meta.context-uid}-base";

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
          initial-ctx = initial.${tikal-meta.context-uid};
          get-member = key: members-uid:
            let
              members = initial-ctx.${members-uid}.members;
            in
              if builtins.hasAttr key members
              then [ members.${key} ]
              else []
          ;
          initial-members = key: builtins.concatMap (get-member key) initial-ctx.contexts;
          override-member-acc = current-member: new-member:
            {
              __functor = self: current-member.__override { super-ctx = initial; member = new-member; };
              __override = override-args: current-member.__override {
                super-ctx = final;
                member = (new-member.__override override-args);
              };
            }
          ;
          override-member = { key, member }: lib.foldr override-member-acc member (initial-members key);
          apply-override = key: member:
            if key != tikal-meta.context-uid && builtins.hasAttr key initial
            then override-member { inherit key member; } final
            else member final
          ;
        in
          builtins.mapAttrs apply-override members
      ;
      __functor = self: value:
        let
          base-ctx = {
            ${tikal-meta.context-uid} = {
              contexts = [ base-ctx-uid self.uid ];
              ${self.uid} = self;
              ${base-ctx-uid} = {
                name = "base";
                members = {
                  prim = member-defaults { fullname = "${self.fullname}.prim"; };
                  extend = member-defaults { fullname = "${self.fullname}.extend"; };
                };
              };
            };

            prim = value;

            extend = new-ctx:
              let
                result = ctx // new-ctx.apply-overrides ctx result;
              in
                result
            ;
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
      "It can declare new members" = { _assert, ... }:
        let
          create-context = context {
            name = "declare-member-test";
            members = {
              test = {
                __functor = _: ctx: ctx.prim + 1;
              };
            };
          };
          expected = 42;
        in
          _assert ((create-context 41).test == expected)
      ;
      "It can override members" = { _assert, ... }:
        let
          ctx-1 = context {
            name = "override-ctx1";
            members = {
              test = {
                __functor = _: ctx: ctx.prim + 1;
                __override = { super-ctx, member, ... }: ctx: super-ctx.test + member ctx;
              };
            };
          };
          ctx-2 = context {
            name = "override-ctx2";
            members = {
              test = {
                __functor = _: ctx: ctx.prim * 2;
              };
            };
          };
          value = (ctx-1 42).extend ctx-2;
          expected = 84 + 43;
        in
          _assert (value.test == expected)
      ;
    };
  };
in
test {
  inherit context;
}
