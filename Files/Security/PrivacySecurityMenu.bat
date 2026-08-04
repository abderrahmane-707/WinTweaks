:PRIVACY_SECURITY_MENU
cls & echo. & echo.
echo                        --------------------------- Privacy and Security --------------------------
echo.
echo                          [1] Telemetry                                       [2] Privacy Cleanup
echo.
echo                          [3] Windows Updates                                 [4] Windows Defender
echo.
echo                          [5] Enhance Security                                [6] Policies
echo.
echo                          [7] Security Info                                   [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" (
    set ROUTINE=DISABLE_TELEMETRY
    set REV_ROUTINE=REV_DISABLE_TELEMETRY
    set APPLY=Disable Windows telemetry
    set REVERT=Default Windows telemetry
    set MENU=PRIVACY_SECURITY_MENU
    call "%F%" SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="2" goto PRIVACY_CLEANUP
if "%choice%"=="3" goto WINDOWS_UPDATES_MENU
if "%choice%"=="4" goto WINDOWS_DEFENDER_MENU
if "%choice%"=="5" (
    set ROUTINE=ENHANCE_SECURITY
    set REV_ROUTINE=REV_ENHANCE_SECURITY
    set APPLY=Enhance system security
    set REVERT=Default system security
    set MENU=PRIVACY_SECURITY_MENU
    call "%F%" SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="6" (
    set ROUTINE=REMOVE_POLICIES
    set REV_ROUTINE=REV_REMOVE_POLICIES
    set APPLY=Remove all policies setting
    set REVERT=Restore all policies setting
    set MENU=PRIVACY_SECURITY_MENU
    call "%F%" SUB_MENU
    goto !SUBMENU_RESULT!
)

if "%choice%"=="7" (call "%F%" INFO_SCRIPT "Security" "SecurityInfo"  & goto PRIVACY_SECURITY_MENU)
if "%choice%"=="0" exit /b 99

call "%F%" INVALID "(0-7)" & goto PRIVACY_SECURITY_MENU

:DISABLE_TELEMETRY
call "%F%" PATH_DIR "Security" "DisableTelemetry"
call "%F%" CREATE_FILE "Security" "HostsOriginal"
if !errorlevel! equ 1 goto PRIVACY_SECURITY_MENU

set "HOSTS_PATH=%SYSTEMROOT%\System32\drivers\etc\hosts"

echo. & echo Disabling Windows telemetry via registry
reg import "Files\Security\DisableTelemetry.reg" >> "%LOG_FILE%" 2>&1

echo Disabling Windows telemetry services

:: DiagTrack:      Connected User Experiences and Telemetry
:: dmwappushsvc:   WAP Push Message Routing Service
:: WerSvc:         Windows Error Reporting Service
for %%S in ("DiagTrack" "dmwappushsvc" "WerSvc") do call "%F%" SC_CONFIGURE "%%S" "disabled" >> "%LOG_FILE%" 2>&1

echo Backing up original Hosts file
copy /y "%HOSTS_PATH%" "%TARGET_FILE%" >> "%LOG_FILE%" 2>&1

echo Blocking windows telemetry and trash domains
for /f "usebackq delims=" %%L in ("Files\Security\TrackingDomains.txt") do (
    findstr /C:"%%L" "%HOSTS_PATH%" >nul
    if !errorlevel! neq 0 (
        echo %%L>>"%HOSTS_PATH%"
    )
)

echo Flushing DNS cache
ipconfig /flushdns >> "%LOG_FILE%" 2>&1

call "%F%" LOG & goto PRIVACY_SECURITY_MENU

:REV_DISABLE_TELEMETRY
call "%F%" PATH_DIR "Security" "DefaultTelemetry"

set "HOSTS_PATH=%SYSTEMROOT%\System32\drivers\etc\hosts"
set "TEMP_FILE=%TEMP%\HostsClean.txt"

echo. & echo Restoring default telemetry registry settings
reg import "Files\Security\DefaultTelemetry.reg" >> "%LOG_FILE%" 2>&1

echo Setting telemetry services to manual startup
for %%S in ("DiagTrack" "dmwappushsvc" "WerSvc") do call "%F%" SC_CONFIGURE "%%S" "demand" >> "%LOG_FILE%" 2>&1

echo Removing telemetry and trash domain entries from the Hosts file
:: Filter out blocked domains listed in TrackingDomains.txt from the HOSTS file
findstr /V /L /G:"Files\Security\TrackingDomains.txt" "%HOSTS_PATH%" > "%TEMP_FILE%"

:: Overwrite the original HOSTS file with the filtered version
copy /y "%TEMP_FILE%" "%HOSTS_PATH%" >> "%LOG_FILE%" 2>&1
del "%TEMP_FILE%" >nul 2>&1

echo Flushing DNS cache
ipconfig /flushdns >> "%LOG_FILE%" 2>&1

call "%F%" LOG & goto PRIVACY_SECURITY_MENU

:PRIVACY_CLEANUP
call "%F%" CONFIRM "WARNING: This will PERMANENTLY DELETE browser data, logs, and privacy-related information"
if errorlevel 2 goto PRIVACY_SECURITY_MENU

echo.
call "%F%" RUNNING_BROWSERS

if "!BROWSERS_OPEN!"=="1" (
    echo Closing open browsers
    for %%B in (%BROWSERS%) do (
        taskkill /IM "%%B" /F /T >nul 2>&1
    )
    timeout /t 2 >nul
)

:: Remove all Chromium-based browsers personal data
call "%F%" DELETE_FOLDERS "Cleaning Google Chrome data" "%LOCALAPPDATA%\Google\Chrome\User Data"
call "%F%" DELETE_FOLDERS "Cleaning Brave data" "%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data"
call "%F%" DELETE_FOLDERS "Cleaning Microsoft Edge data" "%LOCALAPPDATA%\Microsoft\Edge\User Data"

:: Remove all Mozilla Firefox personal data
call "%F%" DELETE_FOLDERS "Cleaning Firefox roaming user data" "%APPDATA%\Mozilla\Firefox"
call "%F%" DELETE_FOLDERS "Cleaning Firefox local user data" "%LOCALAPPDATA%\Mozilla\Firefox"

echo Cleaning registry entries
reg import "Files\Security\PrivacyCleanup.reg" >nul 2>&1

:: Clean System Log files
echo Cleaning system log files
for %%F in ("%SYSTEMROOT%\Logs" "%SYSTEMROOT%\System32\LogFiles") do (
    if exist "%%~F" (
        "Files\Security\PowerRun.exe" /TI /SW:0 cmd.exe /c "del /f /q "%%~F\*""
            for /d %%D in ("%%~F\*") do (
            "Files\Security\PowerRun.exe" /TI /SW:0 cmd.exe /c "rd /s /q "%%~D""
        )
    )
)

:: Clear Windows Event Viewer logs
echo Cleaning Windows Event Logs
for %%L in ("Application" "Security" "System" "Setup") do wevtutil clear-log %%L >nul 2>&1

echo Clearing clipboard content
echo. | clip >nul

echo Flushing DNS cache
ipconfig /flushdns >nul 2>&1

call "%F%" CLEANING_FUNCTION
call "%F%" GO & goto PRIVACY_SECURITY_MENU

:WINDOWS_UPDATES_MENU
cls & echo. & echo.
echo                        ------------------------------ Windows Updates ----------------------------
echo.
echo                           [1] Disable Updates                               [2] Enable Updates
echo.
echo                           [3] Reset / Repair Updates                        [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto DISABLE_UPDATES
if "%choice%"=="2" goto ENABLE_UPDATES
if "%choice%"=="3" goto RESET_UPDATES
if "%choice%"=="0" goto PRIVACY_SECURITY_MENU

call "%F%" INVALID "(0-3)" & goto WINDOWS_UPDATES_MENU

:DISABLE_UPDATES
call "%F%" PATH_DIR "Security" "DisableUpdates"

echo. & echo Disabling Windows Updates via registry
reg import "Files\Security\DisableUpdates.reg" >> "%LOG_FILE%" 2>&1

echo Disabling Windows Update services
for %%S in ("BITS" "UsoSvc" "wuauserv") do call "%F%" SC_CONFIGURE "%%S" "disabled" >> "%LOG_FILE%" 2>&1

echo Stopping Windows Update services
for %%S in ("BITS" "UsoSvc" "wuauserv") do call "%F%" NET_CONTROL "%%S" "stop" >> "%LOG_FILE%" 2>&1

call "%F%" DELETE_FOLDERS "Deleting SoftwareDistribution folder" "%SYSTEMROOT%\SoftwareDistribution" "%LOG_FILE%"

call "%F%" DELETE_FILES "Deleting Windows Update log file" "%SYSTEMROOT%\WindowsUpdate.log" "%LOG_FILE%"

call "%F%" LOG & goto WINDOWS_UPDATES_MENU

:ENABLE_UPDATES
call "%F%" PATH_DIR "Security" "DefaultUpdates"

echo. & echo Restoring default Windows Update registry settings
reg import "Files\Security\DefaultUpdates.reg" >> "%LOG_FILE%" 2>&1

echo Setting Windows Update services to default startup
call "%F%" SC_CONFIGURE "UsoSvc" "delayed-auto" >> "%LOG_FILE%" 2>&1
for %%S in ("BITS" "wuauserv") do call "%F%" SC_CONFIGURE "%%S" "demand" >> "%LOG_FILE%" 2>&1

call "%F%" LOG & goto WINDOWS_UPDATES_MENU

:RESET_UPDATES
call "%F%" CONFIRM "WARNING: This will purge all Windows Update data and reset security policies"
if errorlevel 2 goto WINDOWS_UPDATES_MENU

call "%F%" PATH_DIR "Security" "ResetUpdates"

echo. & echo Resetting Windows Update registry keys to default
reg import "Files\Security\ResetUpdates.reg" >> "%LOG_FILE%" 2>&1

echo Stopping Windows Update services

:: BITS:                  Background Intelligent Transfer Service
:: CryptSvc:              Verifies system file signatures
:: DoSvc:                 Delivery Optimization
:: UsoSvc:                Update Orchestrator Service
:: WaaSMedicSvc:          Windows Update Medic Service
:: wuauserv:              Windows Update Service
:: WinHttpAutoProxySvc:   Automatically discover proxy settings using WPAD
for %%S in ("BITS" "CryptSvc" "DoSvc" "UsoSvc" "WaaSMedicSvc" "wuauserv" "WinHttpAutoProxySvc") do call "%F%" NET_CONTROL "%%S" "stop" >> "%LOG_FILE%" 2>&1

:: Remove pending Updates and update history
call "%F%" DELETE_FOLDERS "Deleting SoftwareDistribution folder" "%SYSTEMROOT%\SoftwareDistribution" "%LOG_FILE%"

:: Force Windows to rebuild the update database and signatures
call "%F%" DELETE_FOLDERS "Deleting Catroot2 folder" "%SYSTEMROOT%\System32\catroot2" "%LOG_FILE%"

:: Remove BITS Queue Manager (QMGR) data files to clear stuck download jobs
call "%F%" DELETE_FILES "Clearing BITS queue manager data files" "%ALLUSERSPROFILE%\Microsoft\Network\Downloader\qmgr*.dat" "%LOG_FILE%"

call "%F%" DELETE_FILES "Deleting Windows Update log file" "%SYSTEMROOT%\WindowsUpdate.log" "%LOG_FILE%"

:: Restore default Security Descriptors (Permissions) for BITS and Windows Update services
:: This fixes "Access Denied" errors that prevent services from starting
echo Resetting security descriptors for BITS and wuauserv services
sc sdset bits D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU) >> "%LOG_FILE%" 2>&1
sc sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU) >> "%LOG_FILE%" 2>&1

:: Re-register essential System DLLs (Libraries) for updates, web protocols, and encryption
echo Re-registering critical system libraries
for %%D in (atl.dll urlmon.dll mshtml.dll shdocvw.dll browseui.dll jscript.dll vbscript.dll scrrun.dll msxml.dll msxml3.dll msxml6.dll actxprxy.dll softpub.dll wintrust.dll dssenh.dll rsaenh.dll gpkcsp.dll sccbase.dll slbcsp.dll cryptdlg.dll oleaut32.dll ole32.dll shell32.dll initpki.dll wuapi.dll wuaueng.dll wups.dll wups2.dll qmgr.dll qmgrprxy.dll wucltux.dll muweb.dll) do (
    regsvr32 /s "%windir%\System32\%%D" >> "%LOG_FILE%" 2>&1
)

:: Revert system security policies to the Windows default baseline
echo Applying default security policy baseline
secedit /configure /cfg "%SYSTEMROOT%\inf\defltbase.inf" /db "%TEMP%\defltbase.sdb" /verbose >> "%LOG_FILE%" 2>&1

:: Forcefully clear all BITS download jobs for all users on the system
echo Clearing all BITS download jobs
bitsadmin /reset /allusers >> "%LOG_FILE%" 2>&1

echo Setting Windows Update services to default startup
call "%F%" SC_CONFIGURE "CryptSvc" "auto"
for %%S in ("UsoSvc" "DoSvc") do call "%F%" SC_CONFIGURE "%%S" "delayed-auto" >> "%LOG_FILE%" 2>&1
for %%S in ("BITS" "WaaSMedicSvc" "wuauserv" "WinHttpAutoProxySvc") do call "%F%" SC_CONFIGURE "%%S" "demand" >> "%LOG_FILE%" 2>&1

echo Reset TCP/IP Stack
netsh int ip reset >> "%LOG_FILE%" 2>&1

echo Reset Winsock catalog
netsh winsock reset >> "%LOG_FILE%" 2>&1

echo Reset WinHTTP proxy
netsh winhttp reset proxy >> "%LOG_FILE%" 2>&1

echo Flushing DNS
ipconfig /flushdns >> "%LOG_FILE%" 2>&1

echo Releasing IP addresses
ipconfig /release >> "%LOG_FILE%" 2>&1

echo Renewing IP addresses
ipconfig /renew >> "%LOG_FILE%" 2>&1

echo Registering DNS name
ipconfig /registerdns >> "%LOG_FILE%" 2>&1

call "%F%" RESTART 
call "%F%" LOG & goto WINDOWS_UPDATES_MENU

:WINDOWS_DEFENDER_MENU
cls & echo. & echo.
echo                        ----------------------------- Windows Defender ----------------------------
echo.
echo                          [1] Disable Defender                                [2] Enable Defender
echo.
echo                          [3] Remove Defender                                 [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto DISABLE_DEFENDER
if "%choice%"=="2" goto ENABLE_DEFENDER
if "%choice%"=="3" goto REMOVE_DEFENDER
if "%choice%"=="0" goto PRIVACY_SECURITY_MENU

call "%F%" INVALID "(0-3)" & goto WINDOWS_DEFENDER_MENU

:DISABLE_DEFENDER
call "%F%" CONFIRM "WARNING: This will PERMANENTLY DISABLE Windows Defender real-time protection"
if errorlevel 2 goto WINDOWS_DEFENDER_MENU

echo. & echo Disabling Windows defender via registry
reg import "Files\Security\DisableDefender.reg"

call "%F%" RESTART 
call "%F%" GO & goto WINDOWS_DEFENDER_MENU

:ENABLE_DEFENDER
echo. & echo Restoring default Windows Defender registry settings
reg import "Files\Security\DefaultDefender.reg"

call "%F%" RESTART 
call "%F%" GO & goto WINDOWS_DEFENDER_MENU

:REMOVE_DEFENDER
call "%F%" CONFIRM "WARNING: This will PERMANENTLY remove Windows Defender core files and services from your system"
if errorlevel 2 goto WINDOWS_DEFENDER_MENU

echo. & echo Removing Windows Defender Security Health UI component
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Security\RemoveSecHealthUI.ps1" >nul

echo Removing Windows Defender entries from the registry
for %%f in ("Files\Security\RemoveDefenderModule\*.reg") do "Files\Security\PowerRun.exe" /TI /SW:0 regedit.exe /s "%%f"

echo Deleting Windows Defender files
"Files\Security\PowerRun.exe" /TI /SW:0 "Files\Security\DefenderFileRemover.bat"

call "%F%" RESTART 
call "%F%" GO & goto WINDOWS_DEFENDER_MENU

:ENHANCE_SECURITY
call "%F%" PATH_DIR "Security" "EnhanceSecurity"

echo. & echo Applying security hardening registry settings
reg import "Files\Security\EnhanceSecurity.reg" >> "%LOG_FILE%" 2>&1

echo Disabling unsafe Windows features
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Security\DisableUnsafeFeature.ps1" >> "%LOG_FILE%" 2>&1

echo Disabling unsafe Windows services

:: mrxsmb10:        SMB 1.0/CIFS File Server Driver (High security risk)
:: RemoteRegistry:  Allows remote users to modify Windows Registry settings
:: SNMP:            Simple Network Management Protocol (Often used for network reconnaissance)
:: SNMPTRAP:        Receives trap messages generated by local or remote SNMP agents
for %%S in ("mrxsmb10" "RemoteRegistry" "SNMP" "SNMPTRAP") do (
    call "%F%" NET_CONTROL "%%S" "stop" >> "%LOG_FILE%" 2>&1
    call "%F%" SC_CONFIGURE "%%S" "disabled" >> "%LOG_FILE%" 2>&1
)

:: Remove 'defaultuser0', a temporary account often left behind after Windows installation
echo Removing temporary default user account
net user defaultuser0 /delete >> "%LOG_FILE%" 2>&1

call "%F%" LOG & goto PRIVACY_SECURITY_MENU

:REV_ENHANCE_SECURITY
echo. & echo Restoring default Windows security registry settings
reg import "Files\Security\DefaultSecurity.reg"

call "%F%" GO & goto PRIVACY_SECURITY_MENU

:REMOVE_POLICIES
call "%F%" CONFIRM "WARNING: This script will RESET all Group Policy settings to system defaults"
if errorlevel 2 goto PRIVACY_SECURITY_MENU

call "%F%" CREATE_FOLDER "Security" "GroupPolicyBackup"
if !errorlevel! equ 1 goto PRIVACY_SECURITY_MENU

call "%F%" PATH_DIR "Security" "RemoveAllPolicies"

set "GP_DIR=%WinDir%\System32\GroupPolicy"
set "GPU_DIR=%WinDir%\System32\GroupPolicyUsers"

set "GP_KEY=HKLM\Software\Policies"
set "GPU_KEY=HKCU\Software\Policies"

set "INF_FILE=%SYSTEMROOT%\inf\defltbase.inf"
set "SEC_BACKUP=%TARGET_FOLDER%\SecurityBackup.inf"

set "HKLM_POLICIES=1"
set "HKCU_POLICIES=1"
set "DEFLTBASE_INF=1"

set "HKLM_POL_SUCCESS=1"
set "HKCU_POL_SUCCESS=1"
set "SEC_POL_SUCCESS=1"

echo.
reg query "%GP_KEY%" >nul 2>&1
if !errorlevel! equ 0 (
    set "HKLM_POLICIES=0"
    echo Backing up HKLM Policies registry key
    reg export "%GP_KEY%" "%TARGET_FOLDER%\HKLM_Policies_Backup.reg" >> "%LOG_FILE%" 2>&1
    if !errorlevel! neq 0 (
	    set "HKLM_POL_SUCCESS=0"
        echo Failed to backup: %GP_KEY%
        echo Skipping deletion for this key
        echo.
    )
)

reg query "%GPU_KEY%" >nul 2>&1
if !errorlevel! equ 0 (
    set "HKCU_POLICIES=0"
    echo Backing up HKCU Policies registry key
    reg export "%GPU_KEY%" "%TARGET_FOLDER%\HKCU_Policies_Backup.reg" >> "%LOG_FILE%" 2>&1
    if !errorlevel! neq 0 (
	    set "HKCU_POL_SUCCESS=0"
        echo Failed to backup: %GPU_KEY%
        echo Skipping deletion for this key
        echo.
    )
)

if exist "%INF_FILE%" (
    set "DEFLTBASE_INF=0"
    echo Backing up current security policies
    secedit /export /cfg "%SEC_BACKUP%" >> "%LOG_FILE%" 2>&1
    if !errorlevel! neq 0 (
	    set "SEC_POL_SUCCESS=0"
        echo Failed to backup: %INF_FILE%
        echo Skipping baseline security reset
		echo.
    )
)

if exist "%GP_DIR%" (
    echo Moving and Backing up GroupPolicy folder
    robocopy "%GP_DIR%" "%TARGET_FOLDER%\GroupPolicy" /E /COPYALL /MOVE /R:0 /W:0 >> "%LOG_FILE%" 2>&1
    if !errorlevel! geq 8 (
        echo Failed to move: %GP_DIR%
        echo Skipping folder movement
    )
)

if exist "%GPU_DIR%" (
    echo Moving and Backing up GroupPolicyUsers folder
    robocopy "%GPU_DIR%" "%TARGET_FOLDER%\GroupPolicyUsers" /E /COPYALL /MOVE /R:0 /W:0 >> "%LOG_FILE%" 2>&1
    if !errorlevel! geq 8 (
        echo Failed to move: %GPU_DIR%
        echo Skipping folder movement
    )
)

if "!HKLM_POLICIES!"=="0" if "!HKLM_POL_SUCCESS!"=="1" (
    echo Deleting HKLM Policies registry key
    reg delete "%GP_KEY%" /f >> "%LOG_FILE%" 2>&1
)

if "!HKCU_POLICIES!"=="0" if "!HKCU_POL_SUCCESS!"=="1" (
    echo Deleting HKCU Policies registry key
    reg delete "%GPU_KEY%" /f >> "%LOG_FILE%" 2>&1
)

if "!DEFLTBASE_INF!"=="0" if "!SEC_POL_SUCCESS!"=="1" (
    echo Applying default security policy baseline
    secedit /configure /cfg "%INF_FILE%" /db "%TEMP%\defltbase.sdb" /verbose >> "%LOG_FILE%" 2>&1
)

echo. & echo Applying Group Policy Update
gpupdate /force >nul 2>&1

echo Backup files saved in: %TARGET_FOLDER%
call "%F%" LOG & goto PRIVACY_SECURITY_MENU

:REV_REMOVE_POLICIES
echo. & call "%F%" CHOICE "WARNING: Restoring previous Group Policy settings will overwrite current changes. Press (N) if you are unsure"
if errorlevel 2 goto PRIVACY_SECURITY_MENU

call "%F%" PATH_DIR "Security" "RestoreAllPolicies"

set "TARGET_FOLDER=%MKDIR_DIR%\GroupPolicyBackup"

set "GP_DIR=%WinDir%\System32\GroupPolicy"
set "GPU_DIR=%WinDir%\System32\GroupPolicyUsers"

set "BACKUP_GP=%TARGET_FOLDER%\GroupPolicy"
set "BACKUP_GPU=%TARGET_FOLDER%\GroupPolicyUsers"

set "HKLM_POL_BACKUP=%TARGET_FOLDER%\HKLM_Policies_Backup.reg"
set "HKCU_POL_BACKUP=%TARGET_FOLDER%\HKCU_Policies_Backup.reg"
set "SEC_BACKUP=%TARGET_FOLDER%\SecurityBackup.inf"

for %%F in (
    "%HKLM_POL_BACKUP%"
    "%HKCU_POL_BACKUP%"
    "%SEC_BACKUP%"
) do (
    if exist "%%~F" goto :FOUND_POLICIES_BACKUP
)

if exist "%BACKUP_GP%" goto :FOUND_POLICIES_BACKUP
if exist "%BACKUP_GPU%" goto :FOUND_POLICIES_BACKUP

echo No backup files found to restore
call "%F%" LOG & goto PRIVACY_SECURITY_MENU

:FOUND_POLICIES_BACKUP
if exist "%BACKUP_GP%" (
    echo Restoring GroupPolicy folder
    robocopy "%BACKUP_GP%" "%GP_DIR%" /E /COPYALL /MOVE /R:0 /W:0 >> "%LOG_FILE%" 2>&1
)

if exist "%BACKUP_GPU%" (
    echo Restoring GroupPolicyUsers folder
    robocopy "%BACKUP_GPU%" "%GPU_DIR%" /E /COPYALL /MOVE /R:0 /W:0 >> "%LOG_FILE%" 2>&1
)

if exist "%HKLM_POL_BACKUP%" (
    echo Restoring HKLM Policies registry keys
    reg import "%HKLM_POL_BACKUP%" >> "%LOG_FILE%" 2>&1
)

if exist "%HKCU_POL_BACKUP%" (
    echo Restoring HKCU Policies registry keys
    reg import "%HKCU_POL_BACKUP%" >> "%LOG_FILE%" 2>&1
)

if exist "%SEC_BACKUP%" (
    echo Restoring security policies baseline
    secedit /configure /cfg "%SEC_BACKUP%" /db "%TEMP%\defltbase_restore.sdb" /verbose >> "%LOG_FILE%" 2>&1
)

echo. & echo Applying Group Policy Update
gpupdate /force >nul 2>&1

echo. & call "%F%" CHOICE "Do you want to delete existing backup folder"
if !errorlevel! equ 1 (
    echo Deleting: %TARGET_FOLDER%
    rd /s /q "%TARGET_FOLDER%" >> "%LOG_FILE%" 2>&1
)

call "%F%" LOG & goto PRIVACY_SECURITY_MENU