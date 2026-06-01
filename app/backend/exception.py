import datetime

class ResourceNotExist(Exception):
    def __init__(self, message):
        self.message = message
        now = datetime.datetime.now()
        self.when = now.strftime("%c") 