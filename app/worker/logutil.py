from __future__ import annotations
import logging
import os
from .config import LOG_LEVEL

def setup_logger(name: str) -> logging.Logger:
    level = LOG_LEVEL
    logging.basicConfig(level=level, format="%(asctime)s %(levelname)s %(message)s")
    log = logging.getLogger(name)
    log.setLevel(level)
    return log
