{ sync-module, tikal, writeTextFile, ... }:
let
  inherit (tikal.xonsh) xsh;
  gitignore = writeTextFile {
    name = ".gitignore";
    text = ''
      /private/
    '';
  };
in
  {
    script = xsh.write-script {
      name = "foundations.xsh";
      vars = {
        inherit (sync-module.config.tikal.context) tikal-dir;
      };
      script = { vars, ... }: ''
        
        from os import path

        def open_passwords(file):

          result = {}
          with open(file, 'r') as stream:
            for line in stream.readlines():
              creds = line.split(":") 

              if len(creds) != 2:
                raise Exception("Passwords must have the format 'nahual:password'")

              result[creds[0]] = creds[1].strip()

          return result

        def init_foundations(tikal):

          # Create a .gitignore file for the
          # private directory
          ignore = path.join(tikal.get_directory(${vars.tikal-dir}, create = True), ".gitignore")
          tikal.log_info(f"Updating the git ignore file at {ignore}")
          cp -f "${gitignore}" f"{ignore}"
      '';
    };
  }
  
