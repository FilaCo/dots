import argparse
import shutil
import subprocess

from utils.logger import getLogger

logger = getLogger(__name__)


def install(args: argparse.Namespace):
    match args.target:
        case "server":
            install_server(args)
        case "desktop":
            logger.info("Installing desktop dot files...")
        case "laptop":
            logger.info("Installing laptop dot files...")
        case _:
            logger.error("Invalid target")
            exit(1)


def install_server(args: argparse.Namespace):
    pass


def add_install_cmd(subparsers: argparse._SubParsersAction):
    install_parser = subparsers.add_parser(
        "install", aliases=["i"], help="install FilaCo's dot files"
    )
    install_parser.set_defaults(func=install)
    install_parser.add_argument(
        "--no-confirm", action="store_true", help="skip confirmation prompts"
    )
    install_parser.add_argument(
        "-t",
        "--target",
        choices=["server", "desktop", "laptop"],
        default="desktop",
        help="specify the installation target, defaults to 'desktop'",
    )


def install_yay():
    if shutil.which("yay"):
        return
    subprocess.run(
        "sudo pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si",
        shell=True,
        check=True,
    )
