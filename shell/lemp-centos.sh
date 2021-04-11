#!/bin/bash


##
## variables
##
NOCOLOR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHTGRAY='\033[0;37m'
DARKGRAY='\033[1;30m'
LIGHTRED='\033[1;31m'
LIGHTGREEN='\033[1;32m'
YELLOW='\033[1;33m'
LIGHTBLUE='\033[1;34m'
LIGHTPURPLE='\033[1;35m'
LIGHTCYAN='\033[1;36m'
WHITE='\033[1;37m'

show_verbose=true
install_php_56=true
install_php_70=true
install_php_71=true
install_php_72=true
install_php_73=true
install_php_74=true
install_php_80=true


printf "${YELLOW}########################################${NOCOLOR}\n"
printf "${YELLOW}# CentOS Webserver Setup Script * v1.2 #${NOCOLOR}\n"
printf "${YELLOW}########################################${NOCOLOR}\n"


##
## https://gist.github.com/davejamesmiller/1965569
##
ask() {
    # https://djm.me/ask
    local prompt default reply

    if [ "${2:-}" = "Y" ]; then
        prompt="Y/n"
        default=Y
    elif [ "${2:-}" = "N" ]; then
        prompt="y/N"
        default=N
    else
        prompt="y/n"
        default=
    fi

    while true; do

        # Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -e -n "${YELLOW} $1 [$prompt] ${NOCOLOR} "

        # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
        read reply </dev/tty

        # Default?
        if [ -z "$reply" ]; then
            reply=$default
        fi

        # Check if the reply is valid
        case "$reply" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac

    done
}


##
## root check
##
if [[ $EUID -ne 0 ]]; then
    printf "${LIGHTRED}[ERR] This script must be run as root ${NOCOLOR}\n"
    exit
fi


##
## detect platform - https://unix.stackexchange.com/a/195808
##
platform_info=`( lsb_release -ds || cat /etc/*release || uname -om ) 2>/dev/null | head -n1`
if [ "$show_verbose" = true ]; then
    printf "${LIGHTCYAN}[INFO] Platform: ${platform_info} ${NOCOLOR}\n"
fi

if [[ "$platform_info" != "CentOS" ]]; then
    printf "${LIGHTRED}[ERR] This script can be run under CentOS ${NOCOLOR}\n"
    exit
fi


## TODO


printf "${LIGHTCYAN}Installation finished. ${NOCOLOR}\n"
exit
