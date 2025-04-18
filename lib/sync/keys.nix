{ xsh, universe, ... }:
{
  script = xsh.write-script {
    name = "keys.xsh";
    vars = { nahuales = universe.nahuales.names; };
    script = ''
      print("begin keys")
      for nahual in nahuales:
        print(f"nahual: {nahual}")
      print("end keys")
    '';
  };
}

