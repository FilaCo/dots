#!/usr/bin/env bash

help() {
echo -e "FilaCo's dots util script

$(ansi::green)Usage:$(ansi::resetFg) $(ansi::cyan)filaco [OPTIONS] [COMMAND]$(ansi::resetFg)

$(ansi::green)Options:$(ansi::resetFg)
  $(ansi::cyan)-V, --version$(ansi::resetFg)		Print version info and exit
  $(ansi::cyan)-h, --help$(ansi::resetFg)		Print help

$(ansi::green)Commands:$(ansi::resetFg)
  $(ansi::cyan)install, i$(ansi::resetFg)		Install FilaCo's config"
}

p=$(getopt -o Vh -l version,help -n filaco -- "$@")
[ $? != 0 ] && echo "filaco: getopt failed, please check params" && exit 1

eval set -- "$p"

while true ; do
  case "$1" in
    -h|--help) help;exit 0;;
    --) break ;;
    *) shift ;;
  esac
done
