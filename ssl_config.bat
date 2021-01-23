@echo off
cls
setlocal EnableExtensions EnableDelayedExpansion

rem -----------------------
rem     INITIALISATION
rem -----------------------
rem  Set default variables
rem -----------------------
set $scriptVersion=1.2.0
set $scriptLogFileName=ssl_config.log

rem WampServer sub-paths.
set $subPathToApacheFolders=bin\apache

rem WampServer Apache sub-paths.
set $subPathToApacheHttpdExe=bin\httpd.exe
set $subPathToApacheOpenSslExe=bin\openssl.exe

rem Operating system paths.
set $pathToOSHostsFile=%systemroot%\System32\drivers\etc\hosts
set $pathToUsersTempFile=%temp%\ssl_config_temp_file.txt


rem -------------------
rem  Get computer name
rem -------------------
set $computerName=%ComputerName%


rem ----------------
rem  Get IP address
rem ----------------
for /f "tokens=2 delims=[]" %%a in ('ping %ComputerName% -4 -n 1') do set $ipAddress=%%a


rem ---------------------
rem  Get IP network part
rem ---------------------
for /f "tokens=1,2 delims=." %%a in ("%$ipAddress%") do set $ipNetworkPart=%%a.%%b


rem ----------------------
rem  Set echo offset hack
rem ----------------------

rem Hack to define a backspace so the 'set /p' command can be offset from the windows edge.
for /f %%a in ('"prompt $H &echo on &for %%b in (1) do rem"') do set backspace=%%a


rem ------------------
rem  Set window title
rem ------------------
title WampServer SSL Auto Config (v%$scriptVersion%)


rem -------------
rem  Show header
rem -------------
echo:
echo   WampServer SSL Auto Config (v%$scriptVersion%)
echo   -----------------------------------
echo:

rem -------------------
rem         CLI
rem -------------------
rem  Get CLI arg count
rem -------------------

rem Count the number of arguments.
set $argumentCount=0
for %%x in (%*) do Set /A $argumentCount+=1

rem Check if no arguments were given.
if !$argumentCount! equ 0 (
    call :failure "CLI Argument Error" "ssl_conf.bat" "No ini file was given." "Please pass in the path to your config.ini file."
)

rem Check if more than two arguments were given.
if !$argumentCount! gtr 2 (
    call :failure "CLI Argument Error" "ssl_conf.bat" "More than two arguments were given." "Please only pass in a maximum of 2 arguments, your ini file and the optional restore command."
)


rem ----------------
rem  Get CLI arg(s)
rem ----------------

rem Set the variables.
set $configPath=
set $restoreFlag=false

rem Check if two arguments were given.
if !$argumentCount! equ 2 (
    rem Check for first combination.
    if /i "%1" equ "restore" (
        set $restoreFlag=true
        set $configPath=%~f2
    ) else (
        rem Check for second combination.
        if /i "%2" equ "restore" (
            set $restoreFlag=true
            set $configPath=%~f1
        ) else (
            rem CLI command not recognised.
            call :failure "CLI Argument Error" "ssl_conf.bat" "Argument not recognised."
        )
    )
)

rem Check if one argument was given.
if !$argumentCount! equ 1 (
    set $configPath=%~f1
)


rem -------------------------------------------
rem  Check CLI config arg has '.ini' extension
rem -------------------------------------------

rem Check if the file is an .ini file.
call :isIniFile "!$configPath!"

rem Check the result.
if /i "!$result!" equ "false" (
    rem Config file name does not contain a valid extension (.ini)
    call :failure "CLI Argument Error" "ssl_conf.bat" "Your config file must have a .ini extension."
)


rem --------------------------
rem        CONFIG FILE
rem --------------------------
rem  Check config file exists
rem --------------------------

rem Check that the configuration file path exists.
if not exist "%$configPath%" (
    call :failure "CLI Argument Error" "ssl_conf.bat" "Path to ^"!$configPath!^" does not exist."
)


rem -------------------
rem  Parse config file
rem -------------------

rem Set the default variables.
set $inSection=false
set $totalConfigDomains=0

rem Parse the configuration file line by line, skipping (by default) all blank lines and lines starting with a semicolon.
for /F "usebackq delims=" %%a in ("!$configPath!") do (
    rem Set the variables.
    set $line=%%a

    rem Check for a section.
    if "!$line:~0,1!" == "[" (
        if "!$line:~-1!" == "]" (
            set $inSection=true
            set /A $totalConfigDomains=$totalConfigDomains+1
            set $key=name
            set $value=!$line:~1,-1!
        ) else (
            call :failure "Config File Error" "!$configPath!" "!$line!" "A [Section] name must not contain any trailing characters."
        )
     ) else (
        rem Split the line around the '=' sign (assuming one exists).
        for /F "tokens=1,2 delims==" %%b in ("!$line!") do (
            rem Check for a valid key / value pair.
            if not "%%b%%c" == "%%c%%b" (
                set $key=%%b
                set $value=%%c
            ) else (
                call :failure "Config File Error" "!$configPath!" "^"!$line!^" key or value missing."
            )
        )
    )

    rem Build the config array.
    if "!$inSection!" == "false" (
        set $config[!$key!]=!$value!
    ) else (
        set $config[!$totalConfigDomains!][!$key!]=!$value!
    )
)

call :logToScreen "Parsed configuration file."


rem ---------------------
rem  Initialise log path
rem ---------------------

rem Create the log path if it does not exist.
if not exist "%$config[wampServerExtensionsPath]%\logs" (
    md "%$config[wampServerExtensionsPath]%\logs"
    call :logToScreen "Created common 'logs' directory."
) else (
    call :logToScreen "Common 'logs' directory already exists."
)

rem Set the log file path.
set $logFilePath=!$config[wampServerExtensionsPath]!\logs\!$scriptLogFileName!

rem Write header to log file.
(
echo:
echo ===========================================================
echo:
echo !date! : WampServer SSL Auto Config Script ^(v%$scriptVersion%^)
echo:
) >> "!$logFilePath!"

call :logToBoth "Script initialised."
call :logToBoth "---------------------------------------------"


rem --------------------------------------
rem               WAMPSERVER
rem --------------------------------------
rem  Check WampServer install path exists
rem --------------------------------------

