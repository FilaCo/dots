import argparse

from features import add_clean_cmd, add_install_cmd


def main():
    parser = argparse.ArgumentParser(description="FilaCo dots installation utility")
    subparsers = parser.add_subparsers(title="commands", required=True)

    add_install_cmd(subparsers)
    add_clean_cmd(subparsers)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
