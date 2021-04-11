# Debian & Ubuntu Webserver Setup Script

> This script will install following components by separated prompts:
> - System update/upgrade
> - Nginx
> - Generate self-signed SSL cert for Nginx
> - ufw
> - MariaDB
> - PHP (5.6, 7.0, 7.1, 7.2, 7.3, 7.4, 8.0)
> - vsftpd
> - Composer


### Tested OSes

- [x] Debian 10 (buster)
- [ ] Debian 9 (stretch)
- [x] Ubuntu 20.04
- [ ] Ubuntu 18.04
- [ ] Ubuntu 16.04


### Notes for defaults

- You can disable some php versions from installing by assinging false to the variable (etc: **install_php_56=false**)
- This script is using stable repositories for Nginx so folder structures will be different than Debian/Ubuntu's default.
- Single file for fastcgi config used **/etc/nginx/fastcgi_params**
- Nginx servers will be included from **/etc/nginx/conf.d/*.conf** (you can disable any server by renaming it from **server.conf** to **server.disabled** etc.)
- default folder for any domain will be **/var/www/domain.tld/** (script folder will be **/var/www/domain.tld/html/**)
- default folder for any subdomain will be **/var/www/domain.tld/subdomain.domain.tld/** (script folder will be **/var/www/domain.tld/subdomain.domain.tld/html/**)
- default logs folder for any domain will be **/var/www/domain.tld/logs/**


> ### Extra Documents
>
> #### LEMP Setup Docs
> - https://www.digitalocean.com/community/tutorials/how-to-install-linux-nginx-mariadb-php-lemp-stack-on-debian-10
> #### ufw Firewall Setup Docs
> - https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-with-ufw-on-debian-10
> #### SSL Cert Setup Docs
> - https://www.digitalocean.com/community/tutorials/how-to-create-a-self-signed-ssl-certificate-for-nginx-on-debian-10
> #### Nginx SSL/TLS configuration with TLSv1.2 and TLSv1.3 - ECDHE and strong ciphers suite (Openssl 1.1.1)
> - https://gist.github.com/VirtuBox/7d432c3c3d134cc3cb7e98b30a76c287
> #### For non-interactive MariaDB installation
> - https://dba.stackexchange.com/questions/35866/install-mariadb-without-password-prompt-in-ubuntu
> #### vsftpd Setup Docs
> - https://www.digitalocean.com/community/tutorials/how-to-set-up-vsftpd-for-a-user-s-directory-on-debian-10
> - https://blog.binaryspaceship.com/2017/complete-installation-guide-lemp-debian8/#43_Configure_vsftpd
> #### Laravel Settler Example
> - https://github.com/laravel/settler/blob/master/scripts/provision.sh


### EXTRA - MariaDB Creating New Database
#### mariadb
    CREATE DATABASE example_database;
    GRANT ALL ON example_database.* TO 'example_user'@'localhost' IDENTIFIED BY 'PASSWORD' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
    exit

### EXTRA - Create Web User With www-data Association
    adduser --gecos "" NEWUSERNAME
    passwd NEWUSERNAME
    usermod -a -G NEWUSERNAME www-data

### EXTRA - Generate vsftpd User Folder and Bind With Domain Home Folder
    mkdir -p /etc/vsftpd/users/NEWUSERNAME
    chown NEWUSERNAME:NEWUSERNAME /etc/vsftpd/users/NEWUSERNAME
    mount --bind /var/www/domain.tld /etc/vsftpd/users/NEWUSERNAME

### EXTRA - Generate Nginx Folders (for sub.domain.tld)
    mkdir -p /var/www/domain.tld/sub.domain.tld/html
    mkdir -p /var/www/domain.tld/sub.domain.tld/logs
    chown -R $USER:$USER /var/www/domain.tld/
    nano /etc/nginx/sites-available/sub.domain.tld.conf
