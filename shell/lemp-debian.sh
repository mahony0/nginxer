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


printf "${YELLOW}#################################################${NOCOLOR}\n"
printf "${YELLOW}# Debian & Ubuntu Webserver Setup Script * v1.2 #${NOCOLOR}\n"
printf "${YELLOW}#################################################${NOCOLOR}\n"


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

OS=""
if [[ "$platform_info" == *"Debian"* ]]; then
    OS="Debian"
elif [[ "$platform_info" == *"Ubuntu"* ]]; then
    OS="Ubuntu"
fi

if [[ "$OS" != "Debian" ]] && [[ "$OS" != "Ubuntu" ]]; then
    printf "${LIGHTRED}[ERR] This script can be run under debian or ubuntu OSes ${NOCOLOR}\n"
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
## Force and Generate Locale to en_US.UTF-8
##
if ask "Force and Generate Locale to en_US.UTF-8?" Y; then
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
## Install Nginx
##
if ask "Install Nginx?" Y; then
    wget -q https://nginx.org/keys/nginx_signing.key -O- | apt-key add -

    # install nginx from stable repo
    if [[ "$OS" == "Debian" ]]; then
        cat > /etc/apt/sources.list.d/nginx.list <<EOF
deb [arch=amd64] https://nginx.org/packages/debian/ $(lsb_release -sc) nginx
deb-src https://nginx.org/packages/debian/ $(lsb_release -sc) nginx
EOF
    elif [[ "$OS" == "Ubuntu" ]]; then
        cat > /etc/apt/sources.list.d/nginx.list <<EOF
deb [arch=amd64] https://nginx.org/packages/ubuntu/ $(lsb_release -sc) nginx
deb-src https://nginx.org/packages/ubuntu/ $(lsb_release -sc) nginx
EOF
    fi

    apt-get remove nginx-common -y
    apt-get update -y
    apt-get install nginx -y
    systemctl restart nginx
fi


##
## Setup fastcgi_params and create required folders
##
if ask "Setup fastcgi_params and create required folders?" Y; then
    # as we installed nginx from the source, some folders like snippets or /var/www not exist
    [[ -d /etc/nginx/snippets ]] || mkdir /etc/nginx/snippets
    [[ -d /var/www ]] || mkdir /var/www

    # chown -R nginx:nginx /var/www

    cat > /etc/nginx/fastcgi_params << EOF
# regex to split \$uri to \$fastcgi_script_name and \$fastcgi_path
fastcgi_split_path_info ^(.+\.php)($|/.*);

# Bypass the fact that try_files resets \$fastcgi_path_info
# see: http://trac.nginx.org/nginx/ticket/321
set \$path_info \$fastcgi_path_info;

# Check that the PHP script exists before passing it
try_files \$fastcgi_script_name =404;

fastcgi_index index.php;

fastcgi_param    QUERY_STRING           \$query_string;
fastcgi_param    REQUEST_METHOD         \$request_method;
fastcgi_param    CONTENT_TYPE           \$content_type;
fastcgi_param    CONTENT_LENGTH         \$content_length;

fastcgi_param    SCRIPT_FILENAME        \$document_root\$fastcgi_script_name;
fastcgi_param    SCRIPT_NAME            \$fastcgi_script_name;
fastcgi_param    PATH_INFO              \$path_info;
fastcgi_param    PATH_TRANSLATED        \$document_root\$fastcgi_script_name;
fastcgi_param    REQUEST_URI            \$request_uri;
fastcgi_param    DOCUMENT_URI           \$document_uri;
fastcgi_param    DOCUMENT_ROOT          \$document_root;
fastcgi_param    SERVER_PROTOCOL        \$server_protocol;

fastcgi_param    GATEWAY_INTERFACE      CGI/1.1;
fastcgi_param    SERVER_SOFTWARE        nginx/\$nginx_version;

fastcgi_param    REMOTE_ADDR            \$remote_addr;
fastcgi_param    REMOTE_PORT            \$remote_port;
fastcgi_param    SERVER_ADDR            \$server_addr;
fastcgi_param    SERVER_PORT            \$server_port;
fastcgi_param    SERVER_NAME            \$server_name;

fastcgi_param    HTTPS                  \$https;

fastcgi_param    REDIRECT_STATUS        200;
EOF
fi


##
## Install Default SSL Cert and dhparams for Nginx
##
if ask "Install Default SSL Cert and dhparams for Nginx?" Y; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -subj "/C=US/ST=State/L=Locality/O=Organization/OU=IT Department/CN=example.com" \
        -keyout /etc/ssl/private/nginx-selfsigned.key \
        -out /etc/ssl/certs/nginx-selfsigned.crt

    # Diffie-Hellman parameter for DHE ciphersuites
    openssl dhparam -out /etc/nginx/dhparam.pem 4096

    cat > /etc/nginx/snippets/self-signed.conf <<EOF
ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
EOF

    cat > /etc/nginx/snippets/ssl-params.conf <<EOF
