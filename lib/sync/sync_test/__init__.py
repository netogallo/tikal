"""
This file contains definitions that are useful for writing tests that involve
the sync stage of Tikal in python/xonsh
"""
from sync_lib.core import LogLevel, Logger, Tikal

def is_matching_log(query, entry):
    from fnmatch import fnmatch
    return all(
        value is not None and fnmatch(str(value), query_value)
        for key,query_value in query.items()
        for value in [entry.get(key)]
    )

class TestLogger(Logger):
    def __init__(
        self,
        loglevel
    ):
        super().__init__(loglevel)
        self.__logs = []

    def __log_message__(self, level, message, **kwargs):

        entry = { 'message': message, 'loglevel': level, **kwargs }

        self.__logs.append(entry)

    def get_matching_logs(self, **kwargs):
        return [
            log
            for log in self.__logs if is_matching_log(kwargs, log)
        ]

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

