{ tikal, universe, ... }:
let
  inherit (tikal.xonsh) xsh;
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
            loglevel = 0,
            passwords = None
          ):
  
            self.__log = Logger(loglevel)

            self.__directory = $PWD
            self.__log.log_info(f"Working directory is: {self.__directory}")
            self.__passwords = passwords

          def get_password(self, name):
            if self.__passwords is None:
              return None

            password = self.__passwords.get(name)

            if password is None:
              self.__log.log_warning(f"No password found for {name} in the supplied file. Using random.")
              return None

            self.__log.log_info(f"Found password for {name}")

            return password
  
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
