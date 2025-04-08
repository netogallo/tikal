{ xsh, universe, ... }:
let
  tikal-dir = universe.tikal-dir;
in
  {
    script = xsh.write-script {
      name = "core.xsh";
      script = { vars, ... }: ''
  
        from os import path
        from colorama import Fore,Style
  
        class Logger:
          def __init__(
            self,
            loglevel
          ):
  
            self.__loglevel = loglevel
  
          def log_info(self, message):
            print(f"{Fore.CYAN}Info: {message}{Style.RESET_ALL}")
  
          def create_dirs(self, *dirs):
            for dir in dirs:
              self.log_info(f"Creating directory: {dir}")
  
        class Tikal:
          def __init__(
            self,
            loglevel = 0
          ):
  
            self.__log = Logger(loglevel)

            self.__directory = $PWD
            self.__log.log_info(f"Working directory is: {self.__directory}")
  
          @property
          def log(self):
            return self.__log

          def log_info(self, *args, **kwargs):
            return self.log.log_info(*args, **kwargs)

          def get_file(self, loc):
            return path.join(self.__directory, loc)

          def get_directory(self, loc=None, create=False):

            if loc is None:
              directory = self.__directory
            else:
              directory = path.join(self.__directory, loc)

            if not create:
              return directory

            if path.isfile(directory): 
              raise Exception(f"The path '{private}' is expected to be a directory")
            elif path.isdir(directory):
              return directory
  
            self.log.create_dirs(directory)
            mkdir -p f"{directory}"
            return directory
      '';
    };
  }