rem Check that the WampServer installation path exists.
if not exist "%$config[wampServerInstallPath]%" (
    call :failure "Config File Error" "!$configPath!" "The WampServer installation path ^"!$config[wampServerInstallPath]!^" does not exist."
) else (
    call :logToFile "Found WampServer installation path at '!$config[wampServerInstallPath]!'"
    call :logToScreen "Found WampServer installation path."
)

rem Remove any trailing slash.
call :removeTrailingSlash "%$config[wampServerInstallPath]%"
set $config[wampServerInstallPath]=!$result!


rem --------------------------
rem           APACHE
rem --------------------------
rem  Check Apache path exists
rem --------------------------

rem Check that the WampServer Apache folder path exists.
if not exist "%$config[wampServerInstallPath]%\%$subPathToApacheFolders%" (
    call :failure "SSL Script" "ssl_conf.bat" "Path to WampServer Apache folder ^"!$config[wampServerInstallPath]!\!$subPathToApacheFolders!^" does not exist." "Please file an issue on github."
) else (
    call :logToFile "Found WampServer Apache path at '%$config[wampServerInstallPath]%\%$subPathToApacheFolders%'"
    call :logToScreen "Found WampServer Apache path."
)


rem -------------------------------
rem  Get installed Apache versions
rem -------------------------------

rem Initialise the counter.
set $totalApacheVersionsInstalled=0

call :logToBoth "Found WampServer Apache installation(s):"

rem Iterate through the WampServer Apache folder paths adding each version folder to the array.
for /f "delims=" %%a in ('dir %$config[wampServerInstallPath]%\%$subPathToApacheFolders% /AD /B') do (

    rem ------------------
    rem  Get version path
    rem ------------------

    set /A $totalApacheVersionsInstalled=$totalApacheVersionsInstalled+1
    rem Set the Apache version folder path to the array.
    set $installedApacheVersionsArray[!$totalApacheVersionsInstalled!]=%%a
    set $installedApacheVersionPathsArray[!$totalApacheVersionsInstalled!]=%$config[wampServerInstallPath]%\%$subPathToApacheFolders%\%%a
    call :logToBoth "  '%%a'"
)


rem ------------------------------
rem               OS
rem ------------------------------
rem  Check OS 'hosts' file exists
rem ------------------------------

rem Check if the OS 'hosts' file exists.
if not exist "%$pathToOSHostsFile%" (
    call :failure "SSL Script Error" "ssl_conf.bat" "Path to OS 'hosts' file ^"!$pathToOSHostsFile!^" does not exist" "Please file an issue on github."
)

call :logToFile "Found OS 'hosts' file at '%$pathToOSHostsFile%'"
call :logToScreen "Found OS 'hosts' file."


rem -------------------------------
rem  Get OS service name of Apache
rem -------------------------------

rem Get the Apache (OS) service name from the WampServer 'wampmanager.conf' file.
call :getIniValue "%$config[wampServerInstallPath]%\wampmanager.conf" "service" "ServiceApache"

rem Check if a result was return.
if [!$result!] == [] (
    call :failure "SSL Script Error" "ssl_conf.bat" "Unable to find 'ServiceApache' key in ^"!$config[wampServerInstallPath]!\wampmanager.conf^"" "Please file an issue on github."
)

rem Strip the surrounding quotes from the value.
set $apacheServiceName=!$result:~1,-1!
call :logToFile "Found OS Apache service name '!$apacheServiceName!'"
call :logToScreen "Found OS Apache service name."


rem --------------------
rem  Restore (CLI Flag)
rem --------------------

rem Check if the restore flag is set to true.
if /i "!$restoreFlag!" equ "true" (

    rem ------------------------------
    rem  Loop through Apache versions
    rem ------------------------------

    call :logToBoth "Restoring Apache config file(s):"

    rem Iterate though the installed Apache version folders.
    for /l %%a in (1,1,%$totalApacheVersionsInstalled%) do (

        rem ----------------------------
        rem  Restore Apache config file
        rem ----------------------------

        rem Check if the 'httpd-backup.conf' file exists.
        if exist "!$installedApacheVersionPathsArray[%%a]!\conf\httpd-backup.conf" (

            rem Restore the 'httpd.conf' file.
            type "!$installedApacheVersionPathsArray[%%a]!\conf\httpd-backup.conf" > "!$installedApacheVersionPathsArray[%%a]!\conf\httpd.conf"

            rem Delete the 'httpd-backup.conf' file.
            call :deleteFileIfExists "!$installedApacheVersionPathsArray[%%a]!\conf\httpd-backup.conf"

            call :logToBoth "  '!$installedApacheVersionsArray[%%a]!' restored."
        ) else (
            call :logToBoth "  '!$installedApacheVersionsArray[%%a]!' backup not found."
        )

        rem --------------------------------
        rem  Validate Apache config file(s)
        rem --------------------------------

        rem Get the validity of the Apache config file(s).
        call :validateApacheConfigFile "!$installedApacheVersionPathsArray[%%a]!"

        rem Check the result.
        if "!$result!" neq "Syntax OK" (
            call :failure "WampServer Apache Validation Error" "See below" "!$result!" "Please correct the error in the stated configuration file and restart WampServer."
        )

        call :logToBoth "  '!$installedApacheVersionsArray[%%a]!' validated."
    )


    rem ----------------------
    rem  Loop through domains
    rem ----------------------

    call :logToBoth "Deleting certificates from store:"

    rem Iterate through all config listed domains.
    for /l %%a in (1,1,%$totalConfigDomains%) do (

        rem -----------------------------------
        rem  Delete cert(s) from Windows store
        rem -----------------------------------

        rem Delete certificate from 'trusted root certificate store'.
        rem View store by entering 'certmgr.msc' at the command line.
        certutil -delstore "root" "!$config[%%a][hostname]!" > nul
        call :logToBoth "  '!$config[%%a][hostname]!'"
    )


    rem -------------------------
    rem  Restore OS 'hosts' file
    rem -------------------------

    rem Set 'hosts' file updated flag.
    set $osHostsFileUpdated=false

    call :logToBoth "Attempting to restore OS 'hosts' file."

    rem Check if the OS 'hosts-backup' file exists.
    if exist "%$pathToOSHostsFile%-backup" (

        rem Restore the OS 'hosts' file.
        rem Unable to redirect error output without breaking updating of file...
        type "!$pathToOSHostsFile!-backup" > "!$pathToOSHostsFile!" 2>nul

        rem Check if the OS 'hosts' file matches the 'hosts-backup'file.
        fc "!$pathToOSHostsFile!-backup" "!$pathToOSHostsFile!" >nul && (
            set $osHostsFileUpdated=true
            call :deleteFileIfExists "!$pathToOSHostsFile!-backup" 2>nul
            call :logToBoth "Restored OS 'hosts' file."
        ) || (
            call :logToBoth "Unable to restore OS 'hosts' file."
        )
    ) else (
        set $osHostsFileUpdated=true
        call :logToBoth "OS 'hosts' backup file not found."
    )

    rem ----------------
    rem  Restart Apache
    rem ----------------

    rem Restart Apache.
    call :logToBoth "Re-starting Apache."
    call :restartApache
    call :logToBoth "Re-started Apache."


    rem ----------------------------------
    rem  Exit showing appropriate message
    rem ----------------------------------
    if /i "!$osHostsFileUpdated!" equ "false" (
        call :warning
    ) else (
        call :success
    )
)


