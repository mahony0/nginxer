<?php

/**
 * http://publicsuffix.org/
 * http://www.alandix.com/blog/code/public-suffix/
 * http://tobyinkster.co.uk/blog/2007/07/19/php-domain-class/
 *
 * https://stackoverflow.com/a/9917859
 *
 * @param null|string $url_or_domain
 *
 * @return bool|string|null
 */
function checkTLD($url_or_domain = null)
{
    $domain = $url_or_domain ?: $_SERVER['HTTP_HOST'];
    preg_match('/^[a-z]+:\/\//i', $domain) && $domain = parse_url($domain, PHP_URL_HOST);
    $domain = mb_strtolower($domain, 'UTF-8');
    if (strpos($domain, '.') === false) {
        return null;
    }

    // $url = 'http://mxr.mozilla.org/mozilla-central/source/netwerk/dns/effective_tld_names.dat?raw=1';
    // $url = 'https://publicsuffix.org/list/effective_tld_names.dat';
    $url = 'https://publicsuffix.org/list/public_suffix_list.dat';

    if (($rules = file($url)) !== false) {
        $rules = array_filter(array_map('trim', $rules));
        array_walk($rules, function($v, $k) use(&$rules) {
            if (strpos($v, '//') !== false) {
                unset($rules[$k]);
            }
        });

        $segments = '';
        foreach (array_reverse(explode('.', $domain)) as $s) {
            $wildcard = rtrim('*.'.$segments, '.');
            $segments = rtrim($s.'.'.$segments, '.');

            if (in_array('!'.$segments, $rules)) {
                $tld = substr($wildcard, 2);
                break;
            } elseif (in_array($wildcard, $rules) || in_array($segments, $rules)) {
                $tld = $segments;
            }
        }

        if (isset($tld)) {
            return $tld;
        }
    }

    return false;
}


/**
 * Copy a file, or recursively copy a folder and its contents
 * @author      Aidan Lister <aidan@php.net>
 * @version     1.0.1
 * @link        http://aidanlister.com/2004/04/recursively-copying-directories-in-php/
 * @param       string   $source    Source path
 * @param       string   $dest      Destination path
 * @param       int      $permissions New folder creation permissions
 * @return      bool     Returns true on success, false on failure
 */
function xcopy($source, $dest, $permissions = 0755)
{
    // Check for symlinks
    if (is_link($source)) {
        return symlink(readlink($source), $dest);
    }

    // Simple copy for a file
    if (is_file($source)) {
        return copy($source, $dest);
    }

    // Make destination directory
    if (!is_dir($dest)) {
        mkdir($dest, $permissions);
    }

    // Loop through the folder
    $dir = dir($source);
    while (false !== $entry = $dir->read()) {
        // Skip pointers
        if ($entry == '.' || $entry == '..') {
            continue;
        }

        // Deep copy directories
        xcopy("$source/$entry", "$dest/$entry", $permissions);
    }

    // Clean up
    $dir->close();
    return true;
}


function consoleAsk($question, $putYesNo = true, $returnResult = false)
{
    echo $putYesNo ? $question."  Yes: 'y', No: 'n': " : $question;

    $handle = fopen('php://stdin', 'r');
    $line = fgets($handle);
    fclose($handle);

    if ($returnResult) {
        return trim(strtolower($line));
    } else {
        return trim(strtolower($line)) == 'y';
    }
}


function generateNginxConfFile(ColoredBashPrinter $printer, $phpVer, $subdomain, $domainWithExt, $subdomainWithDomainExt)
{
    if ($subdomain) {
        $singleServerName = $subdomainWithDomainExt;
        $serverNameDirective = $subdomainWithDomainExt;
        $domainFolderDirective = $domainWithExt.'/'.$subdomainWithDomainExt;
        $nginxConfFileName = $subdomainWithDomainExt.'.conf';

        if ($isNginxConfExist = is_file($nginxConfFileName)) {
            echo $printer->getErrorString('ERR: -'.$nginxConfFileName.'- file already exists');
            exit;
        }
    } else {
        $singleServerName = $domainWithExt;
        $serverNameDirective = $domainWithExt.' '.'www.'.$domainWithExt;
        $domainFolderDirective = $domainWithExt;
        $nginxConfFileName = $domainWithExt.'.conf';

        if ($isNginxConfExist = is_file($nginxConfFileName)) {
            echo $printer->getErrorString('ERR: -'.$nginxConfFileName.'- file already exists');
            exit;
        }
    }

    $answer = consoleAsk("Which nginx template will be used?  PHP website: 'php', OctoberCMS: 'octo': ", false, true);
    if ($answer === 'octo') {
        $nginxTemplate = file_get_contents('stubs/octobercms.stub');
        echo $printer->getInfoString('INFO: continuing with octobercms nginx configs..');
    } elseif ($answer === 'php') {
        $nginxTemplate = file_get_contents('stubs/phpsite.stub');
        echo $printer->getInfoString('INFO: continuing with phpsite nginx configs..');
    } else {
        echo $printer->getErrorString('ERR: stub not found');
        exit;
    }

    $nginxTemplateFilled = sprintf($nginxTemplate, $serverNameDirective, $singleServerName, $domainFolderDirective, $domainFolderDirective, $domainFolderDirective, $phpVer);

    file_put_contents($nginxConfFileName, $nginxTemplateFilled);
    sleep(1);

    return [$nginxConfFileName, $answer];
}


function createDomainFolders(ColoredBashPrinter $printer, $subdomain, $domainWithExt, $subdomainWithDomainExt)
{
    if ($subdomain) {
        echo $printer->getInfoString('INFO: creating html, logs and error_docs folders..');
        `mkdir -p {$domainWithExt}/{$subdomainWithDomainExt}/html`;
        `mkdir -p {$domainWithExt}/{$subdomainWithDomainExt}/logs`;
        `mkdir -p {$domainWithExt}/{$subdomainWithDomainExt}/error_docs`;

        sleep(1);
        if (!$copyErrorDocs = xcopy('error_docs/', $domainWithExt.'/'.$subdomainWithDomainExt.'/error_docs')) {
            echo $printer->getErrorString('ERR: error_docs directory could not be copied, continuing..');
        }
        sleep(1);
    } else {
        echo $printer->getInfoString('INFO: creating html, logs and error_docs folders..');
        `mkdir -p {$domainWithExt}/html`;
        `mkdir -p {$domainWithExt}/logs`;
        `mkdir -p {$domainWithExt}/error_docs`;

        sleep(1);
        if (!$copyErrorDocs = xcopy('error_docs/', $domainWithExt.'/error_docs')) {
            echo $printer->getErrorString('ERR: error_docs directory could not be copied, continuing..');
        }
        sleep(1);
    }
}


function unzipWebsiteFiles(ColoredBashPrinter $printer, $latestScriptZip, $targetPath)
{
    $zip = new ZipArchive();
    $res = $zip->open($latestScriptZip);
    if ($res === true) {
        $zip->extractTo($targetPath);
        $zip->close();

        echo $printer->getInfoString('INFO: script unzip done');
    } else {
        echo $printer->getErrorString('ERR: script zip not found');
    }
}
