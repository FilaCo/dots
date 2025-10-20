#! /usr/bin/env bash

for conf in "$XDG_CONFIG_HOME"/zshrc.d/*.sh; do
  source "$conf"
done
