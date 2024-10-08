{ nixpkgs, tikal-meta }: { module-meta, test }:
let
  inherit (import ./lib.nix { inherit nixpkgs; }) getAttrDeep;
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

      focal = spec;

      fullname = "${module-meta.name}.${spec.name}";

      uid = "${module-meta.name}.${spec.name}";

      surrounds = value:
        getAttrDeep "${tikal-meta.context-uid}.${uid}" value != null;

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
          prev-member = key: lib.last (builtins.concatMap (get-member key) initial-ctx.contexts);
          override-member-acc = new-member: current-member:
            {
              __functor = self: current-member.__override { super-ctx = initial; member = new-member; };
              __override = override-args: current-member.__override {
                super-ctx = initial;
                member = (new-member.__override override-args);
              };
            }
          ;
          override-member = { key, member }: override-member-acc member (prev-member key);
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
          extend = current-ctx: new-ctx:
            let
              prev-inner-ctx = current-ctx.${tikal-meta.context-uid};
              result =
                current-ctx //
                (new-ctx.apply-overrides current-ctx result) //
                {
                  ${tikal-meta.context-uid} = prev-inner-ctx // {
                    contexts = prev-inner-ctx.contexts ++ [ new-ctx.uid ];
                    ${new-ctx.uid} = new-ctx.focal;
                  };
                  extend = extend result;
                }
              ;
            in
              result
          ;
          base-ctx = {
            ${tikal-meta.context-uid} = {
              contexts = [ base-ctx-uid self.uid ];
              ${self.uid} = self;
              ${base-ctx-uid} = {
                name = "base";
                members = {
                  focal = member-defaults { fullname = "${self.fullname}.focal"; };
                  extend = member-defaults { fullname = "${self.fullname}.extend"; };
                };
              };
            };

            focal =
              if builtins.hasAttr "__functor" spec
              then spec value
              else value
            ;
            extend = extend ctx;
          };
          ctx = base-ctx // apply-overrides base-ctx ctx;
        in
          ctx
      ;
    };

    __tests = {
      "It contains a 'focal' member" = { _assert, ...}:
        let
          ctx = context { name = "focal-test"; members = {}; };
          expected = 42;
        in
          _assert ((ctx expected).focal == expected)
      ;
      "It can declare new members" = { _assert, ... }:
        let
          create-context = context {
            name = "declare-member-test";
            members = {
              test = {
                __functor = _: ctx: ctx.focal + 1;
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
                __functor = _: ctx: ctx.focal + 1;
                __override = { super-ctx, member, ... }: ctx: super-ctx.test + member ctx;
              };
            };
          };
          ctx-2 = context {
            name = "override-ctx2";
            members = {
              test = {
                __functor = _: ctx: ctx.focal * 2;
              };
            };
          };
          value = (ctx-1 42).extend ctx-2;
          expected = 84 + 43;
        in
          _assert (value.test == expected)
      ;
      "It can override multiple times" = { _assert, ... }:
        let
          p1 = 41;
          p2 = 47;
          p3 = 31;
          ctx-1 = context {
            name = "override-1";
            members = {
              test = {
                __functor = _: ctx: ctx.focal * p1;
                __override = { super-ctx, member, ... }: ctx: super-ctx.test + member ctx;
              };
            };
          };
          ctx-2 = context {
            name = "override-2";
            members = {
              test = {
                __functor = _: ctx: ctx.focal * p2;
                __override = { super-ctx, member, ... }: ctx: super-ctx.test + member ctx;
              };
            };
          };
          ctx-3 = context {
            name = "override-3";
            members = {
              test = {
                __functor = _: ctx: ctx.focal * p3;
              };
            };
          };
          value = ((ctx-1 3).extend ctx-2).extend ctx-3;
        in
          _assert.eq value.test ((3 * p1) + (3 * p2) + (3 * p3))
      ;
      "It cannot override protected members" = { _assert, ... }:
        let
          ctx-1 = context {
            name = "bad-ctx";
            members = {
              focal = {
                __functor = _: ctx: "bad";
              };
            };
          };
        in
          _assert.throws ((ctx-1 3).focal)
      ;
      "It can transform the focal" = { _assert, ... }:
        let
          spec = {
            name = "transform-focal-ctx";
            __functor = _: value: value + 1;
            members = {};
          };
          input = 41;
          expected = spec input;
          ctx = context spec;
        in
          _assert ((ctx 41).focal == expected)
      ;
    };
  };
in
test {
  inherit context;
}
