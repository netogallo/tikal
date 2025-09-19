"""
This file contains definitions that are useful for writing tests that involve
the sync stage of Tikal in python/xonsh
"""
from enum import Enum

class LogLevel(Enum):
    Info = 7

class TikalMock:
    """
    This is a mock implementation of the "Tikal" class which gets constructed by the
    sync script. The "Tikal" class contains contextual information that is used
    by the script to perform its job. This class simply mock that information.
    """


    def __init__(self, test_case):
        super().__init__()
        self.__logs = []
        self.__test_case = test_case

    @property
    def test_case(self):
        return self.__test_case

    def log_info(self, message: str) -> None:
        self.__logs.append({'level': LogLevel.Info, 'message': message})