rem ------------------------------
rem             APACHE
rem ------------------------------
rem  Loop through Apache versions
rem ------------------------------

call :logToBoth "Validating Apache config file(s):"

rem Iterate though the installed Apache version folders.
for /l %%a in (1,1,%$totalApacheVersionsInstalled%) do (

    rem ------------------------------
    rem  Validate Apache config files
    rem ------------------------------

    rem Get the validity of the Apache config file(s).
    call :validateApacheConfigFile "!$installedApacheVersionPathsArray[%%a]!"

    rem Check the result.
    if "!$result!" neq "Syntax OK" (
        call :failure "WampServer Apache Validation Error" "See below" "!$result!" "Please correct the error in the stated configuration file and restart WampServer."
    )

    call :logToBoth "  '!$installedApacheVersionsArray[%%a]!'"
)


rem ------------------------------------
rem  Get latest OpenSSL executable path
rem ------------------------------------

rem Use the latest Apache version folder.
set $pathToLatestOpenSslExe=!$installedApacheVersionPathsArray[%$totalApacheVersionsInstalled%]!\!$subPathToApacheOpenSslExe!
call :logToBoth "Using 'openssl.exe' from '!$installedApacheVersionsArray[%$totalApacheVersionsInstalled%]!'"


rem ---------------------------------
rem  Start Apache service if stopped
rem ---------------------------------

rem Get the status of the Apache service.
call :getServiceStatus "!$apacheServiceName!"

rem Start Apache service if it is not already running.
if /i "!$result!" neq "Running" (
    call :logToBoth "Starting Apache service."

    rem Start Apache.
    net start !$apacheServiceName! > nul

    rem Get the status of the Apache service.
    call :getServiceStatus "!$apacheServiceName!"

    rem Check if the Apache service is running.
    if /i "!$result!" neq "Running" (
        call :failure "WampServer Apache Service Startup Error" "See below" "!$result!" "Please correct the error and restart WampServer."
    ) else (
        call :logToBoth "Apache service started."
    )
) else (
    call :logToBoth "Apache service already started."
)


rem ------------------------------------
rem                BACKUP
rem ------------------------------------
rem  Backup OS 'hosts' file (once only)
rem ------------------------------------
if not exist "%$pathToOSHostsFile%-backup" (
    type "!$pathToOSHostsFile!" > "!$pathToOSHostsFile!-backup"
    call :logToBoth "OS 'hosts' file backed up."
) else (
    call :logToBoth "OS 'hosts' file already backed up."
)


rem ------------------------------
rem  Loop through Apache versions
rem ------------------------------

call :logToBoth "Backing up Apache 'httpd.conf' file(s):"

rem Iterate though the installed Apache version folders.
for /l %%a in (1,1,%$totalApacheVersionsInstalled%) do (

    rem ---------------------------------------------
    rem  Backup Apache 'httpd.conf' file (once only)
    rem ---------------------------------------------
    if not exist "!$installedApacheVersionPathsArray[%%a]!\conf\httpd-backup.conf" (
        type "!$installedApacheVersionPathsArray[%%a]!\conf\httpd.conf" > "!$installedApacheVersionPathsArray[%%a]!\conf\httpd-backup.conf"
        call :logToBoth "  '!$installedApacheVersionsArray[%%a]!'"
    ) else (
        call :logToBoth "  '!$installedApacheVersionsArray[%%a]!' already backed up."
    )
)


rem --------------------------------------------------------
rem  Create common 'certs', 'logs' And 'vhosts' directories
rem --------------------------------------------------------
if not exist "%$config[wampServerExtensionsPath]%\certs" (
    md "%$config[wampServerExtensionsPath]%\certs"
    call :logToFile "Created common 'certs' directory at '!$config[wampServerExtensionsPath]!\certs'"
    call :logToScreen "Created common 'certs' directory."
) else (
    call :logToFile "Common 'certs' directory already exists at '!$config[wampServerExtensionsPath]!\certs'"
    call :logToScreen "Common 'certs' directory already exists."
)

if not exist "%$config[wampServerExtensionsPath]%\vhosts\http" (
    md "%$config[wampServerExtensionsPath]%\vhosts\http"
    call :logToFile "Created common 'vhosts\http' directory at '!$config[wampServerExtensionsPath]!\vhosts\http'"
    call :logToScreen "Created common 'vhosts\http' directory."
) else (
     call :logToFile "Common 'vhosts\http' directory already exists at '!$config[wampServerExtensionsPath]!\vhosts\http'"
     call :logToScreen "Common 'vhosts\http' directory already exists."
)

if not exist "%$config[wampServerExtensionsPath]%\vhosts\https\conf" (
    md "%$config[wampServerExtensionsPath]%\vhosts\https\conf"
    call :logToFile "Created common 'vhosts\https' directory at '!$config[wampServerExtensionsPath]!\vhosts\https'"
    call :logToScreen "Created common 'vhosts\https' directory."
) else (
     call :logToFile "Common 'vhosts\https' directory already exists at '!$config[wampServerExtensionsPath]!\vhosts\https'"
     call :logToScreen "Common 'vhosts\https' directory already exists."
)


