{
  tikal ? import ../../default.nix {}
}:
let
  inherit (tikal.nixpkgs) newScope stdenv writeTextFile;
  inherit (tikal.lib) prim-lib;

  # The simples way to construct a Tikal instance value from a Nix native value.
  # This constructor will accept anything it is given to it.
  prim-base =
    ''
    { lib, result, ... }: {
      new = prim: result.value prim;
    }
    '';

  mkDerivationType = args:
    let
      defaults = {
        dontUnpack = true;
        unpackPhase = "";
        dontBuild = true;
        buildPhase = "";
      };
    in
      stdenv.mkDerivation (args // defaults)
  ;

  type-instance-prim =
    let
      args = rec {
        name = "prim-instance";
        src = writeTextFile {
          name = "prim-instance.nix";
          text = ''{ version = 1.0.0; }'';
        };
        installPhase = ''
          cp ${src} $out
        '';
        uid = "__tikal_type_instance_prim";
      };
    in
      mkDerivationType args
  ;

  type-from-raw-string = { __prim, name, module }:
    let
      prim-src = writeTextFile {
        name = "${name}.nix";
        text = __prim;
      };
    in
      mkDerivationType rec {
        inherit name module;
        src = prim-src;
        installPhase = ''
          cp ${src} $out
        '';
        uid = "__tikal_type_${module}.${name}";
      }
  ;

  throw-invalid-type-instance = { prim-ctor, value }:
    throw "Type error: Value does not match the expected types."
  ;

  new-instance-derivation = {
    # begin new-instance-derivation

    __description =
    ''
    Creates a new derivation representing the instance of a type.
    '';

    __functor = self: { prim-types }:
      let
        instances =
          builtins.foldl'
            (s: prim-type: s // { "${prim-type}" = prim-type; })
            {} prim-types
        ;
      in
        mkDerivationType rec {
          name = "new-instance";
          src = writeTextFile {
            name = "new-instance.nix";
            text = ''
            { prim-instance = "${type-instance-prim}"; }
            '';
          };
          installPhase = ''
            cp ${src} $out
          '';
          "${type-instance-prim}" = type-instance-prim;
        }
    ;

    # end new-instance-derivation
  };

  call-prim-lib = {
    lib = {
      isType = ty: val: builtins.typeOf val == ty;
    };
    result = {
      value = value: { value = value; };
      error = error: { error = error; };
    };
  };

  call-prim = newScope call-prim-lib;
  new-type-instance = { prim-ctor, inherits, value }:
    let
      new-prim =
        let
          prim-result = (call-prim prim-ctor {}).new value;
          result =
            prim-lib.project
              { value = false; error = false; }
              prim-result
          ;
        in
          if result.error != null
          then throw "not implemented"
          else { "${prim-ctor.uid}" = result.value; }
        ;
      new-instance = name: type: {
        "${name}" = type value;
      };
      instance-ctx =
        builtins.foldl'
          (s: v: s // v)
          {}
          (builtins.attrValues (builtins.mapAttrs new-instance inherits))
      ;
      self-ctx = { self = instance; } // instance-ctx;
      type-instance-ctx =
        { "${prim-ctor.uid}" = instance; }
        // (builtins.foldl' (s: v: s // v) {} (builtins.attrValues instance-ctx))
      ;
      instance = {
        inherit self-ctx value;
        __prim = new-prim;
        "${type-instance-prim.uid}" = type-instance-ctx;
      };
    in
      instance
    ;

  constructor = {
    #begin constructor

    __description =
    ''
    Function to generate a constructor for a new type.
    '';

    __functor = self: { name, prim-ctor, inherits, self-type }:
    {
      __description = "Constructor for type '${name}'";

      __functor = self: value:
        let
          prim-instance = prim-lib.project { "${type-instance-prim.uid}" = false; } value;
          check-boxed =
            prim-lib.all (
              builtins.map (type: type.is-instance) ([self-type] ++ builtins.attrValues inherits)
            );
          boxed-value =
            if check-boxed value
            then value
            else throw-invalid-type-instance { inherit prim-ctor value; }
          ;
          unboxed-value = new-type-instance {
            inherit prim-ctor inherits value;
          };
        in
          if builtins.typeOf value == "set" && prim-instance."${type-instance-prim.uid}" != null
          then boxed-value
          else unboxed-value
      ;
    }
    ;

    #end constructor
  };
in
{
  inherit call-prim call-prim-lib;
  new-type =
    #begin new-type
    name:
    {
      inherits ? {},
      __prim ? prim-base,
      module ? "Tikal.Nix.Types.User",
      __description ? "Todo: Add documentation to for type '${name}'",
      ...
    }:
    let
      prim-type = type-from-raw-string {
        inherit __prim name module;
      };
      ctor = constructor {
        inherit name inherits self-type;
        prim-ctor = prim-type;
      };
      self-type = {
        inherit name module __description;
        __functor = self: ctor;
        "${prim-type.uid}" = prim-type;

        is-instance = value:
          let
            prim-instance = prim-lib.project { "${type-instance-prim.uid}" = false; } value;
            prim-types = prim-instance."${type-instance-prim.uid}";
            prim-check = builtins.hasAttr "${prim-type.uid}" prim-types;
          in
            builtins.typeOf value == "set"
            && prim-types != null
            && prim-check
        ;
      }
    ;
    in
      self-type
  #end new-type
  ;
}