ssl_dhparam /etc/nginx/dhparam.pem;

ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'TLS13+AESGCM+AES128:EECDH+AES128';
ssl_prefer_server_ciphers off;
ssl_ecdh_curve X25519:sect571r1:secp521r1:secp384r1;

ssl_session_timeout  10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;

ssl_stapling on;
ssl_stapling_verify on;

resolver 1.1.1.1 1.0.0.1 [2606:4700:4700::1111] [2606:4700:4700::1001] valid=300s;
resolver_timeout 5s;
EOF
fi


##
## Hide nginx version number and activate SSL in default Nginx server
##
if ask "Hide nginx version number and activate SSL in default Nginx server?" Y; then

    sed -i "/server_name .*;/alisten 443 ssl http2;\nlisten [::]:443 ssl http2;\nproxy_pass_header Server;\nserver_tokens off;\ninclude snippets/self-signed.conf;\ninclude snippets/ssl-params.conf;" /etc/nginx/conf.d/default.conf

    nginx -t
    systemctl restart nginx
fi


##
## Install ufw
##
if ask "Install ufw?" Y; then
    apt-get install ufw -y
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp

    yes y | ufw enable

    if [ "$show_verbose" = true ]; then
        printf "${LIGHTCYAN}[INFO] ufw status verbose: ${NOCOLOR}\n"
        ufw status verbose
    fi
fi


##
## Install MariaDB
##
if ask "Install MariaDB?" Y; then
    GEN_PWD=$(date +%s|sha256sum|base64|head -c 32)

    export DEBIAN_FRONTEND="noninteractive"

    debconf-set-selections <<< "mariadb-server mysql-server/root_password password $GEN_PWD"
    debconf-set-selections <<< "mariadb-server mysql-server/root_password_again password $GEN_PWD"

    apt-get install mariadb-server -y

    export DEBIAN_FRONTEND="dialog"

    printf "${LIGHTCYAN}[INFO] PLEASE NOTE IT SECURELY, Generated random MariaDB root pass: $GEN_PWD ${NOCOLOR}\n"
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
## Install vsftpd
##
if ask "Install vsftpd?" Y; then
    apt-get install vsftpd -y
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -subj "/C=US/ST=State/L=Locality/O=Organization/OU=IT Department/CN=example.com" \
        -keyout /etc/ssl/private/vsftpd.pem \
        -out /etc/ssl/private/vsftpd.pem

    cp /etc/vsftpd.conf /etc/vsftpd.conf.orig

    sed -i "s/#write_enable=YES/write_enable=YES/" /etc/vsftpd.conf
    sed -i "s@rsa_cert_file=.*@# rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem@" /etc/vsftpd.conf
    sed -i "s@rsa_private_key_file=.*@# rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key@" /etc/vsftpd.conf
    sed -i "s/ssl_enable=NO/# ssl_enable=NO/" /etc/vsftpd.conf

    tee -a /etc/vsftpd.conf << END
# Important! Proper umask for uploaded files.
local_umask=022
file_open_mode=0666

# restrict user to home dir
chroot_local_user=YES
user_sub_token=\$USER
local_root=/etc/vsftpd/users/\$USER

# Enable SSL
rsa_cert_file=/etc/ssl/private/vsftpd.pem
rsa_private_key_file=/etc/ssl/private/vsftpd.pem
ssl_enable=YES
allow_anon_ssl=NO
force_local_data_ssl=YES
force_local_logins_ssl=YES
ssl_tlsv1=NO
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO
# ssl_ciphers=HIGH
ssl_ciphers=ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256

# Enable passive transferring mode
pasv_enable=YES
pasv_min_port=62100
pasv_max_port=62500
port_enable=YES

# Show hidden files for FTP client
force_dot_files=YES
END

    ufw allow 20/tcp
    ufw allow 21/tcp
    ufw allow 989/tcp
    ufw allow 990/tcp
    ufw allow 62100:62500/tcp
    if [ "$show_verbose" = true ]; then
        printf "${LIGHTCYAN}[INFO] ufw status verbose: ${NOCOLOR}\n"
        ufw status verbose
    fi

    systemctl restart vsftpd

    if [ "$show_verbose" = true ]; then
        printf "${LIGHTCYAN}[INFO] systemctl status vsftpd: ${NOCOLOR}\n"
        systemctl status vsftpd

        printf "${LIGHTCYAN}[INFO] vsftp error check (if any): ${NOCOLOR}\n"
        journalctl | grep -i vsftp
    fi
fi


##
## Install Composer
##
if ask "Install Composer?" Y; then
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
fi


printf "${LIGHTCYAN}Installation finished. ${NOCOLOR}\n"
exit