rem ------------------------------------------------
rem  (Re)Create common vhosts 'httpd-ssl.conf' file
rem ------------------------------------------------
if not exist "%$config[wampServerExtensionsPath]%\vhosts\https\conf\httpd-ssl.conf" (
    (call :httpdSslCommonConfigFile) >> "%$config[wampServerExtensionsPath]%\vhosts\https\conf\httpd-ssl.conf"
    call :logToBoth "Created common 'httpd-ssl.conf' file."
) else (
    call :deleteFileIfExists "%$config[wampServerExtensionsPath]%\vhosts\https\conf\httpd-ssl.conf"
    (call :httpdSslCommonConfigFile) >> "%$config[wampServerExtensionsPath]%\vhosts\https\conf\httpd-ssl.conf"
    call :logToBoth "Re-created common 'httpd-ssl.conf' file."
)


rem ----------------------
rem  Loop through domains
rem ----------------------

rem Iterate through all config listed domains.
for /l %%a in (1,1,%$totalConfigDomains%) do (

    rem Set the variables for easier replacement in the config files.
    set $config[name]=!$config[%%a][name]!
    set $config[hostname]=!$config[%%a][hostname]!
    set $config[documentRoot]=!$config[%%a][documentRoot]!
    set $config[http2]=!$config[%%a][http2]!

    rem Show domain name.
    call :logToBoth "---------------------------------------------"
    call :logToBoth "!$config[name]! ^(!$config[hostname]!^)"


    rem ---------------------------
    rem  Create domain directories
    rem ---------------------------

    rem Create the 'certs' directory.
    if not exist "!$config[wampServerExtensionsPath]!\certs\!$config[hostname]!" (
        md "!$config[wampServerExtensionsPath]!\certs\!$config[hostname]!"
        call :logToBoth "  'certs' directory created."
    ) else (
        call :logToBoth "  'certs' directory already exists."
    )

    rem Create the 'logs' directory.
    if not exist "!$config[wampServerExtensionsPath]!\logs\!$config[hostname]!" (
        md "!$config[wampServerExtensionsPath]!\logs\!$config[hostname]!"
        call :logToBoth "  'logs' directory created."
    ) else (
        call :logToBoth "  'logs' directory already exists."
    )


    rem -------------------------------
    rem  (Re)Create 'openssl.cnf' file
    rem -------------------------------
    if not exist "!$config[wampServerExtensionsPath]!\certs\!$config[hostname]!\openssl.cnf" (
        (call :openSslCnfFile) >> "!$config[wampServerExtensionsPath]!\certs\!$config[hostname]!\openssl.cnf"
        call :logToBoth "  Created 'openssl.conf' file."
    ) else (
        call :deleteFileIfExists "!$config[wampServerExtensionsPath]!\certs\!$config[hostname]!\openssl.cnf"
        (call :openSslCnfFile) >> "!$config[wampServerExtensionsPath]!\certs\!$config[hostname]!\openssl.cnf"
        call :logToBoth "  Re-created 'openssl.cnf' file."
    )


    rem ----------------------------
    rem  (Re)Create HTTP vhost file
    rem ----------------------------
    if not exist "!$config[wampServerExtensionsPath]!\vhosts\http\!$config[hostname]!.conf" (
        (call :apache24HttpVhostConfigFile) >> "%$config[wampServerExtensionsPath]%\vhosts\http\!$config[hostname]!.conf"
        call :logToBoth "  Created Virtual Host http file."
    ) else (
        call :deleteFileIfExists "!$config[wampServerExtensionsPath]!\vhosts\http\!$config[hostname]!.conf"
        (call :apache24HttpVhostConfigFile) >> "%$config[wampServerExtensionsPath]%\vhosts\http\!$config[hostname]!.conf"
        call :logToBoth "  Re-created Virtual Host http file."
    )


    rem -----------------------------
    rem  (Re)Create HTTPS vhost file
    rem -----------------------------
    if not exist "!$config[wampServerExtensionsPath]!\vhosts\https\!$config[hostname]!.conf" (
        if /i "!$config[http2]!" equ "false" (
            (call :apache24Https11VhostConfigFile) >> "!$config[wampServerExtensionsPath]!\vhosts\https\!$config[hostname]!.conf"
        ) else (
            (call :apache24Https2VhostConfigFile) >> "!$config[wampServerExtensionsPath]!\vhosts\https\!$config[hostname]!.conf"
        )
        call :logToBoth "  Created Virtual Host https file."
    ) else (
        call :deleteFileIfExists "!$config[wampServerExtensionsPath]!\vhosts\https\!$config[hostname]!.conf"
        if /i "!$config[http2]!" equ "false" (
            (call :apache24Https11VhostConfigFile) >> "!$config[wampServerExtensionsPath]!\vhosts\https\!$config[hostname]!.conf"
        ) else (
            (call :apache24Https2VhostConfigFile) >> "!$config[wampServerExtensionsPath]!\vhosts\https\!$config[hostname]!.conf"
        )
        call :logToBoth "  Re-created Virtual Host https file."
    )


    rem ------------------------------------
    rem  Delete old cert from Windows store
    rem ------------------------------------

    rem Delete certificate from 'trusted root certificate store'.
    rem View store by entering 'certmgr.msc' at the command line.
    certutil -delstore "root" "!$config[hostname]!" > nul
    call :logToBoth "  Deleted old certificate from store."


    rem -----------------------
    rem  Create SSL key & cert
    rem -----------------------

    rem Create private (and public) RSA key.
    cmd /C !$pathToLatestOpenSslExe! "genrsa" "-out" "!$config[wampServerExtensionsPath]!\certs\!$config[hostname]!\private.pem" 2> nul
    call :logToBoth "    Generated certificate keys."

    rem Remove private key passphrase.
    cmd /C !$pathToLatestOpenSslExe! "rsa" "-in" "!$config[wampServerExtensionsPath]!\certs\!$config[hostname]!\private.pem" "-out" "!$config[wampServerExtensionsPath]!\certs\!$config[hostname]!\private.key" 2> nul
    call :logToBoth "    Removed certificate passphrase."

    rem Generate self signed certificate.
    cmd /C !$pathToLatestOpenSslExe! "req" "-x509" "-days" "!$config[sslDays]!" "-key" "!$config[wampServerExtensionsPath]!\certs\!$config[hostname]!\private.key" "-out" "!$config[wampServerExtensionsPath]!\certs\!$config[hostname]!\server.crt" "-config" "!$config[wampServerExtensionsPath]!\certs\!$config[hostname]!\openssl.cnf"
    call :logToBoth "    Generated Certificate."

    rem Delete the redundant RSA key file.
    call :deleteFileIfExists "!$config[wampServerExtensionsPath]!\certs\!$config[hostname]!\private.pem"
    call :logToBoth "    Deleted 'private.pem' file."


    rem -------------------------------
    rem  Add new cert to Windows store
    rem -------------------------------

    rem Add certificate to 'trusted root certificate store'.
    rem View store by entering 'certmgr.msc' at the command line.
    certutil -f -addstore "root" "!$config[wampServerExtensionsPath]!\certs\!$config[hostname]!\server.crt" > nul
    call :logToBoth "  Added new certificate to store."


    rem -------------------------------
    rem  Add domain to OS 'hosts' file
    rem -------------------------------

    rem Set 'hosts' file updated flag.
    set $osHostsFileUpdated=false

    rem Check if the hostname has already been added to the 'hosts' file.
    call :findInFile "]# Hostname:   !$config[hostname]!" "!$pathToOSHostsFile!"

    rem Check the result.
    if /i "!$result!" equ "false" (
        rem Try adding the hostname.
        call :logToBoth "  Attempting to add hostname to OS 'hosts' file."
        rem Unable to redirect error output without breaking updating of file...
        (call :includeOsHostsFile) >> "!$pathToOSHostsFile!" 2>nul

        rem Check if the hostname has been added.
        call :findInFile "]# Hostname:   !$config[hostname]!" "!$pathToOSHostsFile!"

        rem Check the result.
        if /i "!$result!" equ "true" (
            set $osHostsFileUpdated=true
            call :logToBoth "  Hostname added to OS 'hosts' file."
        ) else (
            call :logToBoth "  Unable to added hostname to OS 'hosts' file."
        )
    ) else (
        rem Hostname already added to the 'hosts' file.
        set $osHostsFileUpdated=true
        call :logToBoth "  Hostname already added to OS 'hosts' file."
    )
)

