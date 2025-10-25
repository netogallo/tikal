from os import path
from colorama import Fore,Style
from enum import Enum
from datetime import datetime

class LogLevel(Enum):
  Info = 0
  Warning = 1
  Error = 2
  Debug = 3

class Logger:

  LOG_FORES = {
    LogLevel.Info : Fore.CYAN,
    LogLevel.Warning : Fore.YELLOW,
    LogLevel.Error : Fore.RED,
    LogLevel.Debug : Fore.MAGENTA
  }

  LOG_LABELS = {
    LogLevel.Info : "Info",
    LogLevel.Warning : "Warning",
    LogLevel.Error : "Error",
    LogLevel.Debug : "Debug"
  }

  def __init__(
    self,
    loglevel
  ):

    self.__loglevel = loglevel

  def __log_message__(
    self,
    level,
    **kwargs
  ):

    if level.value > self.__loglevel.value:
      return

    fore = self.LOG_FORES.get(level) or Fore.WHITE
    label = self.LOG_LABELS.get(level) or "<MISSING LOGLEVEL>"
    when = datetime.now()

    props = "\n".join(
      f"\t{key}:\n\t\t{formatted_value}"
      for key,value in kwargs.items()
      for formatted_value in [value.replace("\n", "\n\t\t")]
    )

    entry = "\n".join([
      f"{fore}",
      f"LOG [{label}] [{when}]",
      props,
      f"{Style.RESET_ALL}"
    ])

    print(entry)
    

  def log_info(self, message, **kwargs):
    self.__log_message__(LogLevel.Info, message=message, **kwargs)

  def log_warning(self, message, **kwargs):
    self.__log_message__(LogLevel.Warning, message=message, **kwargs)

  def log_error(self, message, **kwargs):
    self.__log_message__(LogLevel.Error, message=message, **kwargs)

  def log_debug(self, message, **kwargs):
    self.__log_message__(LogLevel.Debug, message=message, **kwargs)

  def create_dirs(self, *dirs):
    for dir in dirs:
      self.log_info(f"Creating directory: {dir}")

class Tikal:
  def __init__(
    self,
    loglevel = 0,
    passwords = None
  ):

    self.__log = None

    self.__loglevel = LogLevel(loglevel)
    self.__directory = $PWD
    self.__passwords = passwords

  def __create_logger__(self, loglevel):
    return Logger(loglevel)

  @property
  def log(self):

    if self.__log is None:
      self.__log = self.__create_logger__(self.__loglevel)
      self.log.log_info(f"Working directory is: {self.__directory}")

    return self.__log

  def get_password(self, name):
    if self.__passwords is None:
      return None

    password = self.__passwords.get(name)

    if password is None:
      self.log.log_warning(f"No password found for {name} in the supplied file. Using random.")
      return None

    self.log.log_info(f"Found password for {name}")

    return password

  def get_file(self, loc):
    return path.join(self.__directory, loc)

  def log_info(self, *args, **kwargs):
    return self.log.log_info(*args, **kwargs)

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
