{ universe, xsh, writeTextFile, ... }:
let
  gitignore = writeTextFile {
    name = ".gitignore";
    text = ''
      private
    '';
  };
in
  {
    script = xsh.write-script {
      name = "foundations.xsh";
      vars = {
        inherit (universe) tikal-dir;
      };
      script = { vars, ... }: ''
        
        from os import path

        def init_foundations(tikal):

          # Create a .gitignore file for the
          # private directory
          ignore = path.join(tikal.get_directory(${vars.tikal-dir}, create = True), ".gitignore")
          tikal.log_info(f"Updating the git ignore file at {ignore}")
          cp -f "${gitignore}" f"{ignore}"
      '';
    };
  }
  
