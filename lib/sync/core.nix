{ xsh, universe, ... }:
{
  script = xsh.write-script {
    name = "core.xsh";
    script = ''
      class Tikal:
        def __init__(
          self,
          directory = None
        ):

          if directory is None:
            basedir = $PWD
            directory = f"{basedir}/.tikal"

          self.__directory = directory

        def secrets_dir(self):
          secrets = f"{self.__directory}/secrets"
          mkdir -p secrets
          return secrets
    '';
  };
}