call :logToBoth "---------------------------------------------"


rem ------------------------------
rem  Loop through Apache versions
rem ------------------------------

call :logToBoth "Updating Apache primary config file(s):"

rem Iterate though the installed Apache version folders.
for /l %%a in (1,1,%$totalApacheVersionsInstalled%) do (

    rem Show the header info.
    call :logToBoth "  '!$installedApacheVersionsArray[%%a]!\conf\httpd.conf'"


    rem --------------------------------------------
    rem  Uncomment 'socache_shmcb_module' module
    rem
    rem  Low level shared memory based object cache
    rem  for caching information such as SSL
    rem  sessions and authentication credentials.
    rem --------------------------------------------

    rem Check if the module is commented out / disabled.
    call :findInFile "]#LoadModule socache_shmcb_module modules/mod_socache_shmcb.so" "!$installedApacheVersionPathsArray[%%a]!\conf\httpd.conf"
    if /i "!$result!" equ "true" (
        rem Uncomment / enable the module.
        call :findAndReplaceInFile "]#LoadModule socache_shmcb_module modules/mod_socache_shmcb.so" "]LoadModule socache_shmcb_module modules/mod_socache_shmcb.so" "!$installedApacheVersionPathsArray[%%a]!\conf\httpd.conf"
        call :logToBoth "    'socache_shmcb_module' uncommented."
    ) else (
        rem Module already uncommented / enabled.
        call :logToBoth "    'socache_shmcb_module' already uncommented."
    )


    rem -------------------------------
    rem  Uncomment 'ssl_module' module
    rem
    rem  This module used the socache
    rem  interface to provide a
    rem  session cache and stapling
    rem  cache.
    rem -------------------------------

    rem Check if the module is commented out / disabled.
    call :findInFile "]#LoadModule ssl_module modules/mod_ssl.so" "!$installedApacheVersionPathsArray[%%a]!\conf\httpd.conf"
    if /i "!$result!" equ "true" (
        rem Uncomment / enable the module.
        call :findAndReplaceInFile "]#LoadModule ssl_module modules/mod_ssl.so" "]LoadModule ssl_module modules/mod_ssl.so" "!$installedApacheVersionPathsArray[%%a]!\conf\httpd.conf"
        call :logToBoth "    'ssl_module' uncommented."
    ) else (
        rem Module already uncommented / enabled.
        call :logToBoth "    'ssl_module' already uncommented."
    )


    rem -----------------------------------------
    rem  Uncomment 'http2_module' module
    rem
    rem  This module enables HTTP/2 support.
    rem
    rem  HTTP/2 functionality set per development
    rem  domain.
    rem
    rem  OpenSSL version must be greater than or
    rem  equal to 1.0.2 for HTTP/2 compatibility.
    rem
    rem  OpenSSL cipher suite must be greater
    rem  than or equal to TLS 1.3 for HTTP/2
    rem  compatibility.
    rem -----------------------------------------

    rem Check if the module is commented out / disabled.
    call :findInFile "]#LoadModule http2_module modules/mod_http2.so" "!$installedApacheVersionPathsArray[%%a]!\conf\httpd.conf"
    if /i "!$result!" equ "true" (
        rem Uncomment / enable the module.
        call :findAndReplaceInFile "]#LoadModule http2_module modules/mod_http2.so" "]LoadModule http2_module modules/mod_http2.so" "!$installedApacheVersionPathsArray[%%a]!\conf\httpd.conf"
        call :logToBoth "    'http2_module' uncommented."
    ) else (
        rem Module already uncommented / enabled.
        call :logToBoth "    'http2_module' already uncommented."
    )


    rem ----------------------------------------
    rem  Add vhosts HTTPS 'httpd-ssl.conf' link
    rem ----------------------------------------

    rem Check if the link has been added.
    call :findInFile "]# SSL Config - Additional" "!$installedApacheVersionPathsArray[%%a]!\conf\httpd.conf"
    if /i "!$result!" equ "false" (
        rem Add the link.
        (call :includeSslInConfigFile) >> "!$installedApacheVersionPathsArray[%%a]!\conf\httpd.conf"
        call :logToBoth "    Added SSL Config link."
    ) else (
        rem Link already added.
        call :logToBoth "    SSL Config link already added."
    )


    rem -------------------------------
    rem  Add vhosts HTTP '*.conf' link
    rem -------------------------------

    rem Check if the link has been added.
    call :findInFile "]# HTTP Vhost(s) - Additional" "!$installedApacheVersionPathsArray[%%a]!\conf\httpd.conf"
    if /i "!$result!" equ "false" (
        rem Add the link.
        (call :includeHttpVhostInConfigFile) >> "!$installedApacheVersionPathsArray[%%a]!\conf\httpd.conf"
        call :logToBoth "    Added HTTP vhosts link."
    ) else (
        rem Link already added.
        call :logToBoth "    HTTP vhosts link already added."
    )


    rem --------------------------------
    rem  Add vhosts HTTPS '*.conf' link
    rem --------------------------------

    rem Check if the link has been added.
    call :findInFile "]# HTTPS Vhost(s) - Additional" "!$installedApacheVersionPathsArray[%%a]!\conf\httpd.conf"
    if /i "!$result!" equ "false" (
        rem Add the link.
        (call :includeHttpsVhostInConfigFile) >> "!$installedApacheVersionPathsArray[%%a]!\conf\httpd.conf"
        call :logToBoth "    Added HTTPS vhosts link."
    ) else (
        rem Link already added.
        call :logToBoth "    HTTPS vhosts link already added."
    )


    rem -----------------------
    rem  Validate config files
    rem -----------------------

    rem Get the validity of the Apache config files.
    call :validateApacheConfigFile "!$installedApacheVersionPathsArray[%%a]!"

    rem Check the result.
    if "!$result!" neq "Syntax OK" (
        call :failure "WampServer Apache Validation Error" "See below" "!$result!" "Please correct the error in the stated configuration file and restart WampServer."
    )

    call :logToBoth "    Validated config file(s)."
)

