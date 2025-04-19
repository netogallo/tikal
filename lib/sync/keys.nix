{ xsh, universe, ... }:
{
  script = xsh.write-script {
    name = "keys.xsh";
    vars = { nahuales = universe.nahuales.names; };
    script = ''

      def init_keys(tikal):
        secrets_dir = tikal.secrets_dir()

        for nahual in nahuales:
          print(f"mkdir -p {secrets_dir}/{nahual}")
    '';
  };
}

