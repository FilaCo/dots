import argparse
import inspect
import os
import shutil
import subprocess
from enum import Enum, StrEnum, auto

from colored import Fore, Style


class NoConfirm(Enum):
    YES = auto()
    NO = auto()


NO_CONFIRM = NoConfirm.NO


class SkipAll(Enum):
    YES = auto()
    NO = auto()


SKIP_ALL = SkipAll.NO

TERM_SIZE = os.get_terminal_size()
TERM_WIDTH = TERM_SIZE.columns
TERM_HEIGHT = TERM_SIZE.lines


def prevent_sudo_or_root():
    ROOT_UID = 0
    if ROOT_UID != os.getuid():
        return

    print(
        f'{Fore.red}This script is NOT to be executed with sudo or as root. Aborting...{Style.reset}'
    )
    exit('Aborted due to root permissons')


def set_globals(args):
    global NO_CONFIRM
    NO_CONFIRM = NoConfirm.YES if args.noconfirm else NoConfirm.NO


class ConfirmationAnswer(StrEnum):
    YES = 'y'
    EXIT = 'e'
    SKIP = 's'
    YES_FOR_ALL = 'yesforall'


def need_confirm(func):
    header = f"""
{'#' * TERM_WIDTH}
{Fore.blue}Next command:{Style.reset}
{Fore.green}{inspect.getsource(func)}{Style.reset}
"""
    prompt = f"""
{Fore.blue}Execute? {Style.reset}
y = Yes
e = Exit now
s = Skip this command (NOT recommended - your setup might not work correctly)
yesforall = Yes and don't ask again; NOT recommended unless you really sure
"""

    def with_confirmation(*args, **kwargs):
        global NO_CONFIRM
        if NoConfirm.YES == NO_CONFIRM:
            return func(*args, **kwargs)
        print(header)
        ans = ConfirmationAnswer.EXIT
        while True:
            print(prompt)
            raw_ans = input().lower()
            try:
                ans = ConfirmationAnswer(raw_ans)
                break
            except ValueError:
                print(
                    f'{Fore.red}Please, enter [y/e/s/yesforall].{Style.reset}'
                )

        match ans:
            case ConfirmationAnswer.EXIT:
                print(f'{Fore.blue}Exiting...{Style.reset}')
                global SKIP_ALL
                SKIP_ALL = SkipAll.YES
                exit('Aborted by user')
            case ConfirmationAnswer.SKIP:
                print(
                    f"""
{Fore.blue}Alright, skipping this one...{Style.reset}
{Fore.yellow}{func.__name__}{Style.reset} has been skipped
"""
                )
            case ConfirmationAnswer.YES_FOR_ALL:
                print(
                    f"{Fore.blue}Alright, won't ask again. Executing...{Style.reset}"
                )
                NO_CONFIRM = NoConfirm.YES
                return func(*args, **kwargs)
            case ConfirmationAnswer.YES:
                print(f'{Fore.blue}OK, executing...{Style.reset}')
                return func(*args, **kwargs)

    return with_confirmation


@need_confirm
def pacman_syu():
    subprocess.run(
        'sudo pacman -Syu --noconfirm',
        shell=True,
        check=True,
    )


@need_confirm
def pacman_S_base_deps():
    subprocess.run(
        'sudo pacman -S --needed --noconfirm base-devel git',
        shell=True,
        check=True,
    )


@need_confirm
def install_yay():
    subprocess.run(
        'git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si',
        shell=True,
        check=True,
    )


@need_confirm
def yay_S_req_deps():
    subprocess.run(
        'yay -S --needed --noconfirm btop btrfs-progs chrony dockerfmt dosfstools efibootmgr e2fsprogs fwupd fzf go grub hypridle hyprland hyprpaper hyprpicker hyprpolkitagent hyprsysteminfo kitty luarocks neovim nwg-displays quickshell ripgrep rsync steam teamspeak telegram-desktop ttf-jetbrains-mono-nerd vi vim yay yazi zen-browser-bin zram-generator zsh',
        check=True,
        shell=True,
    )


@need_confirm
def install_rust():
    subprocess.run(
        "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh",
        check=True,
        shell=True,
    )


@need_confirm
def install_nvm():
    subprocess.run(
        'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash',
        check=True,
        shell=True,
    )


@need_confirm
def install_starship():
    subprocess.run(
        'curl -sS https://starship.rs/install.sh | sh',
        check=True,
        shell=True,
    )


@need_confirm
def install_treesitter():
    subprocess.run(
        'cargo install --locked tree-sitter-cli',
        check=True,
        shell=True,
    )


SPECIAL_DEPS = {
    'rustc': install_rust,
    'nvm': install_nvm,
    'starship': install_starship,
    'tree-sitter': install_treesitter,
}


def install_deps():
    pacman_syu()
    pacman_S_base_deps()

    if not shutil.which('yay'):
        install_yay()

    yay_S_req_deps()

    for dep, install_dep in SPECIAL_DEPS.items():
        if not shutil.which(dep):
            install_dep()


def setup_env():
    pass


def sync_dots():
    pass


def install(args):
    set_globals(args)
    install_deps()
    setup_env()
    sync_dots()


def main():
    prevent_sudo_or_root()
    parser = argparse.ArgumentParser(
        description="FilaCo's dotfiles util script",
    )
    parser.add_argument('-v', '--verbose', action='count', default=0)
    parser.add_argument(
        '--noconfirm',
        action='store_true',
        help='do not confirm every time before a command executes',
    )

    subparsers = parser.add_subparsers(
        title='commands',
        required=True,
    )
    install_parser = subparsers.add_parser(
        'install', aliases=['i'], help="install FilaCo's configuration"
    )
    install_parser.set_defaults(func=install)

    args = parser.parse_args()
    try:
        args.func(args)
    except KeyboardInterrupt:
        pass


if __name__ == '__main__':
    main()
