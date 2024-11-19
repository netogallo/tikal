{ nixpkgs, tikal-meta, ... }: { module-meta, test, ... }:
let
  inherit (import ./lib.nix { inherit nixpkgs; }) getAttrDeep;
  lib = nixpkgs.lib;
  base-ctx-uid = "${tikal-meta.context-uid}-base";

  simple-override = override: { key, initial-ctx, final-ctx, current-member, new-member, ... }:
    {
      __member = _:
        let
          self-member = new-member.__member {};
          super-member = current-member.__member {};
        in
          override { inherit self-member super-member; }
      ;
    }
  ;

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

      uid = (builtins.hashString "sha256" "${module-meta.name}.${spec.name}") + "-${spec.name}";

      surrounds = value:
        getAttrDeep [ tikal-meta.context-uid uid ] value != null;

      members = ctx:
        let
          apply-default = key: member: member-defaults { fullname = "${fullname}.${key}"; } // member;
        in
          builtins.mapAttrs apply-default (spec.members ctx)
      ;

      apply-overrides = { initial, final, extension }:
        let
          initial-ctx = initial.${tikal-meta.context-uid};
          call-ctx = {};
          get-member = key: members-uid:
            let
              members' = initial-ctx.${members-uid}.members { self = initial; };
            in
              if builtins.hasAttr key members'
              then [ members'.${key} ]
              else []
          ;
          prev-members = key: (builtins.concatMap (get-member key) initial-ctx.contexts);
          prev-member = key: lib.last (prev-members key);
          override-member = { key, member }:
            let
              prev = prev-members key;
              acc = current-member: new-member:
                current-member.__override {
                  inherit extension key current-member new-member;
                  initial-ctx = initial;
                  final-ctx = final;
                }
              ;
            in
              lib.foldr acc member prev
          ;
          apply-override = key: member:
            # Check if the current context already has a member with the
            # same name as the new members. In the positive case,
            # override the member according to its rules for overriding.
            if key != tikal-meta.context-uid && builtins.hasAttr key initial
            then (override-member { inherit key member; }).__member call-ctx
            else member.__member call-ctx
          ;
        in
          # Map over the members that the new context
          # provides.
          builtins.mapAttrs apply-override (members { self = final; })
      ;
      __functor = self: value:
        let
          extend = current-ctx: new-ctx:
            let
              prev-inner-ctx = current-ctx.${tikal-meta.context-uid};
              result =
                current-ctx //
                (new-ctx.apply-overrides { initial = current-ctx; final = result; extension = new-ctx; }) //
                {
                  ${tikal-meta.context-uid} = prev-inner-ctx // {
                    contexts = prev-inner-ctx.contexts ++ [ new-ctx.uid ];
                    ${new-ctx.uid} = new-ctx;
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
                members = _: {
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
          ctx = base-ctx // apply-overrides { initial = base-ctx; final = ctx; extension = null; };
        in
          ctx
      ;
    };

    __tests = {
      "It contains a 'focal' member" = { _assert, ...}:
        let
          ctx = context { name = "focal-test"; members = _: {}; };
          expected = 42;
        in
          _assert ((ctx expected).focal == expected)
      ;
      "It can declare new members" = { _assert, ... }:
        let
          create-context = context {
            name = "declare-member-test";
            members = { self, ... }: {
              test = {
                __member = _: self.focal + 1;
              };
            };
          };
          expected = 42;
        in
          _assert.eq (create-context 41).test expected
      ;
      "It can override members" = { _assert, ... }:
        let
          ctx-1 = context {
            name = "override-ctx1";
            members = { self, ... }: {
              test = {
                __member = _: self.focal + 1;
                __override = simple-override ({ super-member, self-member, ... }: super-member + self-member);
              };
            };
          };
          ctx-2 = context {
            name = "override-ctx2";
            members = { self, ...}: {
              test = {
                __member = _: self.focal * 2;
              };
            };
          };
          value = (ctx-1 42).extend ctx-2;
          expected = 84 + 43;
        in
          _assert.eq value.test expected
      ;
      "It can override multiple times" = { _assert, ... }:
        let
          p1 = 41;
          p2 = 101;
          p3 = 31;
          ctx-1 = context {
            name = "override-1";
            members = { self, ... }: {
              test = {
                __member = _: self.focal * p1;
                __override = simple-override ({ self-member, super-member, ... }: super-member + self-member);
              };
            };
          };
          ctx-2 = context {
            name = "override-2";
            members = { self, ... }: {
              test = {
                __member = _: self.focal * p2;
                __override = simple-override ({ self-member, super-member, ... }: super-member + self-member);
              };
            };
          };
          ctx-3 = context {
            name = "override-3";
            members = { self, ... }: {
              test = {
                __member = _: self.focal * p3;
              };
            };
          };
          value = ((ctx-1 3).extend ctx-2).extend ctx-3;
        in
          _assert.eq value.test ((3 * p1) + (3 * p2) + (3 * p3))
      ;
#      "It cannot override protected members" = { _assert, ... }:
#        let
#          ctx-1 = context {
#            name = "bad-ctx";
#            members = {
#              focal = {
#                __functor = _: ctx: "bad";
#              };
#            };
#          };
#        in
#          _assert.throws ((ctx-1 3).focal)
#      ;
#      "It can transform the focal" = { _assert, ... }:
#        let
#          spec = {
#            name = "transform-focal-ctx";
#            __functor = _: value: value + 1;
#            members = {};
#          };
#          input = 41;
#          expected = spec input;
#          ctx = context spec;
#        in
#          _assert ((ctx 41).focal == expected)
#      ;
#      "It can have a __funcotr member" = { _assert, ... }:
#        let
#          fn-ctx = context {
#            name = "functor";
#            members = {
#              __functor = {
#                __functor = _: ctx: _: v: ctx.focal v;
#              };
#            };
#          };
#          fn = x: x*x;
#        in
#          _assert.eq (fn-ctx fn 5) (fn 5)
#      ;
#      "It can check if a context surronds a value" = { _assert, ... }:
#        let
#          ctx = context {
#            name = "surronds";
#            members = {};
#          };
#          v = ctx 42;
#        in
#          _assert (ctx.surrounds v)
#      ;
    };
  };
in
test {
  inherit context;
}