call :logToBoth "---------------------------------------------"


rem -----------
rem  Flush DNS
rem -----------
call :logToBoth "Flushing DNS."
ipconfig /flushdns > nul
call :logToBoth "Flushed DNS."


rem ---------------------
rem   Restart WampServer
rem ---------------------

rem Restart Apache.
call :logToBoth "Re-starting Apache."
call :restartApache
call :logToBoth "Re-started Apache."


rem ----------------------------------
rem  Exit showing appropriate message
rem ----------------------------------
if /i "!$osHostsFileUpdated!" equ "false" (
    call :warning
) else (
    call :success
)


rem ====================================================================================================================
rem                                                      Functions
rem ====================================================================================================================

rem ---------------
rem  Log to screen
rem ---------------
:logToScreen $message

rem Set the variable.
set $message=%~1

rem Display the message.
echo   %time% : !$message!

exit /B


rem -------------
rem  Log to file
rem -------------
:logToFile $message

rem Set the variable.
set $message=%~1

rem Log the message.
echo %time% : !$message! >> "!$logFilePath!"

exit /B


rem ----------------------
rem  Log to screen & file
rem ----------------------
:logToBoth $message

call :logToScreen %1
call :logToFile %1

exit /B


rem ----------------
rem  Restart Apache
rem ----------------
:restartApache

rem Stop Apache.
net stop %$apacheServiceName% > nul

rem Start Apache.
net start %$apacheServiceName% > nul

exit /B


rem -----------------------------
rem  Validate Apache config file
rem -----------------------------
:validateApacheConfigFile $file

rem Set the variable scope.
setlocal

rem Set the variables.
set $file=%~1
set $output=

rem As "all" Apache output goes to STDERR, we have redirect it back to STDOUT so it can be processed.
for /f "tokens=* delims=" %%a in ('%$file%\%$subPathToApacheHttpdExe% -t 2^>^&1') do (
    set $output=%%a
    goto :exitValidateApacheConfigFilesFunction
)

:exitValidateApacheConfigFilesFunction

endlocal & set $result=%$output%

exit /B


rem --------------------
rem  Get service status
rem --------------------
:getServiceStatus $name

rem Set the variable scope.
setlocal

rem Set the variables.
set $name=%~1
set $status=Unknown

rem Set the service status.
for /F "tokens=3 delims=: " %%a in ('sc query "%$name%" ^| find "STATE"') do (

    if /i "%%a" equ "RUNNING" (
        set $status=Running
    )

    if /i "%%a" equ "STOPPED" (
        set $status=Stopped
    )
)

endlocal & set $result=%$status%

exit /B


rem -----------------------
rem  Remove trailing slash
rem -----------------------
:removeTrailingSlash $string

rem Set the variable scope.
setlocal

rem Set the variable.
set $string=%~1

rem Remove the backslash if one exists.
if "!$string:~-1%!" equ "\" (
    set "$string=!$string:~0,-1!"
)

rem Remove the forward slash if one exists.
if "!$string:~-1%!" equ "/" (
    set "$string=!$string:~0,-1!"
)

endlocal & set $result=%$string%

exit /B


rem --------------------------
rem  Delete file if it exists
rem --------------------------
:deleteFileIfExists $file

rem Set the variable.
set $file=%~1

if exist "%$file%" (
    del /Q "%$file%"
)

exit /B


rem -------------------------------------
rem  Find and replace a string in a file
rem
rem  To save on double parsing a file,
rem  just parse, replace (if found) and
rem  re-write even is no match is found.
rem -------------------------------------
:findAndReplaceInFile $find $replace $file

rem Set the variable(s).
set $find=%~1
set $replace=%~2
set $file=%~3

rem Delete the temporary file if one exists.
if exist "!$pathToUsersTempFile!" (
    del /Q "!$pathToUsersTempFile!"
)

rem Parse the $file one line at a time.
for /f "tokens=1,* delims=0123456789" %%a in ('find /n /v "" ^< "!$file!"') do (

    rem Set the variable(s).
    set "$line=%%b"

    rem Check if the line matches.
    if !$line!==!$find! (
        rem Replace the line.
        set "$line=!$replace!"
    )

    rem Expand the line removing any surrounding quotes then write the line to the temporary file.
    echo(!$line:~1!) >> "!$pathToUsersTempFile!"
)

rem Overwrite the $file with the temporary file.
copy "!$pathToUsersTempFile!" "!$file!" > nul

exit /B


rem -----------------------------
rem  Check if it is an .ini file
rem -----------------------------
:isIniFile $file

rem Set the variable scope.
setlocal

rem Set the variables.
set $fileExtension=%~x1
set $boolean=false

rem Check if the file extension is .ini
if /i "!$fileExtension!" equ ".ini" (
    set $boolean=true
)

endlocal & set $result=%$boolean%

exit /B


rem -------------------------
rem  Find a string in a file
rem -------------------------
:findInFile $find $file

rem Set the variable scope.
setlocal

rem Set the variable(s).
set $find=%~1
set $file=%~2
set $boolean=false

