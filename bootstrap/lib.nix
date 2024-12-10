{
  nixpkgs
}:
let
  inherit (builtins) concatMap elem filter foldl' hasAttr length head tail getAttr attrNames typeOf;
  inherit (nixpkgs.lib) concatStringsSep splitString;

  to-list-path = path:
    if typeOf path == "string"
    then splitString "." path
    else path;

  getAttrDeepPoly = {
    __begin = "getAttrDeepPoly";

    __description = ''
    Given an attribute path represented as a list of strings, this function will
    get that attribute from the input object. If the attribute is not found, the
    result will depend on how the strict parameter is set.
    '';

    __functor = self: { strict ? false, default ? null, error ? null, validate ? (_: true) }: path-any: obj:
      let
        path = to-list-path path-any;
        path-str = concatStringsSep "." path;
        empty =
          if strict && error != null
          then throw (error { inherit obj; path = path-str; })
          else if strict
          then throw "Attribute '${path-str}' not in object."
          else default
        ;
        cata = s: a:
          if s == null || builtins.typeOf s != "set" || !(hasAttr a s)
	        then empty
	        else getAttr a s;
        result = builtins.foldl' cata obj path;
      in
        if validate { inherit result; }
        then result
        else empty
    ;
    __end = "getAttrDeepPoly";
  };

  getAttrDeepStrict = getAttrDeepPoly { strict = true; };

  getAttrDeep = getAttrDeepPoly { strict = false; };

  setAttrDeep = pathAny: obj: value:
    let
      path = to-list-path pathAny;
      attr = head path;
      rest = tail path;
      next =
        if hasAttr attr obj
	      then getAttr attr obj
	      else {}
      ;
      current-value = getAttrDeep [ attr ] obj;
      current-value-type = builtins.typeOf current-value;
      new-object =
        # Merge the sets if both are sets, otherwise the value overrides
        # the attribute in its entirety.
        if current-value-type == "set" && builtins.typeOf value == "set"
        then builtins.trace "mergeing attr ${attr}" (obj // { "${attr}" = current-value // value; })
        else builtins.trace "no merge ${attr}" (obj // { "${attr}" = value; })
      ;
    in
      if length path == 0
      then obj
      else if length path == 1
      then new-object
      else obj // { "${attr}" = next // setAttrDeep rest next value; };

  findPaths = cond: obj:
    let
      attrs = attrNames obj;
      matching = filter (a: cond (getAttr a obj)) attrs;
      rest = filter (a: !(elem a matching)) attrs;
      filterRec = a:
        let
	        nested = getAttr a obj;
	      in
	        if typeOf nested == "set"
	        then map (res: [a] ++ res) (findPaths cond nested)
	        else []
      ;
      others = concatMap filterRec rest;
    in
      map (a: [a]) matching ++ others; 

  compose = foldl' (s: f: arg: (s (f arg))) (x: x);

  caseFail = v: throw "Pattern match failure";

  all = conds: v: foldl' (s: c: s && c v) true conds;

  casePatch = p: { lambdaC, patchC, failC ? caseFail }:
    let
      isLambda = f: typeOf f == "lambda";
      isLambdaDefault = all [
        (hasAttr "default")
	(hasAttr "update")
	(compose [ isLambda (getAttr "update") ])
      ];
    in
      if isLambda p
      then lambdaC p
      else if isLambdaDefault p
      then patchC p
      else failC p; 

  applyPatch = patch: value:
    casePatch patch {
      lambdaC = fn: fn value;
      patchC = p: p.update (if value == null then p.default else value);
      failC = _: throw "Expecting a patch or a function.";
    };

  isPatch = patch:
    casePatch patch {
      lambdaC = _: true;
      patchC = _: true;
      failC = _: false;
    };

  pretty-print = value:
    let
      render = v:
        if builtins.typeOf v == "lambda"
        then "<lambda>"
        else if builtins.typeOf v == "set"
        then "{ ... }"
        else if builtins.typeOf v == "list"
        then "[ ... ]"
        else if builtins.typeOf v == "string"
        then v
        else builtins.toString v
      ;
      render-item = k: "${k} = ${render (builtins.getAttr k value)}";
      set-items =
        builtins.concatStringsSep
        "; "
        (map render-item (attrNames value))
      ;
      set-str = "{${set-items}}";
      list-str = "[${builtins.concatStringsSep ", " (map render value)}]";
    in
      if builtins.typeOf value == "set"
      then set-str
      else if builtins.typeOf value == "list"
      then list-str
      else render value
    ;

  modify = patches: value:
    let
      paths = findPaths isPatch patches;
      patchPath = path: {path = path; result = applyPatch (getAttrDeep path patches) (getAttrDeep path value);};
      updates = map patchPath paths;
    in
      foldl' (s: {path, result}: setAttrDeep path s result) value updates;
  tests = {
    setAttrDeep = {
      test1 =
      let
        path = ["a" "b" "c"];
        value = x: { a = { b = { c = x;}; x = 6;}; r = 7;};
      in
        rec {
          expected = value 5;
	        actual = setAttrDeep path (value 9) 5;
	        result = expected == actual;
       };
    };
    findPaths = {
      test1 =
      let
        obj = {a = { b = 5;}; c = 7; d = { e = 2; g = 8;};};
      in
        rec {
          expected = [ ["c"] ["a" "b"] ["d" "g"] ];
	        actual = findPaths (x: builtins.typeOf x == "int" && x > 3) obj;
	        result = expected == actual;
        };
    };
    modify = {
      test1 = rec {
        patches = {x = {y = old: 5;}; z = { w = old: old + 7; };};
	      input = {z = { w = 5;};};
        expected = {x = {y = 5;}; z = {w = 12;};};
	      actual = modify patches input;
	      result = expected == actual;
      };
    };
    compose = {
      test1 = rec {
        input = [ (x: x + 2) (x: x + x) ];
	      expected = 5;
	      actual = compose input 8;
	      result = expected == actual;
      };
    };
  };

  isType = {
    # begin isType
    
    __description = ''
    This function checks if the input type matches the type of the value.
    '';
    
    __functor = self: t: x: typeOf x == t;

    # end isType
  };

  project = {
    # begin project;
    
    __description = ''
      This function accepts a attribute set with boolan fields and an object. The
      true/false value, known as the strictness, indicates whether the function
      should fail if the attribute is missing or just return null.
    '';
    
    __functor = self: paths: input:
      let
        matched-paths = findPaths (all [ (isType "bool") ]) paths;
        strict-attrs = map make-strict (filter (a: getAttrDeep a paths) matched-paths);
        loose-attrs = map make-loose (filter (a: !(getAttrDeep a paths)) matched-paths);
        make-strict = attr: s:
          let
            value = getAttrDeepPoly { strict = true; } attr input;
          in
            setAttrDeep attr s value;

        make-loose = attr: s:
          let
            value = getAttrDeepPoly { strict = false; } attr input;
          in
            setAttrDeep attr s value;
      in
        foldl'
          (s: f: f s)
          {}
          (strict-attrs ++ loose-attrs)
    ;

    __tests = {
      "It returns an object when supplied with a selection mask." = rec {
        paths = { a = true; b = { c = true; d = true; }; c = false; };
        input = { a = 5; b = { c = 7; d = 9; }; };
        expected = { a = 5; b = { c = 7; d = 9; }; c = null; };
        actual = project paths input;
        result = expected == actual;
      };
    };
    
    # end project
  };

  hash = rec {
    string = builtins.hashString "sha256";

    __functor = _: obj:
      if typeOf obj == "string"
      then string obj
      else throw "Cannot hash the object provided."
    ;
  };

  self-overridable = {

    __description = ''
      Given a attribute set with function fields and a value. Create a new
      attribute set by applying the functions to the value and additinoally,
      provide an attribute with a function to further override the result.
    '';

    __functor = self: attr: value:
      builtins.mapAttrs (name: fn: fn value) attr // { __override = new-self: self attr new-self; }
    ;
  };
in
{
  inherit
    all
    compose
    findPaths
    getAttrDeep getAttrDeepPoly getAttrDeepStrict
    hash
    pretty-print project
    self-overridable setAttrDeep
    tests;
}
