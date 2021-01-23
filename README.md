# WampServer SSL Auto Config

[![GitHub version](https://img.shields.io/github/tag/custom-dev-tools/WampServer-SSL-Auto-Config.svg?label=WampServer-SSL-Auto-Config&logo=github)](https://github.com/custom-dev-tools/WampServer-SSL-Auto-Config/releases) ![Maintained](https://img.shields.io/static/v1.svg?label=maintened&message=yes&color=informational&logo=github) [![Stars](https://img.shields.io/github/stars/custom-dev-tools/WampServer-SSL-Auto-Config.svg?color=brightgreen&logo=github)](https://github.com/custom-dev-tools/WampServer-SSL-Auto-Config/stargazers)
 
[![GitHub License](https://img.shields.io/github/license/custom-dev-tools/WampServer-SSL-Auto-Config.svg?color=informational&logo=github)](https://github.com/custom-dev-tools/WampServer-SSL-Auto-Config/blob/master/LICENSE) [![GitHub last commit](https://img.shields.io/github/last-commit/custom-dev-tools/WampServer-SSL-Auto-Config.svg?logo=github)](https://github.com/custom-dev-tools/WampServer-SSL-Auto-Config/commits/master) [![GitHub open issues](https://img.shields.io/github/issues-raw/custom-dev-tools/WampServer-SSL-Auto-Config.svg?color=brightgreen&logo=github)](https://github.com/custom-dev-tools/WampServer-SSL-Auto-Config/issues?q=is%3Aopen+is%3Aissue) [![GitHub closed issues](https://img.shields.io/github/issues-closed-raw/custom-dev-tools/WampServer-SSL-Auto-Config.svg?color=brightgreen&logo=github)](https://github.com/custom-dev-tools/WampServer-SSL-Auto-Config/issues?q=is%3Aissue+is%3Aclosed)

WampServer SSL Auto Config is a Microsoft Windows batch script designed to automatically generate and configure a fully working Apache SSL / Name Based virtual host development environment with optional HTTP/2 functionality.

## Table of Contents

* [Introduction](#introduction)
* [Minimum Requirements](#minimum-requirements)
* [Compatible Web Browsers](#compatible-web-browsers)
* [Installation](#installation)
* [Configuration](#configuration)
  * [WampServer Configuration](#wampserver-configuration)
  * [SSL Certificate Details](#ssl-certificate-details)
  * [Development Domains](#development-domains)
* [How To Use](#how-to-use)
  * [The SSL Config Function](#the-ssl-config-function)
    * [The Created Folder Structure](#the-created-folder-structure)
  * [The Restore Function](#the-restore-function)
* [Configurable Web Browsers](#configurable-web-browsers)
  * [How To Configure Firefox](#how-to-configure-firefox)
  * [How To Configure Other Browsers](#how-to-configure-other-browsers)
* [Unable To Modify Your Systems 'Hosts' File](#unable-to-modify-your-systems-hosts-file)

## Introduction

As the web moves towards 100% adaption of SSL, it makes sense that our development environment should match.

Enabling and configuring SSL in WampServer can be a challenge. Knowledge of Apache and OpenSSL is required. The desire to work with multiple domains, each setup with its own unique self-signed SSL certificate, its own unique document root (located in any directory on any drive you want) and its own unique set of log files requires a reliable and repeatable approach.
 
In only a couple of seconds, this batch script automatically creates all the necessary domain specific directories, certificates, log files and configuration files, which are then linked to each and every version of Apache you have installed on your system. In addition to this it also adds your SSL certificates to the Windows Trusted Root Certificate Store removing the need to constantly accept untrusted self-signed certificates in the browser. Finally, it also tries to update your systems 'host' file for URL friendly domain name addresses. All of this is achieved through the use of a simple, easy to understand `config.ini` file.
 
As a safety measure, running the script for the very first time will backup your systems 'host' file, and the primary configuration file of each and every version of Apache you have installed. Thus, if for any reason things don't go the way they should, a simple `restore` command can roll back WampServer to its prior state.

## Minimum Requirements

The following are required for the SSL Auto Config script to function correctly.

* Microsoft Windows 7 and up.
* WampServer v3.0.0 and up.
* Use of Apache 2.4 and up.
* Use of Apache as a service.
* Administrator rights.

Administrator rights are required to update and roll back your systems 'host' file. Without Administrator rights this script will not be able to write to your systems 'host' file, preventing you from using URL friendly domain name addresses. Whilst this does not stop the script from working, it definitely does prevent the use of this great feature. 

## Compatible Web Browsers

Whilst any browser should work, browsers that use the Windows Trusted Root Certificate Store can take advantage of the trusted self-signed certificates.

Such browsers are:

* Chrome
* Internet Explorer
* Edge
* Opera

For browsers that do not use the Windows Trusted Root Certificate Store (such as Firefox), see the section titled [Configurable Web Browsers](#configurable-web-browsers).

## Installation

No installation is required.

At 51kB the SSL Auto Config script is small enough to be saved anywhere in your file system.

## Configuration

Configuration is carried out by editing a simple, easy to understand config `.ini` file.

Below are the contents of the `sample-config.ini` file.

```
;--------------------------;
; WampServer Configuration ;
;--------------------------;

; Your WampServer installation path.
wampServerInstallPath=C:\wamp64

; The parent path where your SSL certificates, keys, vhost and log files will be stored.
wampServerExtensionsPath=C:\wamp64 - ssl auto config

;-------------------------;
; SSL Certificate Details ;
;-------------------------;

; These (common) ssl certificate details are used to build each developments domain name certificate.
;
; sslCity:             The full name of a city.
; sslState:            The full name of a state.
; sslCountry:          The two letter ISO code of a country.
; sslOrganisation:     The organisation name.
; sslOrganisationUnit: The unit name of a organisation.
; sslEmail:            Use the 'local' part of an email address followed by the @ (at) symbol only.
;                      IMPORTANT: Do not include the 'domain' part of the email address as the hostname will be auto-appended.
; sslDays:             The number of days you would like the certificates to remain valid for.

sslCity=Brisbane
sslState=Queensland
sslCountry=AU
sslOrganization=Business
sslOrganizationUnit=IT Department
sslEmail=webmaster@
sslDays=3650

;---------------------;
; Development Domains ;
;---------------------;

[Website 1]
hostname=www.dev.website-1.com.au
documentRoot=C:/wamp64 - domains/website-1/public_html
http2=true

[Website 2]
hostname=www.dev.website-2.com.au
documentRoot=C:/wamp64 - domains/website-2/public_html
http2=true
```

#### WampServer Configuration

* `wampServerInstallPath` : This value represents your WampServers (absolute) installation path.
  
  > The default WampServer installation directories are:
  > * `C:\wamp` - For 32-bit installations.
  > * `C:\wamp64` - For 64-bit installations.

* `wampServerExtensionsPath` : This value represents the (absolute) parent path that will hold all the certificates, keys, log and vhost files used by WampServer. This path will be created if it does not already exist. Additionally, this path does not need to be in the same directory or even on the same drive as WampServer. That said, it is not recommended to point this to a network drive.

#### SSL Certificate Details
  
* `sslCity` : This value represents the full name of a city.

* `sslState` : This value represents the full name of a state.

* `sslCountry` : This value represents the two letter ISO code of a country.

* `sslOrganisation` : This value represents an organisation name.

* `sslOrganisationUnit` : This value represents the unit name of an organisation.

* `sslEmail` : This value represents the email address of the organisation.

  > **Note:** Use the 'local' part of an email address followed by the @ (at) symbol only. Do not include the 'domain' part of the email address as the hostname will be auto-appended.

* `sslDays` : This value represents the number of days you would like the certificates to remain valid for. Enter a high value so your SSL certificate does not expire to regularly and become an inconvenience.

#### Development Domains

* `[Website 1]` : This section name represent the human readable host name which is used within your various configuration files. Whilst it is not used by WampServer itself, it will definitely make identification within the generated configuration files easier.

* `hostname` : This value represents the URL friendly address used to access your site in your web browser.

* `documentRoot` : This value represents the (absolute) path to the public facing directory (commonly called the document root) of your website. This path does not need to be in the same directory or even on the same drive as WampServer. That said, it is not recommended to point this to a network drive.

* `http2` : This boolean value (`true` or `false`) represents the respective enabling or disabling of HTTP/2 functionality.

  > **Note:** You may need to clear (or disable) your browser cache when toggling between HTTP/1.1 and HTTP/2.

> **IMPORTANT:** Do not add quotation marks around your values, even if they contain spaces.

Blank lines and commented lines starting with a semicolon ( ; ) character are ignored. You may format and comment your configuration file any way you like.

> **Tip:** You can copy and rename the `sample-config.ini` file to any directory on any drive you like. 

## How To Use

The SSL Auto Config script can perform two functions.

1. Configure each and every installed version of Apache to use SSL.
2. Return each and every installed version of Apache back to its original state.

### The SSL Config Function  

To run the script from a CMD prompt:

```
C:\>: "C:\path\to\ssl_config.bat" "C:\path\to\my\config.ini"
```

To run the script from a Bash or Powershell prompt:

```
$ start "C:\path\to\ssl_config.bat" "C:\path\to\config.ini"
```

> **Note:** Don't forget to enclose paths in quotes if they contain spaces.

Running the script performs the following:

1. Parses the config file to get required data.
2. Validates your currently installed versions of Apache configuration files prior to modifying them.
3. Backs up your systems 'host' file and each installed version of Apache's primary configuration file.
4. Creates the `wampServerExtensionsPath` folder structure.
5. Loops through the domains creating domain specific folders, Apache config files, SSL certificates, adds the SSL certificates to the Windows Store and updates your systems 'hosts' file.
6. Links the domain specific Apache configuration files to each installed version of Apache's primary configuration file whilst also enabling SSL.
7. Re-validates the Apache configuration files to ensure no errors were introduced.
8. Flush the DNS and restart the Apache service.

> If your systems 'hosts' file was unable to be updated then see the section titled [Unable To Modify Your Systems 'Hosts' File](#unable-to-modify-your-systems-hosts-file).

Once the script has run, any open web browsers will need to be refreshed for the changes to take effect.

If at any stage you install a new version of Apache just run the script again to allow its primary configuration file to be linked and SSL enabled as well.

Should you find that your SSL certificate(s) expire then just run the script again. Doing so will generate new certificates and update then in the Windows Trusted Root Certificate store. If your certificate(s) seem to expire to quickly, just increase the value of `sslDays` in your `config.ini` file.

> **IMPORTANT:** It is important to understand that the backup taken of each installed version of Apache's primary configuration file is a 'snap-shot' of their state at that particular point in time. Any changes you make to that version of Apache (such as enabling or disabling modules via the WampServer menu located in the notification area) will not be saved to the backed-up version. Therefore, if you run the `restore` command, the 'backed-up' version will overwrite any modified settings.   

#### The Created Folder Structure

This script generates a pre-set folder structure base around the value of `wampServerExtensionsPath` in your `config.ini` file. 

If you were to use the `sample-config.ini` file as your configuration file then the following command

```
C:\>: "C:\path\to\ssl_config.bat" "C:\path\to\sample-config.ini"
```

would generate the below folder structure.

```
C:\wamp64 - ssl auto config
    + certs
    |  + www.dev.website-1.com.au
    |  |  + openssl.cnf
    |  |  + private.key
    |  |  + server.crt
    |  + www.dev.website-2.com.au
    |  |  + openssl.cnf
    |  |  + private.key
    |  |  + server.crt
    + logs
    |  + www.dev.website-1.com.au
    |  |  + access.log
    |  |  + error.log
    |  |  + ssl_request.log
    |  + www.dev.website-2.com.au
    |  |  + access.log
    |  |  + error.log
    |  |  + ssl_request.log
    |  + ssl_config.log
    + vhosts
       + http
       |  + www.dev.website-1.com.au.conf
       |  + www.dev.website-2.com.au.conf
       + https
          + conf
          |  + httpd-ssl.conf
          + www.dev.website-1.com.au.conf
          + www.dev.website-2.com.au.conf
```

This folder structure will remain the same, even after multiple runs **unless** you change the value of `wampServerExtensionsPath` in your `config.ini` file.

Adding a development domain to your `config.ini` file will add it to this folder structure.

Removing a development domain from your `config.ini` file will not remove it from this folder structure. You must remove the folder manually if you no longer want it.

The folder(s) you keep your website(s) code in is not touched at all by this script.

> **Note:** As a record of configuration and to assist in any fault-finding, the log file `ssl_config.log` found under the `logs` folder records in detail the scripts actions taken in configuring WampServers SSL. Please be aware this log file is appended on each run of the script, so over many runs it may grow to a considerable size.

### The Restore Function

To run the script from a CMD prompt:

```
C:\>: "C:\path\to\ssl_config.bat" "C:\path\to\my\config.ini" restore
```

To run the script from a Bash or Powershell prompt:

```
$ start "C:\path\to\ssl_config.bat" "C:\path\to\config.ini" restore
```

> **Note:** Don't forget to enclose paths in quotes if they contain spaces.

Running the script performs the following:
                    
1. Parses the config file to get required data.
2. Restores each and every installed version of Apache's primary configuration file (if a backup is found).
3. Removes each and every config domain name from the Windows Trusted Root Certificate Store.
4. Tries to restore the systems 'hosts' file (if a backup is found).

> If your systems 'hosts' file was unable to be restored then see the section titled [Unable To Modify Your Systems 'Hosts' File](#unable-to-modify-your-systems-hosts-file).

If Apache fails to restart following the `restore` command then you will need to perform a manual update as indicated below.

1. In each and every version of Apache you have installed:
    1. Delete the file `C:\wamp64\bin\apache\apacheX.X.XX\conf\httpd.conf`.
    2. Rename the file `C:\wamp64\bin\apache\apacheX.X.XX\conf\httpd-backup.conf` to `httpd.conf`.
2. In the directory containing your system 'hosts' file:
    1. Delete the file `%systemroot%\System32\drivers\etc\hosts`.
    2. Rename the file `%systemroot%\System32\drivers\etc\hosts-backup` to `host`.

> **Note:** You will need Administrator rights to perform the above 'hosts' file action.
 
## Configurable Web Browsers

Not all browsers use the Windows Trusted Root Certificate Store. For those that don't, some configuration may be required.

#### How To Configure Firefox

By default, Firefox prefers to use its own internal certificate store. To enable its use of the Windows Trusted Root Certificate Store you must first enable this feature.
  
To enable this feature, follow the below steps:
1. In the address bar type `about:config` and press the return key.
2. If prompted, click the 'Accept the Risk and Continue' and 'Show All' buttons.
3. In the 'Search preference name' field type `security.enterprise_roots.enabled` into the search field.
4. If the flag is missing, select `boolean` as a value type and then click the add ( + ) button.
5. If the flag exists and its value is `true` then Firefox is configured correctly.

#### How To Configure Other Browsers

If you know of any other browser(s) that would benefit by being added to this list then please do let me know.

## Unable To Modify Your Systems 'Hosts' File

If you are unable to update or restore your systems 'hosts' file then:

1. You are not logged in as an Administrator. To change this either login as an Administrator or right click the script and select 'Run as administrator'.
2. Your anti-virus software is stopping the modification of your systems files, including your systems 'hosts' file. This is usually a standard function of anti-virus software and the most probable cause of this issue. To change this turn off / disable your anti-virus software, run the script and then turn on / enable your anti-virus software. Most anti-virus software has an easily accessible option to disable protection for a short period of time. EG: 1-minute, 3-minutes, etc. You should only need to disable it for 1-minute for the script to execute correctly.   