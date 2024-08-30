{
  tikal
}:
let
  inherit (tikal.nixpkgs) makeShellNoCC stdenv writeTextFile;
  inherit (builtins) hasAttr listAttrs;
in rec {
   type-operators = {
     new: {
       __description = ''
       Define a new type by creating a derivation that represents said type.
       '';
       __functor = self: { name, new }:
         let
	   type-file = "${name}.hs";
	   type-id = 
	     stdenv.makeDerivation {
	       name = type-name;
	       src = writeTextFile {
	         name = type-name;
		 content = ''
		   module ${name} where
		   data ${name} = Void;
		   instance NixType ${name} where
		 '';
	       };
	     };
	     writeTextFile rec {
	       inherit name;
	       content = ''
	         
	       '';
	     };
	   type = {
	     inherit name type-id;
	     is = value:
	       if hasAttr "__type"
	       then value.__type.type-id == type-id
	       else false;
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
