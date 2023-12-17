#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

_DISTRO_NAME="archlinux"

termux-setup-storage
termux-change-repo

pkg update -y -o Dpkg::Options::="--force-confold"
pkg upgrade -y -o Dpkg::Options::="--force-confold"
pkg uninstall dbus -y
pkg install curl bsdtar ncurses-utils dbus proot-distro x11-repo tur-repo pulseaudio -y

#Create default directories
mkdir -p Desktop
mkdir -p Downloads


proot-distro install "${_DISTRO_NAME}"
