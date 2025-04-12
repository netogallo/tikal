{ xsh, universe, ... }:
{
  script = xsh.write-script {
    name = "keys.xsh";
    vars = { universe = universe; };
    script = ''
      print("begin keys")
      for k,v in universe.items():
        print(f"{k} = {v}")
      print("end keys")
    '';
  };
}

