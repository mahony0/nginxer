#!/usr/bin/php
<?php

/**
 * Mandatory:
 * php create.php --domain="domain.tld"
 *
 * Creating with a system user:
 * php create.php --domain="domain.tld" --uname="USER"
 *
 * Creating with a database:
 * php create.php --domain="domain.tld" --dbname="DB_NAME" --dbuname="DB_USER_NAME" --dbupass="DB_USER_PASS"
 *
 * Full installation:
 * php create.php --domain="domain.tld" --uname="USER" --dbname="DB_NAME" --dbuname="DB_USER_NAME" --dbupass="DB_USER_PASS"
 *
 * Sections:
 * 1. Basic checks
 * 2. Create general variables
 * 3. Parse subdomain, domain and domain real extension
 * 4. OPTIONAL - Generate nginx.conf file and reload nginx
 * 5. OPTIONAL - Create domain folders if not already created
 * 6. OPTIONAL - Copy script zipfile and unzip in html dir
 * 7. OPTIONAL - Create a system user if not creating a subdomain
 * 8. OPTIONAL - Create a database and related user
 * 9. OPTIONAL - Import database
 */

include_once __DIR__.'/ColoredBashPrinter.php';
include_once __DIR__.'/helpers.php';

$printer = new ColoredBashPrinter();


/**
 * 1. Basic checks
 */
if (PHP_SAPI !== 'cli') {
    echo $printer->getErrorString('ERR: cli only');
    exit;
}

$params = getopt('', ['domain::']);
if (empty($params['domain'])) {
    echo $printer->getErrorString('ERR: domain parameter missing');
    exit;
}

if (!$extension = checkTLD($params['domain'])) {
    echo $printer->getErrorString('ERR: invalid domain suffix');
    exit;
}


/**
 * 2. Create general variables
 */
$subdomain = null;
$domainWithExt = null;
$subdomainWithDomainExt = null;
$actualBaseDomain = null;
$nginxConfFileName = null;
$templateName = null;

$dbHost = 'localhost';
$dbUsername = 'root';
$dbPassword = '';

$phpVer = '7.4';
$latestScriptZip = 'zips/octobercms-468.zip';
$latestDbBackup = 'zips/octobercms-468.sql';


/**
 * 3. Parse subdomain, domain and domain real extension
 */
$parseDomAndSub = explode('.', rtrim($params['domain'], '.'.$extension));
if (!empty($parseDomAndSub[1])) {
    $domain = array_pop($parseDomAndSub);
    $subdomain = implode('.', $parseDomAndSub);

    echo $printer->getParamString('PARAM: subdomain: '.$subdomain.' *** domain: '.$domain.' *** suffix: '.$extension);
    echo $printer->getInfoString('INFO: performing subdomain installation..');
} else {
    $domain = array_pop($parseDomAndSub);

    echo $printer->getParamString('PARAM: domain: '.$domain.' *** suffix: '.$extension);
    echo $printer->getInfoString('INFO: performing domain installation..');
}
$domainWithExt = $domain.'.'.$extension;
$subdomainWithDomainExt = $subdomain.'.'.$domain.'.'.$extension;

if ($subdomain) {
    # /var/www/domain.tld/sub.domain.tld/html
    $actualBaseDomain = $domainWithExt.'/'.$subdomainWithDomainExt;
} else {
    # /var/www/domain.tld/html
    $actualBaseDomain = $domainWithExt;
}


/**
 * 4. OPTIONAL - Generate nginx.conf file and reload nginx
 */
if ($answer = consoleAsk('The nginx.conf file will be created for the domain. Continue?')) {
    echo $printer->getInfoString('INFO: PHP ver: '.$phpVer);

    $generationResult = generateNginxConfFile($printer, $phpVer, $subdomain, $domainWithExt, $subdomainWithDomainExt);
    $nginxConfFileName = $generationResult[0];
    $templateName = $generationResult[1];

    echo $printer->getInfoString('INFO: nginx.conf created');

    /*
     * create symlink for nginx.conf file
     */
    if (!$createSymlink = `ln -s {$nginxConfFileName} /etc/nginx/sites-enabled/`) {
        echo $printer->getErrorString('ERR: Could not create symlink for nginx.conf, manual action is required. Process continues..');
    } else {
        /*
         * check nginx config
         */
        echo `nginx -t`;
        if ($answer = consoleAsk('Review the nginx test result to avoid errors. do nginx reload?')) {
            echo $printer->getInfoString('INFO: Performing nginx reload: systemctl reload nginx..');

            if ($reloadNginx = `systemctl reload nginx`) {
                echo $printer->getInfoString('INFO: nginx reload done');
            }
        } else {
            echo $printer->getErrorString('ERR: Continuing without nginx reload. Nginx should be reloaded manually after fixing any errors.');
        }
    }
} else {
    echo $printer->getInfoString('INFO: Continuing without creating nginx.conf..');
}


/**
 * 5. OPTIONAL - Create domain folders if not already created
 */
if ($answer = consoleAsk('Create directories for domain?')) {
    if ($isDirExist = is_dir($actualBaseDomain)) {
        echo $printer->getErrorString('ERR: -'.$domainWithExt."/".$subdomainWithDomainExt.'- directory created previously');
    } else {
        createDomainFolders($printer, $subdomain, $domainWithExt, $subdomainWithDomainExt);
    }
} else {
    echo $printer->getInfoString('INFO: Continuing without creating directories..');
}