rem Parse the file one line at a time.
for /f "tokens=1,* delims=0123456789" %%a in ('find /n /v "" ^< "!$file!"') do (

    rem Set the variable(s).
    set "$line=%%b"

    rem Check if the line matches.
    if /i "!$line!" equ "!$find!" (
        set $boolean=true
    )
)

endlocal & set $result=%$boolean%

exit /B


rem -------------------------------------
rem  Get the .ini file section key value
rem -------------------------------------
:getIniValue $iniFile $section $key

rem Set the variable scope.
setlocal

rem Set the arguments.
set $iniFile=%~1
set $section=[%~2]
set $key=%~3

rem Parse the config.ini file.
set $inSection=false
set $sectionLine=false
set $value=

for /F "usebackq delims=" %%a in ("!$iniFile!") do (

    rem Set the line.
    set $line=%%a

    rem Check for a matching section.
    if "!$line:~0,1!" equ "[" (
        if "!$line:~-1!" equ "]" (
            set $sectionLine=true

            if "!$line!" equ "!$section!" (
                set $inSection=true
            ) else (
                set $inSection=false
            )
        )
    ) else (
         set $sectionLine=false
     )

    rem Check that we are within the matching section and at a key / value pair line.
    if "!$inSection!" equ "true" (
        if "!$sectionLine!" equ "false" (
            for /F "tokens=1,2 delims==" %%b in ("!$line!") do (
                rem Set the section key and remove any peripheral spaces.
                set $sectionKey=%%b
                set $sectionKey=!$sectionKey: =!

                rem Set the section value and remove any peripheral spaces.
                set $sectionValue=%%c
                set $sectionValue=!$sectionValue: =!

                rem Check for a matching keys.
                if "!$sectionKey!" equ "!$key!" (
                    set $value=!$sectionValue!
                )
            )
        )
    )
)

endlocal & set $result=%$value%

exit /B


rem ====================================================================================================================
rem                                                      File Templates
rem ====================================================================================================================

rem -----------------------------------------------------------
rem  The vhosts 'httpd-ssl.conf' configuration (template) file
rem -----------------------------------------------------------
:httpdSslCommonConfigFile

echo Listen 443
echo:
echo #   SSL Cipher Suite:
echo SSLCipherSuite HIGH:MEDIUM:^^!MD5:^^!RC4:^^!3DES
echo SSLProxyCipherSuite HIGH:MEDIUM:^^!MD5:^^!RC4:^^!3DES
echo:
echo #  Enforce the server's cipher order.
echo SSLHonorCipherOrder on
echo:
echo #   SSL Protocol support:
echo SSLProtocol all -SSLv3
echo SSLProxyProtocol all -SSLv3
echo:
echo #   Pass Phrase Dialog:
echo SSLPassPhraseDialog  builtin
echo:
echo #   Inter-Process Session Cache:
echo SSLSessionCache        "shmcb:c:/Apache24/logs/ssl_scache(512000)"
echo SSLSessionCacheTimeout  300

exit /B


rem ---------------------------------------------------------
rem  The OpenSSL 'openssl.cnf' configuration (template) file
rem ---------------------------------------------------------
:openSslCnfFile

echo #
echo # OpenSSL config file for !$config[name]!
echo #
echo:
echo [req]
echo default_bits       = 2048
echo default_md         = sha256
echo distinguished_name = dn
echo x509_extensions    = san
echo req_extensions     = san
echo extensions         = san
echo prompt             = no
echo:
echo [dn]
echo C            = !$config[sslCountry]!
echo ST           = !$config[sslState]!
echo L            = !$config[sslCity]!
echo O            = !$config[sslOrganization]!
echo OU           = !$config[sslOrganizationUnit]!
echo CN           = !$config[hostname]!
echo emailAddress = !$config[sslEmail]!!$config[hostname]!
echo:
echo [san]
echo subjectAltName = DNS:!$config[hostname]!

exit /B


rem --------------------------------------------------------------
rem  The vhosts 'httpd-vhosts.conf' configuration (template) file
rem --------------------------------------------------------------
:apache24HttpVhostConfigFile

echo # Virtual Host - http://!$config[hostname]!
echo #
echo ^<VirtualHost *:80^>
echo:
echo     ServerName !$config[hostname]!
echo     ServerAlias !$config[hostname]!
echo     ServerAdmin admin@!$config[hostname]!
echo     DocumentRoot "!$config[documentRoot]!"
echo:
echo     ^<Directory "!$config[documentRoot]!/"^>
echo         Options +Indexes +Includes +FollowSymLinks +MultiViews
echo         AllowOverride All
echo         Require local
echo         Require ip !$ipNetworkPart!
echo     ^</Directory^>
echo:
echo ^</VirtualHost^>

exit /B


rem ---------------------------------------------------------------------------
rem  The vhosts 'httpd-ssl.conf' configuration (template) file (with HTTP/1.1)
rem ---------------------------------------------------------------------------
:apache24Https11VhostConfigFile

echo # Virtual Host - https://!$config[hostname]!
echo #
echo ^<VirtualHost *:443^>
echo:
echo     ServerName !$config[hostname]!
echo     ServerAlias !$config[hostname]!
echo     ServerAdmin admin@%!$config[hostname]!
echo     DocumentRoot "!$config[documentRoot]!"
echo:
echo     ^<Directory "!$config[documentRoot]!/"^>
echo         SSLOptions +StdEnvVars
echo         Options +Indexes +Includes +FollowSymLinks +MultiViews
echo         AllowOverride All
echo         Require local
echo         Require ip !$ipNetworkPart!
echo     ^</Directory^>
echo:
echo     SSLEngine on
echo:
echo     SSLCertificateFile "!$config[wampServerExtensionsPath]!/certs/!$config[hostname]!/server.crt"
echo     SSLCertificateKeyFile "!$config[wampServerExtensionsPath]!/certs/!$config[hostname]!/private.key"
echo:
echo     LogFormat "%%L [%%{%%a, %%d-%%b-%%g %%T}t %%{%%z}t] %%H %%m \"%%U%%q\" (%%b bytes) %%>s" access
echo     CustomLog "!$config[wampServerExtensionsPath]!/logs/!$config[hostname]!/access.log" access
echo:
echo     ErrorLogFormat "%%L [%%t] [%%-m:%%l] [pid %%P:tid %%T] %%E: %%a %%M"
echo     ErrorLog "!$config[wampServerExtensionsPath]!/logs/!$config[hostname]!/error.log"
echo:
echo     LogFormat "%%L [%%{%%a, %%d-%%b-%%g %%T}t %%{%%z}t] %%H %%{SSL_PROTOCOL}x %%{SSL_CIPHER}x %%m \"%%U%%q\" (%%b bytes) %%>s" ssl
echo     CustomLog "!$config[wampServerExtensionsPath]!/logs/!$config[hostname]!/ssl_request.log" ssl
echo:
echo ^</VirtualHost^>

