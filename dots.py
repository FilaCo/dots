import argparse
import logging

from features import add_clean_cmd, add_install_cmd

logger = logging.getLogger(__name__)


def main():
    logging.basicConfig(filename="dots.log", level=logging.INFO)

    parser = argparse.ArgumentParser(description="FilaCo dots installation utility")
    subparsers = parser.add_subparsers(title="commands", required=True)

    add_install_cmd(subparsers)
    add_clean_cmd(subparsers)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
