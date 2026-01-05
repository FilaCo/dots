function fish_greeting
    echo -ne '\x1b[38;5;16m'  # Set colour to primary
    echo '    ____          '
    echo '   /  _/______  __'
    echo '   / // ___/ / / /'
    echo ' _/ // /__/ /_/ / '
    echo '/___/\___/\__, /  '
    echo '         /____/   '
    set_color normal
    fastfetch
end
