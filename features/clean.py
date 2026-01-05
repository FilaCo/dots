import argparse
import logging

logger = logging.getLogger(__name__)


def clean(args: argparse.Namespace):
    logger.info("Not implemented yet")


def add_clean_cmd(subparsers: argparse._SubParsersAction):
    clean_parser = subparsers.add_parser(
        "clean", aliases=["c"], help="Clean FilaCo's dot files"
    )
    clean_parser.set_defaults(func=clean)
