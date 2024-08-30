{
  tikal
}:
let
  inherit (tikal.nixpkgs) ghc makeShellNoCC stdenv symlinkJoin writeTextDir writeTextFile;
  inherit (builtins) baseNameOf hasAttr listAttrs;
  tikal-types = writeTextFile {
    name = "Foundations.hs";
    destination = "src/Tikal/Nix/Types/Foundations.hs";
    content = ''
    module Tikal.Nix.Types.Foundations where
    class NixType a where
    '';
  };
in rec {
  utils = {
    nameToFile = name: "src/" ++ replaceStrings ["."] ["/"] name ++ ".hs";
  };
  types = {
    __begin = "operators";
    
    new = {
      __begin = "operators.new";
      __description = ''
      Define a new type by creating a derivation that represents said type.
      '';
      __functor = self: { name, new, __description ? "" }:
      let
	      type-file =
          let
            path = utils.nameToFile name;
            baseName = baseNameOf path;
          in
          writeTextFile {
	          name = baseName;
            destination = path;
		        content = ''
		        module ${name} where
            import Tikal.Nix.Types.Foundations
		        data ${name} = Void;
		        instance NixType ${name} where
		        '';
	        };
        src-files = symLinkJoin {
          name = "src";
          paths = [ tikal-types tikal-file ];
        };
	      type-id = stdenv.makeDerivation {
	        pname = name;
          nativeBuildInputs = [ ];
          src = src-files;
          unpackPhase = '''';
          buildPhase = ''
          # ghc -c $(find src -name '*.hs')
          '';
          installPhase = ''
          mkdir -p $out
          find . -name "*.hs" -exec cp {} $out \;
          '';
	      };
	      __type = rec {
	        inherit name type-id;
	        is = value:
            let
              other-type-id = project { __instance.__type.type-id = true; } value;
            in
              other-type-id == type-id
          ;
	      };
        in
        {
          inherit __type __description;
          __functor = self: value: {
            __instance = {
              inherit __type;
            };
            __prim = new value;
          };
        };
      };

      __end = "operators.new";
    };
    
    __end = "operators";
  };
	 in {
	   __type = type;
	   __functor = self: value:
	     let
	       content = new value;
	     in
	     if hasAttr "error" content
	     then throw content.error
	     else {
	       __type = type;
	       __value = content.value;
	     };
         };
     };
     apply = {
       __description = ''
       The type application operator. This represents an application of a type function to an arbitrary number
       of parameters to produce a new type.

       Tikal uses nix derivations to represent types. The reason is that they already do a lot of things that one
       might want to do with types. In particular:
       - They can be uniquely identified
       - The build inputs indicates if it was derived from other types.
       '';
       __functor = self: ty: args: makeShellNoCC {
         name = concatMap (t: "${t.name} ") args;
	 buildInputs = args;
       };
     };
   };

   Any = {
     __type = type-operators.new { name = "Tikal.Any"; };

     __is = value: true;

     __functor = self: value: value;
   };

   Union = {

     __type = {
     };

     __functor = self: spec:
       let
         keys = listAttrs spec;
	in
	{
	  
	}
	 
   };
}
