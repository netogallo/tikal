"""
This file contains definitions that are useful for writing tests that involve
the sync stage of Tikal in python/xonsh
"""
from sync_lib.core import LogLevel, Logger, Tikal

class TestLogger(Logger):
    def __init__(
        self,
        loglevel
    ):
        super().__init__(loglevel)
        self.__logs = {}

    def __log_message__(self, message, level):
        if level not in self.__logs:
            self.__logs[level] = []

        self.__logs[level].append(message)

class TikalMock(Tikal):
    """
    This is a mock implementation of the "Tikal" class which gets constructed by the
    sync script. The "Tikal" class contains contextual information that is used
    by the script to perform its job. This class simply mock that information.
    """

    def __init__(self):
        super().__init__(LogLevel.Debug)

    def __create_logger__(self, loglevel):
        return TestLogger(loglevel)