exit /B


rem -------------------------------------------------------------------------
rem  The vhosts 'httpd-ssl.conf' configuration (template) file (with HTTP/2)
rem -------------------------------------------------------------------------
:apache24Https2VhostConfigFile

echo # Virtual Host - https://!$config[hostname]!
echo #
echo ^<VirtualHost *:443^>
echo:
echo     ServerName !$config[hostname]!
echo     ServerAlias !$config[hostname]!
echo     ServerAdmin admin@%!$config[hostname]!
echo     DocumentRoot "!$config[documentRoot]!"
echo:
echo     ^<Directory "!$config[documentRoot]!/"^>
echo         SSLOptions +StdEnvVars
echo         Options +Indexes +Includes +FollowSymLinks +MultiViews
echo         AllowOverride All
echo         Require local
echo         Require ip !$ipNetworkPart!
echo     ^</Directory^>
echo:
echo     SSLEngine on
echo:
echo     SSLCertificateFile "!$config[wampServerExtensionsPath]!/certs/!$config[hostname]!/server.crt"
echo     SSLCertificateKeyFile "!$config[wampServerExtensionsPath]!/certs/!$config[hostname]!/private.key"
echo:
echo     LogFormat "%%L [%%{%%a, %%d-%%b-%%g %%T}t %%{%%z}t] %%H %%m \"%%U%%q\" (%%b bytes) %%>s" access
echo     CustomLog "!$config[wampServerExtensionsPath]!/logs/!$config[hostname]!/access.log" access
echo:
echo     ErrorLogFormat "%%L [%%t] [%%-m:%%l] [pid %%P:tid %%T] %%E: %%a %%M"
echo     ErrorLog "!$config[wampServerExtensionsPath]!/logs/!$config[hostname]!/error.log"
echo:
echo     LogFormat "%%L [%%{%%a, %%d-%%b-%%g %%T}t %%{%%z}t] %%H %%{SSL_PROTOCOL}x %%{SSL_CIPHER}x %%m \"%%U%%q\" (%%b bytes) %%>s" ssl
echo     CustomLog "!$config[wampServerExtensionsPath]!/logs/!$config[hostname]!/ssl_request.log" ssl
echo:
echo     SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
echo     Protocols h2 http/1.1
echo:
echo ^</VirtualHost^>

exit /B


rem ------------------------------------------
rem  Include SSL in Apache configuration file
rem ------------------------------------------
:includeSslInConfigFile

echo:
echo # SSL Config - Additional
echo Include "!$config[wampServerExtensionsPath]!/vhosts/https/conf/httpd-ssl.conf"

exit /B


rem ----------------------------------------------------
rem  Include http vhost(s) in Apache configuration file
rem ----------------------------------------------------
:includeHttpVhostInConfigFile

echo:
echo # HTTP Vhost(s) - Additional
echo Include "!$config[wampServerExtensionsPath]!/vhosts/http/*.conf"

exit /B


rem -----------------------------------------------------
rem  Include https vhost(s) in Apache configuration file
rem -----------------------------------------------------
:includeHttpsVhostInConfigFile

echo:
echo # HTTPS Vhost(s) - Additional
echo Include "!$config[wampServerExtensionsPath]!/vhosts/https/*.conf"

exit /B


rem -------------------------------------
rem  Include hostname in OS 'hosts' file
rem -------------------------------------
:includeOsHostsFile

echo:
echo # Name:       !$config[name]!
echo # Hostname:   !$config[hostname]!
echo # Doc Root:   !$config[documentRoot]!
echo # IP Address: !$ipAddress!
echo # Notes:      To access this hostname from another LAN computer, add
echo #             "!$ipAddress! !$config[hostname]!" to their 'hosts' file.
echo # Added By:   WampServer SSL Auto Config script.
echo 127.0.0.1 !$config[hostname]!
echo ::1 !$config[hostname]!

exit /B


rem ====================================================================================================================
rem                                               Success Message
rem ====================================================================================================================
:success
echo:
echo   -----------------------------------------------------------
echo:
echo                             SUCCESS
echo:
echo   -----------------------------------------------------------
echo:
echo   Please refresh / restart any open web browsers.
echo:
echo   Goodbye.
echo:
echo   -----------------------------------------------------------
echo:
echo   Press any key to exit.
pause >nul

exit 0


rem ====================================================================================================================
rem                                               Warning Message
rem ====================================================================================================================
:warning
echo:
echo   -----------------------------------------------------------
echo:
echo                             WARNING
echo:
echo   -----------------------------------------------------------
echo:
echo   Unable To Modify The OS 'hosts' File
echo:
echo   This step may have failed because of the following reasons:
echo   1. You are not a member of the Administrators group.
echo   2. Your virus protection software is preventing this script
echo      from updating the 'hosts' file.
echo:
echo   To fix this problem you can either:
echo   1. Add yourself to the Administrators group and run this
echo      script again.
echo   2. Temporarily disable your virus protection software and
echo      run this script again (or add the name of this script
echo      to your virus protection software trusted applications
echo      list^).
echo:
echo   If you are already a member of the Administrators group
echo   then the most probable cause is your virus protection
echo   software.
echo:
echo   -----------------------------------------------------------
echo:
echo   Press any key to exit.
pause >nul

exit 1


rem ====================================================================================================================
rem                                               Failure Message
rem ====================================================================================================================
:failure $title $file $error $message

rem Set the variable.
set $title=%~1
set $file=%~2
set $error=%~3
set $message=%~4

echo:
echo   -----------------------------------------------------------
echo:
echo                             FAILURE
echo:
echo   -----------------------------------------------------------
echo:
echo   %$title%
echo:
echo:  File:  %$file%
echo   Error: %$error%
echo:
if /i "!$message!" neq "" (
    echo   %$message%
    echo:
)
echo   -----------------------------------------------------------
echo:
echo   Press any key to exit.
pause >nul

exit 1