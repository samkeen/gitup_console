class Colors:
    NORMAL   = 0
    WARN     = 1
    ERROR    = 2
    SUCCESS  = 3

    PURPLE    = '\033[95m'
    BLUE      = '\033[94m'
    GREEN     = '\033[92m'
    YELLOW    = '\033[93m'
    RED       = '\033[91m'
    END_COLOR = '\033[0m'

    @classmethod
    def colorize(cls, message, type=0):
        prefix = suffix = ''
        if type == cls.WARN:
            prefix = cls.YELLOW
        elif type == cls.ERROR:
            prefix = cls.RED
        elif type == cls.SUCCESS:
            prefix = cls.GREEN

        if prefix:
            suffix = cls.END_COLOR

        return "{0}{1}{2}".format(prefix, message, suffix)
