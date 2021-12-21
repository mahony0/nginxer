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

svhostname="hostname.tld"
show_verbose=true
install_php_56=true
install_php_70=true
install_php_71=true
install_php_72=true
install_php_73=true
install_php_74=true
install_php_80=true


printf "${YELLOW}###########################${NOCOLOR}\n"
printf "${YELLOW}# Virtualmin Setup Script #${NOCOLOR}\n"
printf "${YELLOW}###########################${NOCOLOR}\n"


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
## https://stackoverflow.com/a/26665585
##
chooserand() { echo ${1:RANDOM%${#1}:1} $RANDOM; }
randpass() {
    pass="$({
        for i in $(seq 1 32)
        do
            chooserand '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^\&'
        done
    } | sort -R | awk '{printf "%s",$1}')"

    echo "$pass"
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

OS=""
if [[ "$platform_info" == *"Debian"* ]]; then
    OS="Debian"
elif [[ "$platform_info" == *"Ubuntu"* ]]; then
    OS="Ubuntu"
fi

if [[ "$OS" != "Debian" ]] && [[ "$OS" != "Ubuntu" ]]; then
    printf "${LIGHTRED}[ERR] This script can be run under Debian or Ubuntu ${NOCOLOR}\n"
    exit
fi


##
## Update System
##
if ask "Update System?" Y; then
    apt-get update -y
    apt-get upgrade -y
fi


##
## Generate Locale for en_US.UTF-8
##
if ask "Generate Locale for en_US.UTF-8?" Y; then
    echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale
    locale-gen en_US.UTF-8
fi


##
## Install Some PPAs and Basic Packages
##
if ask "Install PPAs and Basic Packages?" Y; then
    apt-get install software-properties-common unzip curl wget git gnupg2 ca-certificates lsb-release apt-transport-https -y
fi


##
## Install virtualmin (minimal, LAMP)
##
if ask "Install virtualmin (minimal, LAMP)?" Y; then
    wget http://software.virtualmin.com/gpl/scripts/install.sh
    /bin/sh ./install.sh --minimal --bundle LAMP --hostname "${svhostname}"

    printf "${LIGHTCYAN}[INFO] Generating webmin root password ${NOCOLOR}\n"
    randpass=$(randpass)
    echo "webmin root user password: ${randpass}"
    /usr/share/webmin/changepass.pl /etc/webmin root "$randpass"
fi


##
## Install Multiple PHP Versions
##
if ask "Install Multiple PHP Versions?" Y; then
    apt-get install php-fpm php-imagick php-memcached php-redis php-xdebug php-dev -y

    if [[ "$OS" == "Debian" ]]; then
        wget -q https://packages.sury.org/php/apt.gpg -O- | apt-key add -
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
    elif [[ "$OS" == "Ubuntu" ]]; then
        yes y | LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php
    fi

    apt-get update -y
    apt-get upgrade -y

    if [ "$install_php_56" = true ]; then
        apt-get install -y \
        php5.6 php5.6-bcmath php5.6-bz2 php5.6-common php5.6-curl php5.6-fpm php5.6-gd php5.6-gmp php5.6-imap \
        php5.6-intl php5.6-mbstring php5.6-mysql php5.6-odbc php5.6-opcache php5.6-pgsql php5.6-soap php5.6-sqlite3 \
        php5.6-xml php5.6-zip php5.6-json php5.6-mcrypt

        sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/5.6/fpm/php.ini
        sed -i "s/memory_limit = .*/memory_limit = 256M/" /etc/php/5.6/fpm/php.ini
        sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php/5.6/fpm/php.ini
        sed -i "s/post_max_size = .*/post_max_size = 100M/" /etc/php/5.6/fpm/php.ini

        printf "[openssl]\n" | tee -a /etc/php/5.6/fpm/php.ini
        printf "openssl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/5.6/fpm/php.ini

        printf "[curl]\n" | tee -a /etc/php/5.6/fpm/php.ini
        printf "curl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/5.6/fpm/php.ini
    fi

    if [ "$install_php_70" = true ]; then
        apt-get install -y \
        php7.0 php7.0-bcmath php7.0-bz2 php7.0-common php7.0-curl php7.0-fpm php7.0-gd php7.0-gmp php7.0-imap \
        php7.0-intl php7.0-mbstring php7.0-mysql php7.0-odbc php7.0-opcache php7.0-pgsql php7.0-soap php7.0-sqlite3 \
        php7.0-xml php7.0-zip php7.0-json php7.0-mcrypt

        sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.0/fpm/php.ini
        sed -i "s/memory_limit = .*/memory_limit = 256M/" /etc/php/7.0/fpm/php.ini
        sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php/7.0/fpm/php.ini
        sed -i "s/post_max_size = .*/post_max_size = 100M/" /etc/php/7.0/fpm/php.ini

        printf "[openssl]\n" | tee -a /etc/php/7.0/fpm/php.ini
        printf "openssl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/7.0/fpm/php.ini

        printf "[curl]\n" | tee -a /etc/php/7.0/fpm/php.ini
        printf "curl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/7.0/fpm/php.ini
    fi

    if [ "$install_php_71" = true ]; then
        apt-get install -y \
        php7.1 php7.1-bcmath php7.1-bz2 php7.1-common php7.1-curl php7.1-fpm php7.1-gd php7.1-gmp php7.1-imap \
        php7.1-intl php7.1-mbstring php7.1-mysql php7.1-odbc php7.1-opcache php7.1-pgsql php7.1-soap php7.1-sqlite3 \
        php7.1-xml php7.1-zip php7.1-json php7.1-mcrypt

        sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.1/fpm/php.ini
        sed -i "s/memory_limit = .*/memory_limit = 256M/" /etc/php/7.1/fpm/php.ini
        sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php/7.1/fpm/php.ini
        sed -i "s/post_max_size = .*/post_max_size = 100M/" /etc/php/7.1/fpm/php.ini

        printf "[openssl]\n" | tee -a /etc/php/7.1/fpm/php.ini
        printf "openssl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/7.1/fpm/php.ini

        printf "[curl]\n" | tee -a /etc/php/7.1/fpm/php.ini
        printf "curl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/7.1/fpm/php.ini
    fi

    if [ "$install_php_72" = true ]; then
        apt-get install -y \
        php7.2 php7.2-bcmath php7.2-bz2 php7.2-common php7.2-curl php7.2-fpm php7.2-gd php7.2-gmp php7.2-imap \
        php7.2-intl php7.2-mbstring php7.2-mysql php7.2-odbc php7.2-opcache php7.2-pgsql php7.2-soap php7.2-sqlite3 \
        php7.2-xml php7.2-zip php7.2-json

        sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.2/fpm/php.ini
        sed -i "s/memory_limit = .*/memory_limit = 256M/" /etc/php/7.2/fpm/php.ini
        sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php/7.2/fpm/php.ini
        sed -i "s/post_max_size = .*/post_max_size = 100M/" /etc/php/7.2/fpm/php.ini

        printf "[openssl]\n" | tee -a /etc/php/7.2/fpm/php.ini
        printf "openssl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/7.2/fpm/php.ini

        printf "[curl]\n" | tee -a /etc/php/7.2/fpm/php.ini
        printf "curl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/7.2/fpm/php.ini
    fi

    if [ "$install_php_73" = true ]; then
        apt-get install -y \
        php7.3 php7.3-bcmath php7.3-bz2 php7.3-common php7.3-curl php7.3-fpm php7.3-gd php7.3-gmp php7.3-imap \
        php7.3-intl php7.3-mbstring php7.3-mysql php7.3-odbc php7.3-opcache php7.3-pgsql php7.3-soap php7.3-sqlite3 \
        php7.3-xml php7.3-zip php7.3-json

        sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.3/fpm/php.ini
        sed -i "s/memory_limit = .*/memory_limit = 256M/" /etc/php/7.3/fpm/php.ini
        sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php/7.3/fpm/php.ini
        sed -i "s/post_max_size = .*/post_max_size = 100M/" /etc/php/7.3/fpm/php.ini

        printf "[openssl]\n" | tee -a /etc/php/7.3/fpm/php.ini
        printf "openssl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/7.3/fpm/php.ini

        printf "[curl]\n" | tee -a /etc/php/7.3/fpm/php.ini
        printf "curl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/7.3/fpm/php.ini
    fi

    if [ "$install_php_74" = true ]; then
        apt-get install -y \
        php7.4 php7.4-bcmath php7.4-bz2 php7.4-common php7.4-curl php7.4-fpm php7.4-gd php7.4-gmp php7.4-imap \
        php7.4-intl php7.4-mbstring php7.4-mysql php7.4-odbc php7.4-opcache php7.4-pgsql php7.4-soap php7.4-sqlite3 \
        php7.4-xml php7.4-zip php7.4-json

        sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.4/fpm/php.ini
        sed -i "s/memory_limit = .*/memory_limit = 256M/" /etc/php/7.4/fpm/php.ini
        sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php/7.4/fpm/php.ini
        sed -i "s/post_max_size = .*/post_max_size = 100M/" /etc/php/7.4/fpm/php.ini

        printf "[openssl]\n" | tee -a /etc/php/7.4/fpm/php.ini
        printf "openssl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/7.4/fpm/php.ini

        printf "[curl]\n" | tee -a /etc/php/7.4/fpm/php.ini
        printf "curl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/7.4/fpm/php.ini
    fi

    if [ "$install_php_80" = true ]; then
        apt-get install -y \
        php8.0 php8.0-bcmath php8.0-bz2 php8.0-common php8.0-curl php8.0-fpm php8.0-gd php8.0-gmp php8.0-imap \
        php8.0-intl php8.0-mbstring php8.0-mysql php8.0-odbc php8.0-opcache php8.0-pgsql php8.0-soap php8.0-sqlite3 \
        php8.0-xml php8.0-zip

        sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/8.0/fpm/php.ini
        sed -i "s/memory_limit = .*/memory_limit = 256M/" /etc/php/8.0/fpm/php.ini
        sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php/8.0/fpm/php.ini
        sed -i "s/post_max_size = .*/post_max_size = 100M/" /etc/php/8.0/fpm/php.ini

        printf "[openssl]\n" | tee -a /etc/php/8.0/fpm/php.ini
        printf "openssl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/8.0/fpm/php.ini

        printf "[curl]\n" | tee -a /etc/php/8.0/fpm/php.ini
        printf "curl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/8.0/fpm/php.ini

        update-alternatives --set php /usr/bin/php8.0
    fi
fi


##
## Restart PHPs
##
if ask "Restart PHPs?" Y; then
    if [ "$install_php_56" = true ]; then
        systemctl restart php5.6-fpm
        if [ "$show_verbose" = true ]; then
            printf "${LIGHTCYAN}[INFO] systemctl status php5.6-fpm: ${NOCOLOR}\n"
            systemctl status php5.6-fpm
        fi
    fi
    if [ "$install_php_70" = true ]; then
        systemctl restart php7.0-fpm
        if [ "$show_verbose" = true ]; then
            printf "${LIGHTCYAN}[INFO] systemctl status php7.0-fpm: ${NOCOLOR}\n"
            systemctl status php7.0-fpm
        fi
    fi
    if [ "$install_php_71" = true ]; then
        systemctl restart php7.1-fpm
        if [ "$show_verbose" = true ]; then
            printf "${LIGHTCYAN}[INFO] systemctl status php7.1-fpm: ${NOCOLOR}\n"
            systemctl status php7.1-fpm
        fi
    fi
    if [ "$install_php_72" = true ]; then
        systemctl restart php7.2-fpm
        if [ "$show_verbose" = true ]; then
            printf "${LIGHTCYAN}[INFO] systemctl status php7.2-fpm: ${NOCOLOR}\n"
            systemctl status php7.2-fpm
        fi
    fi
    if [ "$install_php_73" = true ]; then
        systemctl restart php7.3-fpm
        if [ "$show_verbose" = true ]; then
            printf "${LIGHTCYAN}[INFO] systemctl status php7.3-fpm: ${NOCOLOR}\n"
            systemctl status php7.3-fpm
        fi
    fi
    if [ "$install_php_74" = true ]; then
        systemctl restart php7.4-fpm
        if [ "$show_verbose" = true ]; then
            printf "${LIGHTCYAN}[INFO] systemctl status php7.4-fpm: ${NOCOLOR}\n"
            systemctl status php7.4-fpm
        fi
    fi
    if [ "$install_php_80" = true ]; then
        systemctl restart php8.0-fpm
        if [ "$show_verbose" = true ]; then
            printf "${LIGHTCYAN}[INFO] systemctl status php8.0-fpm: ${NOCOLOR}\n"
            systemctl status php8.0-fpm
        fi
    fi
fi


##
## Enable PHP-FPM, mpm_event, http2 and apache mod headers
##
if ask "Enable PHP-FPM, mpm_event, http2 and apache mod headers?" Y; then
    a2dismod php8.0
    a2enconf php8.0-fpm
    a2enmod proxy_fcgi

    systemctl restart apache2

    a2dismod mpm_prefork
    a2enmod mpm_event

    a2enmod http2
    systemctl restart apache2

    a2enmod headers
    systemctl restart apache2
fi