/**
 * 6. OPTIONAL - Copy script zipfile and unzip in html dir (if OctoberCMS selected)
 */
if ($templateName == 'octo') {
    if ($answer = consoleAsk('Do you want to extract the last uploaded script zip file ('.$latestScriptZip.') to the domain html directory?')) {
        echo $printer->getInfoString('INFO: The website script is unziped..');

        $latestScriptZipTargetPath = pathinfo(realpath($actualBaseDomain.'/html/'), PATHINFO_DIRNAME);
        unzipWebsiteFiles($printer, $latestScriptZip, $latestScriptZipTargetPath);
    } else {
        echo $printer->getInfoString('INFO: Continuing without unzip operation..');
    }
}


/**
 * 7. OPTIONAL - Create a system user if not creating a subdomain
 *
 * https://blog.binaryspaceship.com/2017/complete-installation-guide-lemp-debian8/#43_Configure_vsftpd
 * https://www.digitalocean.com/community/tutorials/how-to-set-up-vsftpd-for-a-user-s-directory-on-debian-10
 */
if (!$subdomain) {
    if ($answer = consoleAsk('Create a system user for this domain?')) {
        $params = getopt('', ['uname::']);
        if (empty($params['uname'])) {
            echo $printer->getErrorString('ERR: Uname parameter missing to create system user');
            exit;
        }

        $uname = $params['uname'];

        echo $printer->getInfoString('INFO: system user ('.$uname.') is creating..');

        `adduser --gecos "" {$uname}`;
        `passwd {$uname}`;
        `usermod -a -G {$uname} www-data`;

        echo $printer->getInfoString('INFO: user home directory and /var/www/ sub folder is binding..');
        `mkdir -p /etc/vsftpd/users/{$uname}/{$domainWithExt}`;
        `chown {$uname}:{$uname} /etc/vsftpd/users/{$uname}/{$domainWithExt}`;
        `mount --bind /var/www/{$domainWithExt} /etc/vsftpd/users/{$uname}/{$domainWithExt}`;

        if ($answer = consoleAsk('vsftpd restart required. Continue?')) {
            echo $printer->getInfoString('INFO: vsftpd restart..');
            `service vsftpd restart`;
            sleep(1);
            `service vsftpd status`;
        } else {
            echo $printer->getErrorString('ERR: Continuing without vsftpd restart. vsftpd has to be restarted manually');
        }
    } else {
        echo $printer->getInfoString('INFO: Continuing without system user creation..');
    }
}


/**
 * 8. OPTIONAL - Create a database and related user
 */
if ($answer = consoleAsk('Should the database and user be created?')) {
    $params = getopt('', ['dbname::', 'dbuname::', 'dbupass::']);
    if (empty($params['dbname']) || empty($params['dbuname']) || empty($params['dbupass'])) {
        echo $printer->getErrorString('ERR: The dbname, dbuname and dbupass parameters are required to create the database and its user');
        exit;
    }

    $dbname = $params['dbname'];
    $dbuname = $params['dbuname'];
    $dbupass = $params['dbupass'];

    // Conenct to DB
    try {
        $dbh = new PDO("mysql:host={$dbHost};", $dbUsername, $dbPassword);
        $dbh->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    } catch(PDOException $e) {
        echo $printer->getErrorString('ERR: Database connection failed: '.$e->getMessage());
        exit;
    }

    echo $printer->getInfoString('INFO: Database user ('.$dbuname.') and database ('.$dbname.') creating..');
    try {
        $dbh->exec("CREATE DATABASE `$dbname`;
                CREATE USER '$dbuname'@'$dbHost' IDENTIFIED BY '$dbupass';
                GRANT ALL PRIVILEGES ON `$dbname`.* TO '$dbuname'@'$dbHost';
                FLUSH PRIVILEGES;")
        || die( $printer->getErrorString('ERR: Sql exec failed: '.$dbh->errorInfo()) );

        echo $printer->getInfoString('INFO: DB Database and user created');
    } catch(PDOException $e) {
        echo $printer->getErrorString('ERR: Sql query failed: '.$e->getMessage());
        exit;
    }

    // Close connection
    unset($dbh);
} else {
    echo $printer->getInfoString('INFO: Continuing without creating the database and user..');
}


/**
 * 9. OPTIONAL - Import database (if OctoberCMS selected)
 * TODO: this needs to be changed for broader usage
 */
if ($templateName == 'octo') {
    if ($answer = consoleAsk('Import the last uploaded database backup ('.$latestDbBackup.') file?')) {
        $params = getopt('', ['dbname::']);
        if (empty($params['dbname'])) {
            echo $printer->getErrorString('ERR: The dbname parameter is required for database import');
            exit;
        }

        $dbname = $params['dbname'];

        $latestDbBackupTargetPath = realpath($latestDbBackup);
        `mysql {$dbname} < {$latestDbBackupTargetPath}`;

        echo $printer->getInfoString('INFO: Database import complete');
    } else {
        echo $printer->getInfoString('INFO: Continuing without importing the database..');
    }
}
