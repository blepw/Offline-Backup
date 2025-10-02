#!/bin/bash

# shellcheck disable=SC2034
# shellcheck disable=SC2034

red="$(tput setaf 1)"
green="$(tput setaf 2)"
yellow="$(tput setaf 3)"
blue="$(tput setaf 4)"
orange="$(tput setaf 208)"
light_cyan="$(tput setaf 51)"
white="$(tput setaf 7)"


os=""
version=""


banner() {
    echo "${white}


    ___  ____  ____  _  _  ____
  / ___)(  __)(_  _)/ )( \(  _ \\
  \___ \ ) _)   )(  ) \/ ( ) __/
  (____/(____) (__) \____/(__)
"
}

# Root check
sudo_check() {
    if [ "${EUID}" -ne 0 ]; then
        echo "${red}[!] Run this as root"
        exit
    else
        echo "${blue}[${green}*${blue}] Root."
        return 0
    fi
}

# Internet check
internet_connection() {
    ping -c 1 8.8.8.8 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "${blue}[${white}*${blue}]${white} Connected to the internet"
    else
        echo "${red}[!] No internet connection."
        exit 1
    fi
}

# Appearance
appearance() {
    echo "${blue}[${yellow}*${blue}] ${white}Changing appearance"
    gsettings set org.gnome.shell.extensions.dash-to-dock extend-height false
    gsettings set org.gnome.shell.extensions.topicons icon-size 20
}

# GitHub driver installation
github() {
    echo "${blue}[${yellow}*${blue}] ${white}Installing rtl8192eu drivers"
    git clone https://github.com/clnhub/rtl8192eu-linux
    cd rtl8192eu-linux/ || return
    ./install_wifi.sh
}

# Apps installation
apps() {
    echo "${blue}[${yellow}*${blue}] ${white}Installing apps"
    apt-get install -y gnome-tweaks wget terminator snapd

    snap install telegram-desktop
    snap install pycharm-community --classic
    snap install brave-browser
    snap install code --classic
    snap install discord
    sudo snap install auto-cpufreq
}

# Prerequisites
prereq() {
    echo "${blue}[${yellow}*${blue}] ${white}Installing prerequisites"
    apt-get install -y linux-headers-generic build-essential dkms git neofetch default-jdk megatools python3-tk libunwind8 libxss1 libgconf-2-4
}

# CPU config
configuration() {
    echo "${blue}[${yellow}*${blue}] ${white}Setting up cpufreq"
    systemctl status snap.auto-cpufreq.service.service
}

# Python packages
python_packages() {
    echo "${blue}[${yellow}*${blue}] ${white}Installing python packages"
    pip install --upgrade toml telethon cryptography tabulate mega.py discord colorama praw
}

# System update
update() {
    echo "${blue}[${green}*${blue}] ${white}Updating system"
    apt-get update -y && apt-get full-upgrade -y
}

# Main menu
option() {
    internet_connection
    sudo_check
    banner
    echo "${blue}[${white}1${blue}] Install"
    echo "${blue}[${red}2${blue}] Exit"
    echo ""

    read -rp "${blue}[${white}*${blue}] > " choice

    if [[ -n "${choice}" && "${choice}" =~ ^[0-9]+$ ]]; then
        case "${choice}" in
            1)
                prereq
                configuration
                appearance
                github
                apps
                python_packages
                echo "${green}[${white}✓${green}] Done."
                ;;
            2)
                echo "${red}[!] Exiting .."
                exit 0
                ;;
            *)
                echo "${red}[!] Invalid choice"
                option
                ;;
        esac
    else
        echo "${red}[!] You didn't enter a number"
        option
    fi
}

option
