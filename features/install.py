import argparse
import logging

logger = logging.getLogger(__name__)


def install(args: argparse.Namespace):
    pass


def add_install_cmd(subparsers: argparse._SubParsersAction):
    install_parser = subparsers.add_parser(
        "install", aliases=["i"], help="Install FilaCo's dot files"
    )
    install_parser.set_defaults(func=install)
