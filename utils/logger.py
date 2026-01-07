import logging
import os
import sys
from logging.handlers import TimedRotatingFileHandler

LOG_DIR = "logs"
LOG_FILE = os.path.join(LOG_DIR, "dots.log")


def getLogger(name: str, level=logging.INFO):
    """init log config"""
    if not os.path.exists(LOG_DIR):
        os.makedirs(LOG_DIR)

    logger = logging.getLogger(name)
    logger.setLevel(level)
    formatter = logging.Formatter(
        "[%(asctime)s:%(module)s:%(lineno)s:%(levelname)s] %(message)s"
    )
    streamhandler = logging.StreamHandler(sys.stdout)
    streamhandler.setLevel(level)
    streamhandler.setFormatter(formatter)
    logger.addHandler(streamhandler)
    filehandler = TimedRotatingFileHandler(
        LOG_FILE, when="W6", interval=1, backupCount=60
    )
    filehandler.setLevel(level)
    filehandler.setFormatter(formatter)
    logger.addHandler(filehandler)

    return logger
