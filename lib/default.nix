{
}:
let
  inherit (builtins) concatMap elem filter foldl' hasAttr length head tail getAttr attrNames typeOf;
  getAttrDeep = path: obj:
    let
      cata = s: a:
        if s == null || !(hasAttr a s)
	then null
	else getAttr a s;
    in
      builtins.foldl' cata obj path;
  setAttrDeep = path: obj: value:
    let
      attr = head path;
      rest = tail path;
      next =
        if hasAttr attr obj
	then getAttr attr obj
	else {};
    in
      if length path == 0
      then obj
      else if length path == 1
      then obj // { "${attr}" = value; }
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
	else [];
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
in
{
  inherit compose findPaths getAttrDeep setAttrDeep tests;
}
