@echo off
setlocal enabledelayedexpansion
title WinTweaks

:: Check for administrator privileges
fltmc >nul 2>&1
if errorlevel 1 (
    echo This script must be run with Administrator privileges
    pause & exit /b 1
)

:: Go to script's directory
cd /d "%~dp0"

:: WinTweaks Script main menu
:MAIN_MENU
cls
echo.
echo                                                           \\!//
echo                                                           (o o)
echo                        -------------------------------oOOo-(_)-oOOo-------------------------------
echo.
echo                            [1] Performance                                        [2] Security
echo.
echo                            [3] Network                                            [4] Packages
echo.
echo                            [5] Customization                                      [6] System
echo.
echo                            [7] Tools                                              [8] Other
echo.
echo                                                          [0] Exit
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto PERFORMANCE_MENU
if "%choice%"=="2" goto PRIVACY_SECURITY_MENU
if "%choice%"=="3" goto NETWORK_MENU
if "%choice%"=="4" goto PACKAGES_MENU
if "%choice%"=="5" goto CUSTOMIZATION_MENU
if "%choice%"=="6" goto SYSTEM_MENU
if "%choice%"=="7" goto TOOLS_MENU
if "%choice%"=="8" goto OTHER_MENU
if "%choice%"=="0" exit /b

call :INVALID "(0-8)" & goto MAIN_MENU

:PERFORMANCE_MENU
cls & echo. & echo.
echo                        ------------------------------- Performance -------------------------------
echo.
echo                          [1] Services                                         [2] Scheduled Tasks
echo.
echo                          [3] Boot Up                                          [4] Clean Up
echo.
echo                          [5] Power Plan                                       [6] Hardware Info
echo.
echo                                                         [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto SERVICES_MENU
if "%choice%"=="2" (
    set ROUTINE=DISABLE_TASKS
    set REV_ROUTINE=ENABLE_TASKS
    set APPLY=Disable unnecessary scheduled tasks
    set REVERT=Re-enable disabled scheduled tasks
    set MENU=PERFORMANCE_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="3" (
    set ROUTINE=BOOT_TWEAKS
    set REV_ROUTINE=REV_BOOT_TWEAKS
    set APPLY=Enhance boot-up settings
    set REVERT=Set boot-up settings to default
    set MENU=PERFORMANCE_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="4" goto CLEAN_UP
if "%choice%"=="5" goto POWER_PLAN_MENU
if "%choice%"=="6" goto HW_INFO_MENU
if "%choice%"=="0" goto MAIN_MENU

call :INVALID "(0-6)" & goto PERFORMANCE_MENU

:SERVICES_MENU
cls & echo. & echo.
echo                        -------------------------------- Services ---------------------------------
echo.
echo                          [1] Services Tweaks                                [2] Services Tweaks (Safe)
echo.
echo                          [3] Default Services                               [4] Export Services
echo.
echo                                                          [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" (
    set FILE=Files\Performance\ServicesTweaks.txt
    set MSG=Tweaking Windows services
    set LOG=ServicesTweaks
    goto SET_SERVICES
)
if "%choice%"=="2" (
    set FILE=Files\Performance\SafeServicesTweaks.txt
    set MSG=Tweaking Windows services in safe mode
    set LOG=SafeServicesTweaks
    goto SET_SERVICES
)
if "%choice%"=="3" (
    set FILE=Files\Performance\DefaultServicesSettings.txt
    set MSG=Restore Windows services to default startup
    set LOG=DefaultServicesSettings
    goto SET_SERVICES
)
if "%choice%"=="4" goto EXPORT_SERVICES
if "%choice%"=="0" goto PERFORMANCE_MENU

call :INVALID "(0-4)" & goto SERVICES_MENU

:SET_SERVICES
call :PATH_DIR "Performance" "%LOG%"
echo. & echo %MSG%
for /f "usebackq tokens=1,2 delims=," %%A in ("%FILE%") do (
    set "SERVICE_NAME=%%A"
    set "SERVICE_STATUS=%%B"

    sc config "!SERVICE_NAME!" start= !SERVICE_STATUS! >nul 2>&1
    if !errorlevel! equ 0 (
        echo [SUCCESS]: !SERVICE_NAME! _ !SERVICE_STATUS! >> "%LOG_FILE%"
    ) else if !errorlevel! equ 1060 (
        echo [NOT FOUND]: !SERVICE_NAME! >> "%LOG_FILE%"
    ) else (
        echo [FAILED]: !SERVICE_NAME! _ !SERVICE_STATUS! >> "%LOG_FILE%"
    )
)
call :LOG & goto SERVICES_MENU

:EXPORT_SERVICES
call :CREATE_FILE "Performance" "ServiceStartupStatus.log"
if errorlevel 1 goto SERVICES_MENU

echo. & echo Exporting service startup status
powershell -Command "Get-Service | Sort-Object Name | ForEach-Object { Write-Output ($_.Name + ',' + $_.StartType) }" >> "%TARGET_FILE%" 2>&1

echo. & echo Service Startup Status file saved in: %TARGET_FILE%
call :GO & goto SERVICES_MENU

:DISABLE_TASKS
call :PATH_DIR "Performance" "DisableScheduledTasks"
echo. & echo Disabling unnecessary scheduled tasks
call :SET_TASKS "disable" "Files\Performance\TasksList.txt"
call :LOG & goto PERFORMANCE_MENU
    
:ENABLE_TASKS
call :PATH_DIR "Performance" "EnableScheduledTasks"
echo. & echo Re-enable previously disabled scheduled tasks
call :SET_TASKS "enable" "Files\Performance\TasksList.txt"
call :LOG & goto PERFORMANCE_MENU

:BOOT_TWEAKS
call "%F%" CREATE_FOLDER "Performance" "StartupBackup"
if errorlevel 1 goto PERFORMANCE_MENU

set "TARGET_FOLDER=%MKDIR_DIR%\StartupBackup"
call "%F%" PATH_DIR "Performance" "BootTweaks"

set "START_MENU_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "ALL_START_MENU_DIR=%PROGRAMDATA%\Microsoft\Windows\Start Menu\Programs\Startup"

set "REG_HKCU_RUN=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "REG_HKLM_RUN=HKLM\Software\Microsoft\Windows\CurrentVersion\Run"

set "HKCU_STARTUP=1"
set "HKLM_STARTUP=1"

set "HKCU_BACKUP_SUCCESS=1"
set "HKLM_BACKUP_SUCCESS=1"

echo. & echo Importing Boot up tweaks registry settings
reg import "Files\Performance\BootTweaks.reg" >> "%LOG_FILE%" 2>&1

reg query "%REG_HKCU_RUN%" >nul 2>&1
if !errorlevel! equ 0 (
    set "HKCU_STARTUP=0"
    echo Backing up HKCU Startup registry key
    reg export "%REG_HKCU_RUN%" "%TARGET_FOLDER%\HKCURunBackup.reg" /y >> "%LOG_FILE%" 2>&1
    if !errorlevel! neq 0 (
        set "HKCU_BACKUP_SUCCESS=0"
        echo Failed to backup: %REG_HKCU_RUN%
        echo Skipping deletion for this key
        echo.
    )
)

reg query "%REG_HKLM_RUN%" >nul 2>&1
if !errorlevel! equ 0 (
    set "HKLM_STARTUP=0"
    echo Backing up HKLM Startup registry key
    reg export "%REG_HKLM_RUN%" "%TARGET_FOLDER%\HKLMRunBackup.reg" /y >> "%LOG_FILE%" 2>&1
    if !errorlevel! neq 0 (
        set "HKLM_BACKUP_SUCCESS=0"
        echo Failed to backup: %REG_HKLM_RUN%
        echo Skipping deletion for this key
        echo.
    )
)

if exist "%START_MENU_DIR%\*.lnk" (
    echo Moving and Backing up current user's Startup shortcuts
    robocopy "%START_MENU_DIR%" "%TARGET_FOLDER%\CurrentUser" "*.lnk" /MOV /R:0 /W:0 >> "%LOG_FILE%" 2>&1
    if !errorlevel! geq 8 (
        echo Failed to backup: %START_MENU_DIR%
        echo Skipping shortcut movement
        echo.
    )
)

if exist "%ALL_START_MENU_DIR%\*.lnk" (
    echo Moving and Backing up all users Startup shortcuts
    robocopy "%ALL_START_MENU_DIR%" "%TARGET_FOLDER%\AllUsers" "*.lnk" /MOV /R:0 /W:0 >> "%LOG_FILE%" 2>&1
    if !errorlevel! geq 8 (
        echo Failed to backup: %ALL_START_MENU_DIR%
        echo Skipping shortcut movement
        echo.
    )
)

if "!HKCU_STARTUP!"=="0" if "!HKCU_BACKUP_SUCCESS!"=="1" (
    echo Clearing HKCU Startup registry key
    reg delete "%REG_HKCU_RUN%" /f >> "%LOG_FILE%" 2>&1
    reg add "%REG_HKCU_RUN%" /f >> "%LOG_FILE%" 2>&1
)

if "!HKLM_STARTUP!"=="0" if "!HKLM_BACKUP_SUCCESS!"=="1" (
    echo Clearing HKLM Startup registry key
    reg delete "%REG_HKLM_RUN%" /f >> "%LOG_FILE%" 2>&1
    reg add "%REG_HKLM_RUN%" /f >> "%LOG_FILE%" 2>&1
)

echo Backup files saved in: %TARGET_FOLDER%
call "%F%" LOG & goto PERFORMANCE_MENU

:REV_BOOT_TWEAKS
call "%F%" PATH_DIR "Performance" "DefaultBootSettings"

set "TARGET_FOLDER=%MKDIR_DIR%\StartupBackup"

set "START_MENU_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "ALL_START_MENU_DIR=%PROGRAMDATA%\Microsoft\Windows\Start Menu\Programs\Startup"

set "BACKUP_USER=%TARGET_FOLDER%\CurrentUser"
set "BACKUP_ALL=%TARGET_FOLDER%\AllUsers"

set "HKCU_RUN_BACKUP=%TARGET_FOLDER%\HKCURunBackup.reg"
set "HKLM_RUN_BACKUP=%TARGET_FOLDER%\HKLMRunBackup.reg"

echo. & echo Import default Boot up registry settings
reg import "Files\Performance\DefaultBootSettings.reg" >> "%LOG_FILE%" 2>&1

set "HAS_BACKUP=0"
for %%F in (
    "%BACKUP_USER%\*.lnk"
    "%BACKUP_ALL%\*.lnk"
    "%HKCU_RUN_BACKUP%"
    "%HKLM_RUN_BACKUP%"
) do (
    if exist "%%~F" set "HAS_BACKUP=1"
)

if "!HAS_BACKUP!"=="0" (
    echo No backup files found to restore
    call "%F%" LOG & goto PERFORMANCE_MENU
)

echo. & call "%F%" CHOICE "WARNING: Restoring previous startup settings is NOT recommended. Press (N) if you are unsure"
if errorlevel 2 goto PERFORMANCE_MENU

if exist "%BACKUP_USER%\*.lnk" (
    echo Restoring current user's Startup folder
    robocopy "%BACKUP_USER%" "%START_MENU_DIR%" "*.lnk" /MOV /R:0 /W:0 >> "%LOG_FILE%" 2>&1
)

if exist "%BACKUP_ALL%\*.lnk" (
    echo Restoring all users Startup folder
    robocopy "%BACKUP_ALL%" "%ALL_START_MENU_DIR%" "*.lnk" /MOV /R:0 /W:0 >> "%LOG_FILE%" 2>&1
)

if exist "%HKCU_RUN_BACKUP%" (
    echo Restoring HKCU Startup registry keys
    reg import "%HKCU_RUN_BACKUP%" >> "%LOG_FILE%" 2>&1
)

if exist "%HKLM_RUN_BACKUP%" (
    echo Restoring HKLM Startup registry keys
    reg import "%HKLM_RUN_BACKUP%" >> "%LOG_FILE%" 2>&1
)

echo. & call "%F%" CHOICE "Do you want to delete existing backup folder"
if !errorlevel! equ 1 (
    echo deleting: %TARGET_FOLDER%
    rd /s /q "%TARGET_FOLDER%" >> "%LOG_FILE%" 2>&1
)

call "%F%" LOG & goto PERFORMANCE_MENU

:CLEAN_UP
cls
call :RUNNING_BROWSERS
call :CLEAN_BROWSER
call :GO & goto PERFORMANCE_MENU

:POWER_PLAN_MENU
cls & echo. & echo.
echo                        ------------------------------- Power Plan --------------------------------
echo.
echo                           [1] Ultimate Performance                          [2] High Performance
echo.
echo                           [3] Balanced                                      [4] Power Saver
echo.
echo                           [5] Active Plan                                   [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" (
    set ROUTINE=ADD_ULTIMATE_PLAN
    set REV_ROUTINE=REMOVE_ULTIMATE_PLAN
    set APPLY=Add Ultimate Performance plan
    set REVERT=Remove Ultimate Performance plan
    set MENU=POWER_PLAN_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="2" call :SET_POWER_PLAN "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" "high performance"  & goto POWER_PLAN_MENU
if "%choice%"=="3" call :SET_POWER_PLAN "381b4222-f694-41f0-9685-ff5bb260df2e" "balanced"          & goto POWER_PLAN_MENU
if "%choice%"=="4" call :SET_POWER_PLAN "a1841308-3541-4fab-bc81-f71556f20b4a" "power saver"       & goto POWER_PLAN_MENU
if "%choice%"=="5" goto ACTIVE_PLAN
if "%choice%"=="0" goto PERFORMANCE_MENU

call :INVALID "(0-5)" & goto POWER_PLAN_MENU

:ADD_ULTIMATE_PLAN
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\AddUltimatePerformance.ps1"
call :GO & goto POWER_PLAN_MENU

:REMOVE_ULTIMATE_PLAN
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\RemoveUltimatePerformance.ps1"
call :GO & goto POWER_PLAN_MENU

:ACTIVE_PLAN
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\ActivePlan.ps1"
call :GO & goto POWER_PLAN_MENU

:HW_INFO_MENU
cls & echo. & echo.
echo                        --------------------------------- HW Info ---------------------------------
echo.
echo                           [1] CPU                                                    [2] GPU
echo.
echo                           [3] Hard Disk                                              [4] RAM
echo. 
echo                           [5] Motherboard                                            [6] Battery
echo.
echo                                                         [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" (call :INFO_SCRIPT "Performance" "CPUInfo"          & goto HW_INFO_MENU)
if "%choice%"=="2" (call :INFO_SCRIPT "Performance" "GPUInfo"          & goto HW_INFO_MENU)
if "%choice%"=="3" (call :INFO_SCRIPT "Performance" "HardDiskInfo"     & goto HW_INFO_MENU)
if "%choice%"=="4" (call :INFO_SCRIPT "Performance" "MemoryInfo"       & goto HW_INFO_MENU)
if "%choice%"=="5" (call :INFO_SCRIPT "Performance" "MotherboardInfo"  & goto HW_INFO_MENU)
if "%choice%"=="6" goto BATTERY_INFO
if "%choice%"=="0" goto PERFORMANCE_MENU

call :INVALID "(0-6)" & goto HW_INFO_MENU

:BATTERY_INFO
call :MKDIR_PROMPT "%PROGRAMDATA%\WinTweaks\Performance"
set "BATTERY_REPORT=%MKDIR_DIR%\BatteryReport.html"

cls & echo Creating battery report
powercfg /batteryreport /output "%BATTERY_REPORT%"
if %errorlevel% equ 0 (
    start "" "%BATTERY_REPORT%"
) else (
    echo Failed to create battery report
)

call :GO & goto HW_INFO_MENU

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
    call :SUB_MENU
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
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="6" (
    set ROUTINE=REMOVE_POLICIES
    set REV_ROUTINE=REV_REMOVE_POLICIES
    set APPLY=Remove all policies setting
    set REVERT=Restore all policies setting
    set MENU=PRIVACY_SECURITY_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="7" (call :INFO_SCRIPT "Security" "SecurityInfo"  & goto PRIVACY_SECURITY_MENU)
if "%choice%"=="0" goto MAIN_MENU

call :INVALID "(0-7)" & goto PRIVACY_SECURITY_MENU

:DISABLE_TELEMETRY
call :PATH_DIR "Security" "DisableTelemetry"
call :CREATE_FILE "Security" "HostsOriginal"
if errorlevel 1 goto PRIVACY_SECURITY_MENU

set "HOSTS_PATH=%SYSTEMROOT%\System32\drivers\etc\hosts"

echo. & echo Disabling Windows telemetry via registry
reg import "Files\Security\DisableTelemetry.reg" >> "%LOG_FILE%" 2>&1

echo Disabling Windows telemetry services
for %%S in ("DiagTrack" "dmwappushsvc" "WerSvc") do call :SC_CONFIGURE "%%S" "disabled" >> "%LOG_FILE%" 2>&1

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
call :LOG & goto PRIVACY_SECURITY_MENU

:REV_DISABLE_TELEMETRY
call :PATH_DIR "Security" "DefaultTelemetry"

set "HOSTS_PATH=%SYSTEMROOT%\System32\drivers\etc\hosts"
set "TEMP_FILE=%TEMP%\HostsClean.txt"

echo. & echo Restoring default telemetry registry settings
reg import "Files\Security\DefaultTelemetry.reg" >> "%LOG_FILE%" 2>&1

echo Setting telemetry services to manual startup
for %%S in ("DiagTrack" "dmwappushsvc" "WerSvc") do call :SC_CONFIGURE "%%S" "demand" >> "%LOG_FILE%" 2>&1

echo Removing telemetry and trash domain entries from the Hosts file
findstr /V /L /G:"Files\Security\TrackingDomains.txt" "%HOSTS_PATH%" > "%TEMP_FILE%"
copy /y "%TEMP_FILE%" "%HOSTS_PATH%" >> "%LOG_FILE%" 2>&1
del "%TEMP_FILE%" >nul 2>&1

echo Flushing DNS cache
ipconfig /flushdns >> "%LOG_FILE%" 2>&1
call :LOG & goto PRIVACY_SECURITY_MENU

:PRIVACY_CLEANUP
call :CONFIRM "WARNING: This will PERMANENTLY DELETE browser data, logs, and privacy-related information"
if errorlevel 2 goto PRIVACY_SECURITY_MENU


echo.
call :RUNNING_BROWSERS

if "!BROWSERS_OPEN!"=="1" (
    echo Closing open browsers
    for %%B in (%BROWSERS%) do (
        taskkill /IM "%%B" /F /T >nul 2>&1
    )
    timeout /t 2 >nul
)

call :DELETE_FOLDERS "Cleaning Google Chrome data" "%LOCALAPPDATA%\Google\Chrome\User Data"
call :DELETE_FOLDERS "Cleaning Brave data" "%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data"
call :DELETE_FOLDERS "Cleaning Microsoft Edge data" "%LOCALAPPDATA%\Microsoft\Edge\User Data"
call :DELETE_FOLDERS "Cleaning Firefox roaming user data" "%APPDATA%\Mozilla\Firefox"
call :DELETE_FOLDERS "Cleaning Firefox local user data" "%LOCALAPPDATA%\Mozilla\Firefox"

echo Cleaning registry entries
reg import "Files\Security\PrivacyCleanup.reg" >nul 2>&1

echo Cleaning system log files
for %%F in ("%SYSTEMROOT%\Logs" "%SYSTEMROOT%\System32\LogFiles") do (
    if exist "%%~F" (
        "Files\Security\PowerRun.exe" /TI /SW:0 cmd.exe /c "del /f /q "%%~F\*""
            for /d %%D in ("%%~F\*") do (
            "Files\Security\PowerRun.exe" /TI /SW:0 cmd.exe /c "rd /s /q "%%~D""
        )
    )
)

echo Cleaning Windows Event Logs
for %%L in ("Application" "Security" "System" "Setup") do wevtutil clear-log %%L >nul 2>&1

echo Clearing clipboard content
echo. | clip >nul

echo Flushing DNS cache
ipconfig /flushdns >nul 2>&1

call :CLEANING_FUNCTION
call :GO & goto PRIVACY_SECURITY_MENU

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

call :INVALID "(0-3)" & goto WINDOWS_UPDATES_MENU

:DISABLE_UPDATES
call :PATH_DIR "Security" "DisableUpdates"

echo. & echo Disabling Windows Updates via registry
reg import "Files\Security\DisableUpdates.reg" >> "%LOG_FILE%" 2>&1

echo Disabling Windows Update services
for %%S in ("BITS" "UsoSvc" "wuauserv") do call :SC_CONFIGURE "%%S" "disabled" >> "%LOG_FILE%" 2>&1

echo Stopping Windows Update services
for %%S in ("BITS" "UsoSvc" "wuauserv") do call :NET_CONTROL "%%S" "stop" >> "%LOG_FILE%" 2>&1

call :DELETE_FOLDERS "Deleting SoftwareDistribution folder" "%SYSTEMROOT%\SoftwareDistribution" "%LOG_FILE%"
call :DELETE_FILES "Deleting Windows Update log file" "%SYSTEMROOT%\WindowsUpdate.log" "%LOG_FILE%"
call :LOG & goto WINDOWS_UPDATES_MENU

:ENABLE_UPDATES
call :PATH_DIR "Security" "DefaultUpdates"
echo. & echo Restoring default Windows Update registry settings
reg import "Files\Security\DefaultUpdates.reg" >> "%LOG_FILE%" 2>&1

echo Setting Windows Update services to default startup
call :SC_CONFIGURE "UsoSvc" "delayed-auto" >> "%LOG_FILE%" 2>&1
for %%S in ("BITS" "wuauserv") do call :SC_CONFIGURE "%%S" "demand" >> "%LOG_FILE%" 2>&1

call :LOG & goto WINDOWS_UPDATES_MENU

:RESET_UPDATES
call :CONFIRM "WARNING: This will purge all Windows Update data and reset security policies"
if errorlevel 2 goto WINDOWS_UPDATES_MENU

call :PATH_DIR "Security" "ResetUpdates"
echo. & echo Resetting Windows Update registry keys to default
reg import "Files\Security\ResetUpdates.reg" >> "%LOG_FILE%" 2>&1

echo Stopping Windows Update services
for %%S in ("BITS" "CryptSvc" "DoSvc" "UsoSvc" "WaaSMedicSvc" "wuauserv" "WinHttpAutoProxySvc") do call :NET_CONTROL "%%S" "stop" >> "%LOG_FILE%" 2>&1
call :DELETE_FOLDERS "Deleting SoftwareDistribution folder" "%SYSTEMROOT%\SoftwareDistribution" "%LOG_FILE%"
call :DELETE_FOLDERS "Deleting Catroot2 folder" "%SYSTEMROOT%\System32\catroot2" "%LOG_FILE%"
call :DELETE_FILES "Clearing BITS queue manager data files" "%ALLUSERSPROFILE%\Microsoft\Network\Downloader\qmgr*.dat" "%LOG_FILE%"
call :DELETE_FILES "Deleting Windows Update log file" "%SYSTEMROOT%\WindowsUpdate.log" "%LOG_FILE%"

echo Resetting security descriptors for BITS and wuauserv services
sc sdset bits D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU) >> "%LOG_FILE%" 2>&1
sc sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU) >> "%LOG_FILE%" 2>&1

echo Re-registering critical system libraries
for %%D in (atl.dll urlmon.dll mshtml.dll shdocvw.dll browseui.dll jscript.dll vbscript.dll scrrun.dll msxml.dll msxml3.dll msxml6.dll actxprxy.dll softpub.dll wintrust.dll dssenh.dll rsaenh.dll gpkcsp.dll sccbase.dll slbcsp.dll cryptdlg.dll oleaut32.dll ole32.dll shell32.dll initpki.dll wuapi.dll wuaueng.dll wups.dll wups2.dll qmgr.dll qmgrprxy.dll wucltux.dll muweb.dll) do (
    regsvr32 /s "%windir%\System32\%%D" >> "%LOG_FILE%" 2>&1
)

echo Applying default security policy baseline
secedit /configure /cfg "%SYSTEMROOT%\inf\defltbase.inf" /db "%TEMP%\defltbase.sdb" /verbose >> "%LOG_FILE%" 2>&1

echo Clearing all BITS download jobs
bitsadmin /reset /allusers >> "%LOG_FILE%" 2>&1

echo Setting Windows Update services to default startup
call :SC_CONFIGURE "CryptSvc" "auto"
for %%S in ("UsoSvc" "DoSvc") do call :SC_CONFIGURE "%%S" "delayed-auto" >> "%LOG_FILE%" 2>&1
for %%S in ("BITS" "WaaSMedicSvc" "wuauserv" "WinHttpAutoProxySvc") do call :SC_CONFIGURE "%%S" "demand" >> "%LOG_FILE%" 2>&1

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

call :RESTART 
call :LOG & goto WINDOWS_UPDATES_MENU

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

call :INVALID "(0-3)" & goto WINDOWS_DEFENDER_MENU

:DISABLE_DEFENDER
call :CONFIRM "WARNING: This will PERMANENTLY DISABLE Windows Defender real-time protection"
if errorlevel 2 goto WINDOWS_DEFENDER_MENU

echo. & echo Disabling Windows defender via registry
reg import "Files\Security\DisableDefender.reg"

call :RESTART 
call :GO & goto WINDOWS_DEFENDER_MENU

:ENABLE_DEFENDER
echo. & echo Restoring default Windows Defender registry settings
reg import "Files\Security\DefaultDefender.reg"

call :RESTART 
call :GO & goto WINDOWS_DEFENDER_MENU

:REMOVE_DEFENDER
call :CONFIRM "WARNING: This will PERMANENTLY remove Windows Defender core files and services from your system"
if errorlevel 2 goto WINDOWS_DEFENDER_MENU

echo. & echo Removing Windows Defender Security Health UI component
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Security\RemoveSecHealthUI.ps1" >nul

echo Removing Windows Defender entries from the registry
for %%f in ("Files\Security\RemoveDefenderModule\*.reg") do "Files\Security\PowerRun.exe" /TI /SW:0 regedit.exe /s "%%f"

echo Deleting Windows Defender files
"Files\Security\PowerRun.exe" /TI /SW:0 "Files\Security\DefenderFileRemover.bat"

call :RESTART 
call :GO & goto WINDOWS_DEFENDER_MENU

:ENHANCE_SECURITY
call :PATH_DIR "Security" "EnhanceSecurity"
echo. & echo Applying security hardening registry settings
reg import "Files\Security\EnhanceSecurity.reg" >> "%LOG_FILE%" 2>&1

echo Disabling unsafe Windows features
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Security\DisableUnsafeFeature.ps1" >> "%LOG_FILE%" 2>&1

echo Disabling unsafe Windows services
for %%S in ("mrxsmb10" "RemoteRegistry" "SNMP" "SNMPTRAP") do (
    call :NET_CONTROL "%%S" "stop" >> "%LOG_FILE%" 2>&1
    call :SC_CONFIGURE "%%S" "disabled" >> "%LOG_FILE%" 2>&1
)

echo Removing temporary default user account
net user defaultuser0 /delete >> "%LOG_FILE%" 2>&1

call :LOG & goto PRIVACY_SECURITY_MENU

:REV_ENHANCE_SECURITY
echo. & echo Restoring default Windows security registry settings
reg import "Files\Security\DefaultSecurity.reg"

call :GO & goto PRIVACY_SECURITY_MENU

:REMOVE_POLICIES
call :CONFIRM "WARNING: This script will RESET all Group Policy settings to system defaults"
if errorlevel 2 goto PRIVACY_SECURITY_MENU

call :CREATE_FOLDER "Security" "GroupPolicyBackup"
if errorlevel 1 goto PRIVACY_SECURITY_MENU

call :PATH_DIR "Security" "RemoveAllPolicies"

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
call :LOG & goto PRIVACY_SECURITY_MENU

:REV_REMOVE_POLICIES
echo. & call :CHOICE "WARNING: Restoring previous Group Policy settings will overwrite current changes. Press (N) if you are unsure"
if errorlevel 2 goto PRIVACY_SECURITY_MENU

call :PATH_DIR "Security" "RestoreAllPolicies"

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
call :LOG & goto PRIVACY_SECURITY_MENU

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
    echo Restoring default security policy baseline
    secedit /configure /cfg "%SEC_BACKUP%" /db "%TEMP%\defltbase.sdb" /verbose >> "%LOG_FILE%" 2>&1
)

gpupdate /force >nul 2>&1
call :GO & goto PRIVACY_SECURITY_MENU

:NETWORK_MENU
cls & echo. & echo.
echo                        --------------------------------- Network ---------------------------------
echo.
echo                          [1] Network Tweaks                                    [2] Change DNS
echo.
echo                          [3] Wi-Fi Passwords                                   [4] Reset Network
echo.
echo                          [5] Network Info                                      [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" (
    set ROUTINE=NETWORK_TWEAKS
    set REV_ROUTINE=REV_NETWORK_TWEAKS
    set APPLY=Improve Network settings
    set REVERT=Default Network settings
    set MENU=NETWORK_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="2" goto DNS_MENU
if "%choice%"=="3" goto WIFI_PASSWORDS
if "%choice%"=="4" goto NETWORK_RESET
if "%choice%"=="5" (call :INFO_SCRIPT "Network" "NetworkInfo"  & goto NETWORK_MENU)
if "%choice%"=="0" goto MAIN_MENU

call :INVALID "(0-5)" & goto NETWORK_MENU

:NETWORK_TWEAKS
call :PATH_DIR "Network" "NetworkTweaks"
echo. & echo Improve network settings via registry
reg import "Files\Network\NetworkTweaks.reg" >> "%LOG_FILE%" 2>&1

echo Configuring TCP global parameters
for %%P in ("fastopen=enabled" "fastopenfallback=enabled" "rss=enabled" "autotuninglevel=high") do (
    echo  - %%~P
    netsh int tcp set global %%~P >> "%LOG_FILE%" 2>&1
)

echo Setting Cloudflare DNS on all connected interfaces
set DNS_IPv4_1=1.1.1.1
set DNS_IPv4_2=1.0.0.1
set DNS_IPv6_1=2606:4700:4700::1111
set DNS_IPv6_2=2606:4700:4700::1001
call :UPDATE_DNS

call :LOG & goto NETWORK_MENU

:REV_NETWORK_TWEAKS
call :PATH_DIR "Network" "DefaultNetworkSettings"
echo. & echo Restoring default network registry settings
reg import "Files\Network\DefaultNetworkSettings.reg" >> "%LOG_FILE%" 2>&1

echo Resetting TCP global parameters to default
for %%P in ("fastopen=default" "fastopenfallback=default" "rss=default" "autotuninglevel=normal") do (
    echo  - %%~P
    netsh int tcp set global %%~P >> "%LOG_FILE%" 2>&1
)

echo. & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\SetDHCP.ps1"

call :LOG & goto NETWORK_MENU

:DNS_MENU
cls & echo. & echo.
echo                        ------------------------------- DNS Server --------------------------------
echo.
echo                           [1] Google Public                                      [2] Cloudflare
echo.
echo                           [3] Cloudflare Family                                  [4] AdGuard
echo.
echo                           [5] Clean Browsing                                     [6] Quad9
echo.
echo                           [7] OpenDNS                                            [8] Default
echo.
echo                           [9] DNS Server Test                                    [10] DNS Status
echo.
echo                                                         [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" (set "DNS_NAME=Google Public DNS" & set "DNS_IPv4_1=8.8.8.8" & set "DNS_IPv4_2=8.8.4.4" & set "DNS_IPv6_1=2001:4860:4860::8888" & set "DNS_IPv6_2=2001:4860:4860::8844" & goto SET_DNS)
if "%choice%"=="2" (set "DNS_NAME=Cloudflare DNS" & set "DNS_IPv4_1=1.1.1.1" & set "DNS_IPv4_2=1.0.0.1" & set "DNS_IPv6_1=2606:4700:4700::1111" & set "DNS_IPv6_2=2606:4700:4700::1001" & goto SET_DNS)
if "%choice%"=="3" (set "DNS_NAME=Cloudflare Family DNS" & set "DNS_IPv4_1=1.1.1.3" & set "DNS_IPv4_2=1.0.0.3" & set "DNS_IPv6_1=2606:4700:4700::1113" & set "DNS_IPv6_2=2606:4700:4700::1003" & goto SET_DNS)
if "%choice%"=="4" (set "DNS_NAME=AdGuard DNS" & set "DNS_IPv4_1=94.140.14.14" & set "DNS_IPv4_2=94.140.15.15" & set "DNS_IPv6_1=2a10:50c0::ad1:ff" & set "DNS_IPv6_2=2a10:50c0::ad2:ff" & goto SET_DNS)
if "%choice%"=="5" (set "DNS_NAME=Clean Browsing DNS" & set "DNS_IPv4_1=185.228.168.168" & set "DNS_IPv4_2=185.228.169.168" & set "DNS_IPv6_1=2a0d:2a00:1::" & set "DNS_IPv6_2=2a0d:2a00:2::" & goto SET_DNS)
if "%choice%"=="6" (set "DNS_NAME=Quad9 DNS" & set "DNS_IPv4_1=9.9.9.9" & set "DNS_IPv4_2=149.112.112.112" & set "DNS_IPv6_1=2620:fe::fe" & set "DNS_IPv6_2=2620:fe::9" & goto SET_DNS)
if "%choice%"=="7" (set "DNS_NAME=OpenDNS" & set "DNS_IPv4_1=208.67.222.222" & set "DNS_IPv4_2=208.67.220.220" & set "DNS_IPv6_1=2620:119:35::35" & set "DNS_IPv6_2=2620:119:53::53" & goto SET_DNS)
if "%choice%"=="8" goto SET_DHCP
if "%choice%"=="9" goto DNS_SERVER_TEST
if "%choice%"=="10" goto DNS_STATUS
if "%choice%"=="0" goto NETWORK_MENU

call :INVALID "(0-10)" & goto DNS_MENU

:SET_DNS
call :PATH_DIR "Network" "DNS"
echo. & echo Setting %DNS_NAME% server on all connected interfaces
call :UPDATE_DNS

call :LOG & goto DNS_MENU

:SET_DHCP
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\SetDHCP.ps1"
call :GO & goto DNS_MENU

:DNS_SERVER_TEST
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\DNSTest.ps1"
call :GO & goto DNS_MENU

:DNS_STATUS
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\DNSStatus.ps1"
call :GO & goto DNS_MENU

:WIFI_PASSWORDS
call :CREATE_FILE "Network" "WifiPassword.log"
if errorlevel 1 goto NETWORK_MENU

cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\WifiPassword.ps1" "%TARGET_FILE%"
echo. & echo Wifi Password file saved in: %TARGET_FILE%
call :GO & goto NETWORK_MENU

:NETWORK_RESET
call :CONFIRM "WARNING: This script will RESET ALL network configurations"
if errorlevel 2 goto NETWORK_MENU

call :PATH_DIR "Network" "NetworkReset"
echo. & echo Stopping Network Services
for %%S in ("dot3svc" "netman" "WlanSvc" "WwanSvc") do call :NET_CONTROL "%%S" "stop" >> "%LOG_FILE%" 2>&1

echo Resetting Network services to default startup
for %%S in ("Dhcp" "dnscache" "nlasvc" "WlanSvc") do call :SC_CONFIGURE "%%S" "auto" >> "%LOG_FILE%" 2>&1
for %%S in ("dot3svc" "netman" "netprofm" "WwanSvc") do call :SC_CONFIGURE "%%S" "demand" >> "%LOG_FILE%" 2>&1

echo Starting Network Services
for %%S in ("dot3svc" "netman" "WlanSvc" "WwanSvc") do call :NET_CONTROL "%%S" "start" >> "%LOG_FILE%" 2>&1
pause
echo Reset TCP/IP Stack
netsh int ip reset >> "%LOG_FILE%" 2>&1

echo Reset Winsock catalog
netsh winsock reset >> "%LOG_FILE%" 2>&1

echo Reset WinHTTP proxy
netsh winhttp reset proxy >> "%LOG_FILE%" 2>&1

echo Reset IPv6 settings
netsh interface ipv6 reset >> "%LOG_FILE%" 2>&1

echo Reset Port Proxies
netsh interface portproxy reset >> "%LOG_FILE%" 2>&1

echo Reset Firewall Rules
netsh advfirewall reset >> "%LOG_FILE%" 2>&1

echo Resetting BranchCache
netsh branchcache reset >> "%LOG_FILE%" 2>&1

echo Refreshing NetBIOS names
nbtstat -RR >> "%LOG_FILE%" 2>&1

echo Flushing DNS
ipconfig /flushdns >> "%LOG_FILE%" 2>&1

echo Cleaning ARP cache
arp -d * >> "%LOG_FILE%" 2>&1

echo Cleaning IPv6 Neighbor
netsh interface ipv6 delete neighbors >> "%LOG_FILE%" 2>&1

echo Cleaning IPv6 Destination Cache
netsh interface ipv6 delete destinationcache >> "%LOG_FILE%" 2>&1

call :LOG & goto NETWORK_MENU

:PACKAGES_MENU
cls & echo. & echo.
echo                        -------------------------------- Packages ---------------------------------
echo.
echo                         [1] Chocolatey                                        [2] Remove ALL MS Apps
echo.
echo                         [3] Packages Info                                     [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto CHOCO_INITIAL
if "%choice%"=="2" goto REMOVE_MS
if "%choice%"=="3" (call :INFO_SCRIPT "Packages" "ProgramsInfo"  & goto PACKAGES_MENU)
if "%choice%"=="0" goto MAIN_MENU

call :INVALID "(0-3)" & goto PACKAGES_MENU
:CHOCO_INITIAL
call :WHERE_CHOCO
if errorlevel 1 goto PACKAGES_MENU

:: Initialize
set "ON=(YES)"
set "OFF=(NO)"

call :INIT_PACKAGES
call :TOGGLE_ALL OFF

:: Main interface
:CHOCO_MENU
cls
echo.
echo                                                 \\!//
echo                                                 (o o)
echo              -------------------------------oOOo-(_)-oOOo-------------------------------
echo                                       Chocolatey Package Manager
echo              ---------------------------------------------------------------------------
echo.
call :RENDER_COLUMNS

echo.
echo    [U] Update Packages
echo    [R] Remove Packages
echo    [M] More
echo.
echo              ---------------------------------------------------------------------------
echo.
echo                    [A] Select All            [D] Deselect All            [0] Back
echo.

echo Tip: You can select multiple items, e.g. 1,3,5 or 1-5 or 1-3,7,10-12
set "choice=" & set /p "choice=--> Select option(s) and press [S] to Start: "

if "%choice%"=="" goto CHOCO_MENU
if "%choice%"=="0" goto PACKAGES_MENU
if /i "%choice%"=="S" goto RUN_PACKAGES
if /i "%choice%"=="A" (call :TOGGLE_ALL ON & goto CHOCO_MENU)
if /i "%choice%"=="D" (call :TOGGLE_ALL OFF & goto CHOCO_MENU)
if /i "%choice%"=="U" goto UPDATE_MENU
if /i "%choice%"=="R" goto REMOVE_MENU
if /i "%choice%"=="M" goto MORE_PKG

call :MULTI_INPUT OPT %MAX_PKG%
goto CHOCO_MENU

:RUN_PACKAGES
call :COLLECT_SELECTED toInstall

call :INSTALL_PKG_LIST
if errorlevel 1 (pause & goto CHOCO_MENU)

call :GO & call :TOGGLE_ALL OFF & goto CHOCO_MENU

:UPDATE_MENU
call :LIST_MENU "update" "Checking for available updates" "outdated" "upgrade"
if errorlevel 2 goto CHOCO_MENU
if errorlevel 1 (pause & goto CHOCO_MENU)
call :GO & goto CHOCO_MENU

:REMOVE_MENU
call :LIST_MENU "remove" "Installed packages" "list" "uninstall"
if errorlevel 2 goto CHOCO_MENU
if errorlevel 1 (pause & goto CHOCO_MENU)
call :GO & goto CHOCO_MENU

:MORE_PKG
cls
echo Enter package name(s) separated by spaces
echo Type 0 to go back

set "choice=" & set /p "choice=--> "
if "%choice%"=="" goto MORE_PKG
if "%choice%"=="0" goto CHOCO_MENU

for %%A in (%choice%) do call :PROCESS_PKG "%%A"
call :GO & goto CHOCO_MENU

:REMOVE_MS
call :CONFIRM "WARNING: This will remove ALL Microsoft Store apps"
if errorlevel 2 goto PACKAGES_MENU

powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Packages\Remove_All_MS.ps1"
call :GO & goto PACKAGES_MENU

:CUSTOMIZATION_MENU
cls & echo. & echo.
echo                        ------------------------------ Customization ------------------------------
echo.
echo                           [1] File Explorer                                    [2] Theme
echo.
echo                           [3] Notification                                     [4] Shortcut Arrow
echo.
echo                           [5] Num Lock                                         [6] UTC Time
echo.
echo                           [7] Power Settings                                   [8] Trash Options 
echo.
echo                           [9] Classic Photo Viewer                             [10] Context Menu
echo.
echo                                                          [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto FILE_EXPLORER_MENU
if "%choice%"=="2" (
    set ROUTINE=DARK_MODE
    set REV_ROUTINE=LIGHT_MODE
    set APPLY=Activate dark mode
    set REVERT=Activate light mode
    set MENU=CUSTOMIZATION_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="3" (
    set ROUTINE=DIS_NOTIFICATION
    set REV_ROUTINE=ENA_NOTIFICATION
    set APPLY=Disable notification center
    set REVERT=Enable notification center
    set MENU=CUSTOMIZATION_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="4" (
    set ROUTINE=HIDE_SHORTCUT_ARROW
    set REV_ROUTINE=SHOW_SHORTCUT_ARROW
    set APPLY=Remove shortcut arrow
    set REVERT=Show shortcut arrow
    set MENU=CUSTOMIZATION_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="5" (
    set ROUTINE=NUM_LOCK_OFF
    set REV_ROUTINE=NUM_LOCK_ON
    set APPLY=Disable num lock when logging in
    set REVERT=Enable num lock when logging in
    set MENU=CUSTOMIZATION_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="6" (
    set ROUTINE=UTC
    set REV_ROUTINE=LOCAL_TIME
    set APPLY=Setting hardware clock to UTC
    set REVERT=Setting hardware clock to Local Time
    set MENU=CUSTOMIZATION_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="7" (
    set ROUTINE=POWER_SETTINGS
    set REV_ROUTINE=REMOVE_POWER_SETTINGS
    set APPLY=Creating 'Powerful settings' folder on your Desktop
    set REVERT=Removing 'Powerful settings' folder from your Desktop
    set MENU=CUSTOMIZATION_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="8" (
    set ROUTINE=TRASH
    set REV_ROUTINE=DEF_TRASH
    set APPLY=Disable unnecessary Windows features
    set REVERT=Default unnecessary Windows features
    set MENU=CUSTOMIZATION_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="9" (
    set ROUTINE=PHOTO_VIEWER
    set REV_ROUTINE=REMOVE_PHOTO_VIEWER
    set APPLY=Restore classic Windows photo viewer
    set REVERT=Remove classic Windows photo viewer
    set MENU=CUSTOMIZATION_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="10" goto CONTEXT_MENU
if "%choice%"=="0" goto MAIN_MENU

call :INVALID "(0-10)" & goto CUSTOMIZATION_MENU

:FILE_EXPLORER_MENU
cls & echo. & echo.
echo                        ------------------------------ File Explorer ------------------------------
echo.
echo                          [1] File Extensions                                  [2] Hidden Files
echo.
echo                          [3] Recent Files                                     [4] Open On This PC
echo.
echo                                                         [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" (
    set ROUTINE=SHOW_EXTENSIONS
    set REV_ROUTINE=HIDE_EXTENSIONS
    set APPLY=Show files extensions
    set REVERT=Hide file extensions
    set MENU=FILE_EXPLORER_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="2" (
    set ROUTINE=SHOW_HIDDEN
    set REV_ROUTINE=DIS_HIDDEN
    set APPLY=Show hidden files
    set REVERT=Hide hidden files
    set MENU=FILE_EXPLORER_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="3" (
    set ROUTINE=HIDE_RECENT
    set REV_ROUTINE=SHOW_RECENT
    set APPLY=Hide recent files
    set REVERT=Show recent files
    set MENU=FILE_EXPLORER_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="4" (
    set ROUTINE=ON_THIS_PC
    set REV_ROUTINE=ON_QUICK_ACCESS
    set APPLY=Open file explorer on: This PC
    set REVERT=Open file explorer on: Quick Access
    set MENU=FILE_EXPLORER_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="0" goto CUSTOMIZATION_MENU

call :INVALID "(0-4)" & goto FILE_EXPLORER_MENU

:SHOW_EXTENSIONS
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f >nul 2>&1
call :GO & goto FILE_EXPLORER_MENU

:HIDE_EXTENSIONS
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 1 /f >nul 2>&1
call :GO & goto FILE_EXPLORER_MENU

:SHOW_HIDDEN
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSuperHidden /t REG_DWORD /d 1 /f >nul 2>&1
call :GO & goto FILE_EXPLORER_MENU

:DIS_HIDDEN
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSuperHidden /t REG_DWORD /d 0 /f >nul 2>&1
call :GO & goto FILE_EXPLORER_MENU

:HIDE_RECENT
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowRecent /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackDocs /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackProgs /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "ShowFrequent" /t REG_DWORD /d 0 /f >nul 2>&1
goto ON_THIS_PC

:SHOW_RECENT
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowRecent /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackDocs /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackProgs /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "ShowFrequent" /t REG_DWORD /d 1 /f >nul 2>&1
goto ON_QUICK_ACCESS

:ON_THIS_PC
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 1 /f >nul 2>&1
call :GO & goto FILE_EXPLORER_MENU

:ON_QUICK_ACCESS
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 2 /f >nul 2>&1
call :GO & goto FILE_EXPLORER_MENU

:DARK_MODE
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f >nul 2>&1
call :GO & goto CUSTOMIZATION_MENU

:LIGHT_MODE
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f >nul 2>&1
call :GO & goto CUSTOMIZATION_MENU

:DIS_NOTIFICATION
echo. & echo Disabling notification services
for %%S in ("WpnService" "WpnUserService") do call :SC_CONFIGURE "%%S" "disabled" >nul 2>&1

echo Disabling notification via registry
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v DisableNotificationCenter /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 0 /f >nul 2>&1
call :GO & goto CUSTOMIZATION_MENU

:ENA_NOTIFICATION
echo. & echo Enabling notification services
for %%S in ("WpnService" "WpnUserService") do call :SC_CONFIGURE "%%S" "auto" >nul 2>&1

echo Enabling notification via registry
reg delete "HKLM\Software\Policies\Microsoft\Windows\Explorer" /v DisableNotificationCenter /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 1 /f >nul 2>&1
call :GO & goto CUSTOMIZATION_MENU

:HIDE_SHORTCUT_ARROW
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons" /v 29 /t REG_EXPAND_SZ /d "%SystemRoot%\System32\imageres.dll,197" /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v link /t REG_BINARY /d 00000000 /f >nul 2>&1
call :GO & goto CUSTOMIZATION_MENU

:SHOW_SHORTCUT_ARROW
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons" /v 29 /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v link /f >nul 2>&1
call :GO & goto CUSTOMIZATION_MENU

:NUM_LOCK_OFF
reg add "HKCU\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 0 /f >nul 2>&1
reg add "HKU\.DEFAULT\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 2147483648 /f >nul 2>&1
call :GO & goto CUSTOMIZATION_MENU

:NUM_LOCK_ON
reg add "HKCU\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 2 /f >nul 2>&1
reg add "HKU\.DEFAULT\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 2147483650 /f >nul 2>&1
call :GO & goto CUSTOMIZATION_MENU

:UTC
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f >nul 2>&1
call :GO & goto CUSTOMIZATION_MENU

:LOCAL_TIME
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /f >nul 2>&1
call :GO & goto CUSTOMIZATION_MENU

:POWER_SETTINGS
call :MKDIR_PROMPT "%USERPROFILE%\Desktop\Powerful Settings.{ED7BA470-8E54-465E-825C-99712043E01C}"
call :GO & goto CUSTOMIZATION_MENU

:REMOVE_POWER_SETTINGS
rd /s /q "%USERPROFILE%\Desktop\Powerful Settings.{ED7BA470-8E54-465E-825C-99712043E01C}" >nul 2>&1
call :GO & goto CUSTOMIZATION_MENU

:TRASH
reg import "Files\Customization\DisableTrash.reg" >nul 2>&1
reg import "Files\Security\DisableTelemetry.reg" >nul 2>&1
call :GO & goto CUSTOMIZATION_MENU

:DEF_TRASH
reg import "Files\Customization\DefaultTrash.reg" >nul 2>&1
reg import "Files\Security\DefaultTelemetry.reg" >nul 2>&1
call :GO & goto CUSTOMIZATION_MENU

:PHOTO_VIEWER
reg import "Files\Customization\RestoreClassicPhotoViewer.reg" >nul 2>&1
call :GO & goto CUSTOMIZATION_MENU

:REMOVE_PHOTO_VIEWER
reg import "Files\Customization\RemoveClassicPhotoViewer.reg" >nul 2>&1
call :GO & goto CUSTOMIZATION_MENU

:CONTEXT_MENU
cls & echo. & echo.
echo                        ------------------------------- Context Menu ------------------------------
echo.
echo                          [1] Command Prompt                                 [2] Command Prompt As Admin
echo.
echo                          [3] Restart Explorer                               [4] Kill Frozen
echo.
echo                                                          [0] Back
echo.    
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" (
    set ROUTINE=CMD_CONTEXT
    set REV_ROUTINE=REV_CMD_CONTEXT
    set APPLY=Add "Open CMD Here" options to context menu
    set REVERT=Remove option
    set MENU=CONTEXT_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="2" (
    set ROUTINE=CMD_CONTEXT_ADMIN
    set REV_ROUTINE=REV_CMD_CONTEXT_ADMIN
    set APPLY=Add "Open CMD Here (Admin)" options to context menu
    set REVERT=Remove option
    set MENU=CONTEXT_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="3" (
    set ROUTINE=RESTART_EXPLORER
    set REV_ROUTINE=REV_RESTART_EXPLORER
    set APPLY=Add "Restart Explorer" option to context menu
    set REVERT=Remove option
    set MENU=CONTEXT_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="4" (
    set ROUTINE=KILL_FROZEN
    set REV_ROUTINE=REV_KILL_FROZEN
    set APPLY=Add "Kill frozen process" option to context menu
    set REVERT=Remove option
    set MENU=CONTEXT_MENU
    call :SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="0" goto CUSTOMIZATION_MENU

call :INVALID "(0-4)" & goto CONTEXT_MENU

:CMD_CONTEXT
reg add "HKCU\Software\Classes\Directory\shell\OpenCmdHere" /ve /d "Open CMD Here" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\shell\OpenCmdHere" /v "Icon" /d "cmd.exe" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\shell\OpenCmdHere\command" /ve /d "cmd.exe /k pushd \"%%1\"" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHere" /ve /d "Open CMD Here" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHere" /v "Icon" /d "cmd.exe" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHere\command" /ve /d "cmd.exe /k pushd \"%%V\"" /f >nul 2>&1
call :GO & goto CONTEXT_MENU

:REV_CMD_CONTEXT
reg delete "HKCU\Software\Classes\Directory\shell\OpenCmdHere" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHere" /f >nul 2>&1
call :GO & goto CONTEXT_MENU

:CMD_CONTEXT_ADMIN
reg add "HKCU\Software\Classes\Directory\shell\OpenCmdHereAdmin" /ve /d "Open CMD Here (Admin)" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\shell\OpenCmdHereAdmin" /v "HasLUAShield" /t REG_SZ /d "" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\shell\OpenCmdHereAdmin" /v "Icon" /d "cmd.exe,0" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\shell\OpenCmdHereAdmin\command" /ve /d "powershell -Command \"Start-Process cmd -ArgumentList '/s','/k','pushd %%1' -Verb RunAs\"" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHereAdmin" /ve /d "Open CMD Here (Admin)" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHereAdmin" /v "HasLUAShield" /t REG_SZ /d "" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHereAdmin" /v "Icon" /d "cmd.exe" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHereAdmin\command" /ve /d "powershell -Command \"Start-Process cmd -ArgumentList '/s','/k','pushd %%V' -Verb RunAs\"" /f >nul 2>&1
call :GO & goto CONTEXT_MENU

:REV_CMD_CONTEXT_ADMIN
reg delete "HKCU\Software\Classes\Directory\shell\OpenCmdHereAdmin" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHereAdmin" /f >nul 2>&1
call :GO & goto CONTEXT_MENU

:RESTART_EXPLORER
reg add "HKCU\Software\Classes\DesktopBackground\Shell\RestartExplorer" /ve /d "Restart Explorer" /f >nul 2>&1
reg add "HKCU\Software\Classes\DesktopBackground\Shell\RestartExplorer" /v "Icon" /d "explorer.exe,0" /f >nul 2>&1
reg add "HKCU\Software\Classes\DesktopBackground\Shell\RestartExplorer\command" /ve /d "cmd.exe /c taskkill /F /IM explorer.exe >nul 2>&1 & start explorer.exe" /f >nul 2>&1
call :GO & goto CONTEXT_MENU

:REV_RESTART_EXPLORER
reg delete "HKCU\Software\Classes\DesktopBackground\Shell\RestartExplorer" /f >nul 2>&1
call :GO & goto CONTEXT_MENU

:KILL_FROZEN
reg add "HKCU\Software\Classes\DesktopBackground\Shell\KillNotResponding" /v "MUIVerb" /d "Kill frozen process" /f >nul 2>&1
reg add "HKCU\Software\Classes\DesktopBackground\Shell\KillNotResponding" /v "Icon" /d "taskmgr.exe,0" /f >nul 2>&1
reg add "HKCU\Software\Classes\DesktopBackground\Shell\KillNotResponding\Command" /ve /d "cmd.exe /C taskkill.exe /F /FI \"status eq NOT RESPONDING\"" /f >nul 2>&1
call :GO & goto CONTEXT_MENU

:REV_KILL_FROZEN
reg delete "HKCU\Software\Classes\DesktopBackground\Shell\KillNotResponding" /f >nul 2>&1
call :GO & goto CONTEXT_MENU

:SYSTEM_MENU
cls & echo. & echo.
echo                        --------------------------------- System ----------------------------------
echo.
echo                          [1] Restore Point                                   [2] Registry Backup
echo.
echo                          [3] Activation                                      [4] System Info
echo.
echo                                                         [0] Back
echo.  
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto RESTORE_POINT
if "%choice%"=="2" goto REG_BACK
if "%choice%"=="3" goto ACTIVATION_MENU
if "%choice%"=="4" (call :INFO_SCRIPT "System" "SystemInfo"  & goto SYSTEM_MENU)
if "%choice%"=="0" goto MAIN_MENU

call :INVALID "(0-4)" & goto SYSTEM_MENU

:RESTORE_POINT
cls & echo Creating a System Restore Point
powershell -Command "Checkpoint-Computer -Description 'WinTweaks Restore Point' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop"
if %errorlevel% equ 0 (call :GO & goto SYSTEM_MENU)

call :PATH_DIR "System" "RestorePoint"
echo Creating a restore point failed. Attempting to fix system dependencies
echo Enable System Restore on the C: drive
powershell -Command "Enable-ComputerRestore -Drive 'C:\'" >> "%LOG_FILE%" 2>&1
echo. & echo Enabling System Restore via registry
reg import "Files\System\EnableRestorePoint.reg" >> "%LOG_FILE%" 2>&1
echo Stopping restore point services
for %%S in ("VSS" "swprv") do call :NET_CONTROL "%%S" "stop" >> "%LOG_FILE%" 2>&1

echo Re-registering VSS-related system libraries
for %%D in (ole32.dll oleaut32.dll vss_ps.dll stdprov.dll vssui.dll) do (
    regsvr32 /s "%windir%\System32\%%D" >> "%LOG_FILE%" 2>&1
)

for %%D in (swprv.dll eventcls.dll) do (
    regsvr32 /s /i "%windir%\System32\%%D" >> "%LOG_FILE%" 2>&1
)

echo Registering VSS Service
vssvc /register  >> "%LOG_FILE%" 2>&1

echo Starting restore point services
for %%S in ("VSS" "swprv") do (
    call :SC_CONFIGURE "%%S" "demand" >> "%LOG_FILE%" 2>&1
    call :NET_CONTROL "%%S" "start" >> "%LOG_FILE%" 2>&1
)
for %%S in ("RpcSs" "CryptSvc" "EventLog" "EventSystem" "Schedule") do (
    call :SC_CONFIGURE "%%S" "auto" >> "%LOG_FILE%" 2>&1
    call :NET_CONTROL "%%S" "start" >> "%LOG_FILE%" 2>&1
)

echo Checking VSS Writers status
vssadmin list writers >> "%LOG_FILE%" 2>&1

echo Attempting to create System Restore Point again
powershell -Command "Checkpoint-Computer -Description 'WinTweaks Restore Point' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop" >> "%LOG_FILE%" 2>&1
if %errorlevel% equ 0 (
    echo System Restore Point created successfully
) else (
    echo Creating system restore point has failed after troubleshooting 
)
call :LOG & goto SYSTEM_MENU

:REG_BACK
cls
call :CREATE_FOLDER "System" "FullRegistryBackup"
if errorlevel 1 goto SYSTEM_MENU

call :PATH_DIR "System" "FullRegistryBackup"

set "SUCCESS_COUNT=0"

echo Creating Full Registry Backup
for %%A in (
    "HKLM\SYSTEM,SYSTEM"
    "HKLM\SOFTWARE,SOFTWARE"
    "HKLM\SAM,SAM"
    "HKLM\SECURITY,SECURITY"
    "HKU\.DEFAULT,DEFAULT"
    "HKCU,NTUSER"
    "HKCU\Software\Classes,UsrClass"
) do (
    for /f "tokens=1,2 delims=," %%B in ("%%~A") do (
        echo  Exporting: %%B
        reg save "%%B" "%TARGET_FOLDER%\%%C.hive" /y >>"%LOG_FILE%" 2>&1      
        if !errorlevel! equ 0 set /a SUCCESS_COUNT+=1
    )
)

if exist "%TARGET_FOLDER%\*.hive" (
    echo. & echo Backup Process Finished. Total Success: !SUCCESS_COUNT!/7 
    call :CHOICE "Compress folder?"
    if errorlevel 2 (
        echo. & echo Backup saved in: %TARGET_FOLDER%
    ) else (
	    powershell -NoProfile -ExecutionPolicy Bypass -File "Files\System\CompressHiveFiles.ps1" "%TARGET_FOLDER%" "%LOG_FILE%"
    )
) else (
    echo No hive files were created. Backup failed
)
call :LOG & goto SYSTEM_MENU

:ACTIVATION_MENU
cls & echo. & echo.
echo                        -------------------------------- Activation -------------------------------
echo.
echo                          [1] Windows And Office                             [2] Activation Status
echo. 
echo                                                          [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto RUN_ACTIVATION
if "%choice%"=="2" goto CHECK_ACTIVATION
if "%choice%"=="0" goto SYSTEM_MENU

call :INVALID "(0-2)" & goto ACTIVATION_MENU

:RUN_ACTIVATION
cls & echo Launching Microsoft Activation Script (MAS) to activate Windows and Office
echo The script will open in a new window. Follow the on-screen instructions
powershell -NoP -EP Bypass -c "irm https://get.activated.win | iex"
call :GO & goto ACTIVATION_MENU

:CHECK_ACTIVATION
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\System\ActivationStatus.ps1"
call :GO & goto ACTIVATION_MENU

:TOOLS_MENU
cls & echo. & echo.
echo                        ---------------------------------- Tools ----------------------------------
echo.
echo                          [1] SFC Scan                                            [2] DISM Tools
echo.  
echo                          [3] Defragment Drive                                    [4] Check Disk 
echo. 
echo                          [5] Memory Diagnostic                                   [6] Disk Cleanup
echo.
echo                          [7] Delete Script Data                                  [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto SFC_SCAN
if "%choice%"=="2" goto DISM_MENU
if "%choice%"=="3" goto DEFRAG
if "%choice%"=="4" goto CHKDSK
if "%choice%"=="5" goto MEMORY_DIAG
if "%choice%"=="6" goto CLEAN_MGR
if "%choice%"=="7" goto DELETE_SCRIPT_DATA
if "%choice%"=="0" goto MAIN_MENU

call :INVALID "(0-7)" & goto TOOLS_MENU

:SFC_SCAN
cls & echo Running sfc scan
sfc /scannow
call :GO & goto TOOLS_MENU

:DISM_MENU
cls & echo. & echo.
echo                        ------------------------------- DISM Tools --------------------------------
echo.
echo                           [1] Fast Check                                     [2] Deep Check
echo.                    
echo                           [3] Fix Corruption                                 [4] Component Cleanup
echo.
echo                                                         [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: " 
if "%choice%"=="1" goto DISM_CHECK_HEALTH
if "%choice%"=="2" goto DISM_SCAN_HEALTH
if "%choice%"=="3" goto DISM_RESTORE_HEALTH
if "%choice%"=="4" goto DISM_COMPONENT_CLEANUP
if "%choice%"=="0" goto TOOLS_MENU

call :INVALID "(0-4)" & goto DISM_MENU

:DISM_CHECK_HEALTH
cls & echo Performing quick health check of Windows image
dism /Online /Cleanup-Image /CheckHealth
call :GO & goto DISM_MENU

:DISM_SCAN_HEALTH
cls & echo Performing deep scan of Windows image
dism /Online /Cleanup-Image /ScanHealth
call :GO & goto DISM_MENU

:DISM_RESTORE_HEALTH
cls & echo Fix Windows component
dism /Online /Cleanup-Image /RestoreHealth
call :GO & goto DISM_MENU

:DISM_COMPONENT_CLEANUP
call :CONFIRM "WARNING: This will permanently remove rollback capability for Windows Updates"
if errorlevel 2 goto DISM_MENU

echo Cleaning Windows components
dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase
call :GO & goto DISM_MENU

:DEFRAG
start "" dfrgui.exe
goto TOOLS_MENU

:CHKDSK
cls & echo Available drives on your system:
for %%d in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist %%d:\ echo %%d:\
)

echo. & echo Enter drive letter to check
echo Enter "0" to go back

set "drive=" & set /p "drive= "
if "%drive%"=="0" goto TOOLS_MENU
if not defined drive goto CHKDSK
set "drive=%drive:"=%"
set "drive=%drive:~0,1%"
if not exist "%drive%:\" (
    echo. & echo Invalid drive letter: %drive%
    pause
    goto CHKDSK
)
for %%c in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do if /i "%drive%"=="%%c" set "drive=%%c"

:CHKDSK_MENU
cls & echo. & echo.
echo                        --------------------------------- CHKDSK ----------------------------------
echo.
echo                          [1] Check Status                                    [2] Fix File System
echo.
echo                          [3] Fix Bad Sectors                                 [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option for %drive%\: drive: "
if "%choice%"=="1" goto DISK_STATUS 
if "%choice%"=="2" goto FIX_FILE
if "%choice%"=="3" goto FIX_SECTORS
if "%choice%"=="0" goto CHKDSK

call :INVALID "(0-3)" & goto CHKDSK_MENU

:DISK_STATUS
cls & echo Running read-only CHKDSK on drive %drive%:\ to check for errors
timeout /t 2 >nul
chkdsk %drive%:
call :GO & goto CHKDSK_MENU

:FIX_FILE
cls & echo Running CHKDSK with /f option on drive %drive%:\ to fix file system errors
timeout /t 2 >nul
chkdsk %drive%: /f
call :GO & goto CHKDSK_MENU

:FIX_SECTORS
cls & echo Running CHKDSK with /r option on drive %drive%:\ to find bad sectors and recover data
timeout /t 2 >nul
chkdsk %drive%: /r
call :GO & goto CHKDSK_MENU

:MEMORY_DIAG
start "" mdsched.exe
goto TOOLS_MENU

:CLEAN_MGR
cleanmgr.exe /d %SYSTEMDRIVE% /VERYLOWDISK
goto TOOLS_MENU

:DELETE_SCRIPT_DATA
set "MKDIR_DIR=%PROGRAMDATA%\WinTweaks"
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Tools\DeleteScriptData.ps1" "%MKDIR_DIR%"
call :GO & goto TOOLS_MENU

:OTHER_MENU
cls
echo.
echo.
echo                        ---------------------------------- Other ----------------------------------
echo.
echo                           [1] Run Chris Titus Tool                           [2] Run OO Shutup 10
echo.
echo                           [3] Run Internet Speed Test                        [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto CTT
if "%choice%"=="2" goto OO_SHUTUP
if "%choice%"=="3" goto NET_SPEED_TEST
if "%choice%"=="0" goto MAIN_MENU

call :INVALID "(0-3)" & goto OTHER_MENU

:CTT
cls & echo Running Chris Titus tool
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb https://christitus.com/win | iex"
call :GO & goto OTHER_MENU

:OO_SHUTUP
call :MKDIR_PROMPT "%PROGRAMDATA%\WinTweaks\Other\OOSU10"
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Other\DownloadOOShutup.ps1" "%MKDIR_DIR%"
call :GO & goto OTHER_MENU

:NET_SPEED_TEST
call :MKDIR_PROMPT "%PROGRAMDATA%\WinTweaks\Other\speedtest_cli"
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Other\DownloadNetSpeed.ps1" "%MKDIR_DIR%"
call :GO & goto OTHER_MENU



:: -------------------------------------------------------------<FUNCTIONS>-------------------------------------------------------------
:SET_TASKS
for /f "usebackq delims=" %%A in ("%~2") do (
    set "TASK_NAME=%%A"
    set "TASK_ACTION=%~1"

    schtasks /query /tn "!TASK_NAME!" >nul 2>&1
    if !errorlevel! neq 0 (
        echo [NOT FOUND]: !TASK_NAME! >> "%LOG_FILE%"
    ) else (
        schtasks /change /tn "!TASK_NAME!" /!TASK_ACTION! >nul 2>&1
        if !errorlevel! equ 0 (
            echo [SUCCESS]: !TASK_NAME! _ !TASK_ACTION! >> "%LOG_FILE%"
        ) else (
            echo [FAILED]: !TASK_NAME! _ !TASK_ACTION! >> "%LOG_FILE%"
        )
    )
)
exit /b

:RUNNING_BROWSERS
:: List of browser processes to check
set "BROWSERS=chrome.exe brave.exe msedge.exe firefox.exe"
set "BROWSERS_OPEN=0"

:: Check if any browser is currently running
for %%A in (%BROWSERS%) do (
    tasklist /FI "IMAGENAME eq %%A" 2>nul | find /I "%%A" >nul
    if not errorlevel 1 (
        echo %%A is currently running
        set "BROWSERS_OPEN=1"
    )
)
exit /b

:CLEAN_BROWSER
if "!BROWSERS_OPEN!"=="1" (
    call :CHOICE "Close browsers to clean them?"
    echo.
    if errorlevel 2 (
        echo Skipping cleaning browsers
		call :CLEANING_FUNCTION
		exit /b
    ) else (
        echo Closing browsers
        for %%B in (%BROWSERS%) do (
            taskkill /IM "%%B" /F /T >nul 2>&1
        )
        timeout /t 2 >nul     
    )
)

::  Chromium-based browsers (Chrome, Edge, Brave)
for %%X in (
    "Google\Chrome\User Data|Google Chrome"
    "Microsoft\Edge\User Data|Microsoft Edge"
    "BraveSoftware\Brave-Browser\User Data|Brave"
) do (
    for /f "tokens=1,2 delims=|" %%A in ("%%~X") do (
        if exist "%LOCALAPPDATA%\%%A" (
            echo Cleaning %%B
            for /d %%P in ("%LOCALAPPDATA%\%%A\*") do (
                for %%D in ("Cache" "Code Cache" "GPUCache" "ShaderCache" "Media Cache" "Download Service") do (
                    rd /s /q "%%P\%%~D" >nul 2>&1
                )
            )
        )
    )
)

:: Mozilla Firefox
for %%X in (
    "Mozilla\Firefox|Mozilla Firefox"
) do (
    for /f "tokens=1,2 delims=|" %%A in ("%%~X") do (
        if exist "%APPDATA%\%%A" (
            echo Cleaning %%B
            if exist "%LOCALAPPDATA%\%%A\Profiles" (
                for /d %%P in ("%LOCALAPPDATA%\%%A\Profiles\*") do (
                    for %%D in ("cache2" "thumbnails" "jumpListCache" "startupCache") do (
                        rd /s /q "%%P\%%~D" >nul 2>&1
                    )
                )
            )
            rd /s /q "%APPDATA%\%%A\Crash Reports" >nul 2>&1
        )
    )
)
exit /b

:CLEANING_FUNCTION
echo Cleaning Temp and prefetch folders
for %%F in ("%TEMP%" "%SYSTEMROOT%\TEMP" "%SYSTEMROOT%\Prefetch") do (
    if exist "%%~F" (
        del /f /q "%%~F\*" >nul 2>&1
        for /d %%D in ("%%~F\*") do (
            rd /s /q "%%D" >nul 2>&1
        )
    )
)

:: Clear the "Recent Items" list shown in File Explorer
call :DELETE_FILES "Clearing Recent Files" "%APPDATA%\Microsoft\Windows\Recent\*.lnk"

:: Rebuild icon and thumbnail cache
echo Rebuilding Thumbnail and Icon cache
taskkill /F /IM explorer.exe >nul 2>&1
timeout /t 2 /nobreak >nul
del /f /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache*.db" >nul 2>&1
del /f /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache*.db" >nul 2>&1
start explorer.exe >nul 2>&1

:: Delete PowerShell command history
call :DELETE_FILES "Clearing PowerShell command history" "%APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"

call :CHOICE "Run Disk Cleanup to complete the cleaning?"
if !errorlevel! equ 1 (
    echo Running Disk Cleanup
    cleanmgr.exe /d %SYSTEMDRIVE% /VERYLOWDISK
)

:: Force empty the Recycle Bin for all drives
echo Emptying Recycle Bin
powershell -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue"
exit /b

:SET_POWER_PLAN
echo. & echo Activate %~2 power plan
powercfg /setactive %~1 >nul
call :GO
exit /b

:INFO_SCRIPT
call :PATH_DIR "%~1" "%~2"
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\%~1\%~2.ps1" "%LOG_FILE%"
call :LOG
exit /b

:UPDATE_DNS
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\SetDNS.ps1" ^
    -DnsIPv4Primary "%DNS_IPv4_1%" ^
    -DnsIPv4Secondary "%DNS_IPv4_2%" ^
    -DnsIPv6Primary "%DNS_IPv6_1%" ^
    -DnsIPv6Secondary "%DNS_IPv6_2%"
exit /b

:INIT_PACKAGES
set "PKG_COUNT=0"

:: Browsers
call :ADD_ITEM "googlechrome"                "Google Chrome"
call :ADD_ITEM "brave"                       "Brave"
call :ADD_ITEM "firefox"                     "Firefox"

:: Archivers
call :ADD_ITEM "winrar"                      "WinRAR"
call :ADD_ITEM "7zip.install"                "7-Zip"

:: Media
call :ADD_ITEM "vlc.install"                 "VLC"
call :ADD_ITEM "k-litecodecpack-standard"    "K-Lite Codec"
call :ADD_ITEM "irfanview irfanviewplugins"  "IrfanView"

:: Documents
call :ADD_ITEM "sumatrapdf.install"          "Sumatra PDF"

:: Text Editors / Dev Tools
call :ADD_ITEM "notepadplusplus.install"      "Notepad++"
call :ADD_ITEM "vscode.install"               "VS Code"
call :ADD_ITEM "git.install"                  "Git"

:: Utilities
call :ADD_ITEM "qbittorrent"                  "qbittorrent"
call :ADD_ITEM "vcredist140"                  "VC++ 2015-2022"
call :ADD_ITEM "virtualbox"                   "VirtualBox"
call :ADD_ITEM "io-unlocker"                  "IObit Unlocker"
call :ADD_ITEM "autohotke1y.install"          "AutoHotkey"
call :ADD_ITEM "megasync"                     "MEGA"

set "MAX_PKG=%PKG_COUNT%"
exit /b

:WHERE_CHOCO
where choco >nul 2>&1 && exit /b 0

call :CHOICE "choco not found in PATH. Do you want to install Chocolatey package manager"
if errorlevel 2 exit /b 1

echo. & echo Installing Chocolatey
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Packages\InstallChoco.ps1"
call "%ALLUSERSPROFILE%\chocolatey\bin\RefreshEnv.cmd" >nul

where choco >nul 2>&1
if errorlevel 1 (
    echo. & echo Chocolatey installation failed or not found in PATH
    pause & exit /b 1
)
exit /b 0

:INSTALL_PKG_LIST
if not defined toInstall (
    echo. & echo No packages selected
    exit /b 1
)

cls & echo Selected packages:
for %%P in (!toInstall!) do echo     - %%P

echo. & call :CHOICE "Do you want to continue?"
if errorlevel 2 (
    echo. & echo The operation was cancelled
    exit /b 2
)

call :TRY_ACTION "!toInstall!"
exit /b 0

:LIST_MENU
cls
set "listfile=%temp%\choco_%~3.txt"
del "%listfile%" >nul 2>&1

echo %~2
echo. & call choco %~3 > "%listfile%" 2>&1
type "%listfile%"

call :PRINT_ACTION_PROMPT "%~1"

set "choice=" & set /p "choice=--> "
if "%choice%"=="0" (del "%listfile%" >nul 2>&1 & exit /b 2)

call :PKG_BULK_ACTION "%~4" "%listfile%"
if errorlevel 1 (del "%listfile%" >nul 2>&1 & exit /b 1)

del "%listfile%" >nul 2>&1
exit /b 0

:PKG_BULK_ACTION
echo. & if not defined choice (
    echo No package selected
    exit /b 1
)
set "action=%~1"
if /i "!action!"=="upgrade" (set "verb=Updating") else (set "verb=Removing")

set "listfile=%~2"
set "hasupdate= "
set "installed= "
if /i "!action!"=="upgrade" (
    call :COLLECT_NAMES "!listfile!" hasupdate
) else (
    call :COLLECT_NAMES "!listfile!" installed
)

set "cmd_targets="
if /i "!choice!"=="ALL" (
    if /i "!action!"=="upgrade" (
        if "!hasupdate!"==" " (
            echo No updates are available
            exit /b 1
        )
        set "targets=!hasupdate!"
        set "cmd_targets=all"
    ) else (
        if "!installed!"==" " (
            echo No packages are currently installed
            exit /b 1
        )
        set "targets=!installed!"
        set "cmd_targets=!installed!"
    )
    echo !verb! all packages:
    for %%P in (!targets!) do echo     - %%P
) else (
    set "requested=!choice:,= !"
    set "targets="
    set "missing="
    set "noupdate="
    for %%P in (!requested!) do (
        if /i "!action!"=="upgrade" (
            set "hasupd="
            for %%X in (!hasupdate!) do if /i "%%X"=="%%P" set "hasupd=1"
            if not defined hasupd (
                set "noupdate=!noupdate! %%P"
            ) else (
                set "targets=!targets! %%P"
            )
        ) else (
            set "isinstalled="
            for %%X in (!installed!) do if /i "%%X"=="%%P" set "isinstalled=1"
            if not defined isinstalled (
                set "missing=!missing! %%P"
            ) else (
                set "targets=!targets! %%P"
            )
        )
    )
    if defined missing (
        echo The following packages are not installed and will be skipped:
        for %%M in (!missing!) do echo     - %%M
    )
    if defined noupdate (
        echo The following packages are already up to date and will be skipped:
        for %%N in (!noupdate!) do echo     - %%N
    )
    if not defined targets (
        echo. & echo None of the selected packages need action
        exit /b 1
    )
    echo !verb! the following packages:
    for %%P in (!targets!) do echo     - %%P
    set "cmd_targets=!targets!"
)

echo. & call :CHOICE "Do you want to continue?"
if errorlevel 2 (echo. & echo The operation was cancelled & exit /b 2)
if /i "!action!"=="upgrade" (
    echo. & call choco upgrade !cmd_targets! -y
) else (
    echo. & call choco uninstall !cmd_targets! -y
)
exit /b 0

:COLLECT_NAMES
set "src_file=%~1"
set "names= "
for /f "usebackq delims=" %%P in ("!src_file!") do (
    set "ln=%%P"
    set "skip=0"
    if "!ln!"=="" set "skip=1"
    echo(!ln!| findstr /i /c:"Chocolatey v" /c:"Output is" /c:"packages installed" /c:"package(s) are outdated" /c:"Did you know" >nul && set "skip=1"
    if "!skip!"=="0" (
        if not "!ln:|=!"=="!ln!" (
            for /f "tokens=1 delims=|" %%A in ("!ln!") do set "names=!names!%%A "
        ) else (
            for /f "tokens=1" %%A in ("!ln!") do set "names=!names!%%A "
        )
    )
)
set "%~2=!names!"
exit /b

:PROCESS_PKG
set "query=%~1"
echo. & echo Searching for: !query!
call choco search "!query!" --exact --limit-output > "%temp%\choco_result.txt" 2>nul

set "found=0"
set "official_pkg="
set "official_version="

for /f "tokens=1,2 delims=|" %%L in ('type "%temp%\choco_result.txt" 2^>nul') do (
    set "found=1"
    set "official_pkg=%%L"
    set "official_version=%%M"
)

if "!found!"=="1" (
    echo. & echo Official package found: !official_pkg! !official_version!
    call :CHOICE "Do you want to install !official_pkg!"
    if errorlevel 2 (
        echo Installation skipped
    ) else (
        call :TRY_ACTION "!official_pkg!"
    )
) else (
    echo No exact match for "!query!" was found
    echo Similar packages available in Chocolatey:
    echo. & call choco search "!query!" --limit-output
    echo. & echo No package was installed automatically. Check the list above and pick the correct name if available
)

del "%temp%\choco_result.txt" >nul 2>&1
exit /b

:: %1 = package id to install (also used as the display name, so it no longer needs to be passed twice)
:TRY_ACTION
echo. & call choco install %~1 -y
if !errorlevel! neq 0 (
    echo. & echo One or more packages failed to install
    call :CHOICE "Do you want to ignore checksum and retry"
    if errorlevel 2 (
        echo The retry was skipped
    ) else (
        echo. & echo Retrying with --ignore-checksums
        call choco install %~1 --ignore-checksums -y
    )
)
exit /b

:PRINT_ACTION_PROMPT
echo.
echo --------------------------------------------------------------------------------
echo Type ALL to %~1 everything
echo Or type the exact name(s) as shown above, separated by spaces
echo Type 0 to go back
echo --------------------------------------------------------------------------------
exit /b

:RENDER_COLUMNS
set /a "ROWS=(MAX_PKG+2)/3"
for /L %%r in (1,1,!ROWS!) do (
    set "line="
    for %%x in (1 2 3) do (
        set /a "idx=%%r+ROWS*(%%x-1)"
        set "cell=                          "
        if !idx! leq !MAX_PKG! (
            for %%V in (ITEM!idx!) do for %%W in (OPT!idx!) do (
                for /f "tokens=1,2 delims=|" %%A in ("!%%V!") do (
                    set "cell=  [!idx!] %%B"
                    if "!%%W!"=="!ON!" set "cell=* [!idx!] %%B"
                )
            )
        )
        set "cell=!cell!                          "
        set "cell=!cell:~0,25!"
        set "line=!line!!cell!"
    )
    echo                   !line!
)
exit /b

:TOGGLE_ALL
set "val=!OFF!"
if /i "%~1"=="ON" set "val=!ON!"
for /L %%i in (1,1,%MAX_PKG%) do set "OPT%%i=!val!"
exit /b

:ADD_ITEM
set /a "PKG_COUNT+=1"
set "ITEM%PKG_COUNT%=%~1|%~2"
exit /b

:MULTI_INPUT
set "prefix=%~1"
set "max_count=%~2"
set "invalid="
set "tokens=!choice:,= !"

for %%G in (%tokens%) do (
    set "tok=%%G"
    set "matched=0"
    set "noHyphen=!tok:-=!"

    if not "!tok!"=="!noHyphen!" (
        set "rangeStart=" & set "rangeEnd="
        for /f "tokens=1,2 delims=-" %%X in ("!tok!") do (
            set "rangeStart=%%X"
            set "rangeEnd=%%Y"
        )
        set "isNum1=1" & for /f "delims=0123456789" %%C in ("!rangeStart!") do set "isNum1=0"
        set "isNum2=1" & for /f "delims=0123456789" %%C in ("!rangeEnd!") do set "isNum2=0"

        if defined rangeStart if defined rangeEnd if "!isNum1!!isNum2!"=="11" (
            if !rangeStart! geq 1 if !rangeEnd! leq !max_count! if !rangeStart! leq !rangeEnd! (
                for /L %%N in (!rangeStart!,1,!rangeEnd!) do (
                    for %%V in (%prefix%%%N) do (
                        if "!%%V!"=="%ON%" (set "%%V=%OFF%") else (set "%%V=%ON%")
                    )
                )
                set "matched=1"
            )
        )
    ) else (
        set "isNum=1" & for /f "delims=0123456789" %%C in ("!tok!") do set "isNum=0"
        if "!isNum!"=="1" if defined tok (
            if !tok! geq 1 if !tok! leq !max_count! (
                for %%V in (%prefix%!tok!) do (
                    if "!%%V!"=="%ON%" (set "%%V=%OFF%") else (set "%%V=%ON%")
                )
                set "matched=1"
            )
        )
    )

    if "!matched!"=="0" set "invalid=!invalid! !tok!"
)

if defined invalid (
    echo. & echo Invalid or out-of-range input:!invalid!
    pause
)
exit /b

:NET_CONTROL
:: Check if the service exists
sc query %~1 >nul 2>&1
if !errorlevel! neq 0 (
    echo [NOT FOUND]: %~1
    exit /b
)

:: Execute the action based on the requested operation (stop or start)
if /i %~2==stop (
    :: Check if the service is already stopped
    sc query %~1 | find /i "STOPPED" >nul
    if !errorlevel! equ 0 (
        echo [ALREADY STOPPED]: %~1
    ) else (
        :: Try to stop the service
        net stop %~1 >nul 2>&1
        if !errorlevel! equ 0 (
            echo [SUCCESS]: %~1 _ %~2 
        ) else (
            echo [FAILED]: %~1 _ %~2 
        )
    )
) else if /i %~2==start (
    :: Check if the service is already running
    sc query %~1 | find /i "RUNNING" >nul
    if !errorlevel! equ 0 (
        echo [ALREADY RUNNING]: %~1
    ) else (
        :: Try to start the service
        net start %~1 >nul 2>&1
        if !errorlevel! equ 0 (
            echo [SUCCESS]: %~1 _ %~2 
        ) else (
            echo [FAILED]: %~1 _ %~2 
        )
    )
)
exit /b

:SC_CONFIGURE
sc query %~1 >nul 2>&1
if !errorlevel! neq 0 (
    echo [NOT FOUND]: %~1
    exit /b
)

sc config %~1 start= %~2 >nul 2>&1
if !errorlevel! equ 0 (
    echo [SUCCESS]: %~1 _ %~2
) else (
    echo [FAILED]: %~1 _ %~2
)
exit /b

:CREATE_FILE
call :MKDIR_PROMPT "%PROGRAMDATA%\WinTweaks\%~1"

set "TARGET_FILE=%PROGRAMDATA%\WinTweaks\%~1\%~2"
if exist "%TARGET_FILE%" (
    echo. & echo %TARGET_FILE%: Already exists
    call :CHOICE "Do you want to delete the existing file and start fresh?"
    if errorlevel 2 exit /b 2

    del /f /q "%TARGET_FILE%" >nul 2>&1
)

if exist "%TARGET_FILE%" (
    echo. & echo Failed to delete old file
    pause & exit /b 1
)
exit /b

:CREATE_FOLDER
set "TARGET_FOLDER=%PROGRAMDATA%\WinTweaks\%~1\%~2"

if exist "%TARGET_FOLDER%" (
    echo. & echo %TARGET_FOLDER%: Already exists
    call :CHOICE "Do you want to delete the existing backup folder and start fresh?"
    if errorlevel 2 exit /b 2
    
    rd /s /q "%TARGET_FOLDER%" >nul 2>&1
)

if exist "%TARGET_FOLDER%" (
    echo. & echo Failed to delete old backup folder
    pause & exit /b 1
) else (
    call :MKDIR_PROMPT "%PROGRAMDATA%\WinTweaks\%~1\%~2"
)
exit /b

:PATH_DIR
:: Define the base directory within PROGRAMDATA for organizational consistency
call :MKDIR_PROMPT "%PROGRAMDATA%\WinTweaks\%~1"

:: Set the full path for the current log file
set "LOG_FILE=%MKDIR_DIR%\%~2.log"

:: Initialize the log file with a fresh timestamp header for every session
(echo Start at %time% %date% & echo.) > "%LOG_FILE%" 2>&1
exit /b

:DELETE_FILES
if exist "%~2" (
    echo %~1
    if "%~3"=="" (
        del /f /q "%~2" >nul 2>&1
    ) else (
        del /f /q "%~2" >> "%~3" 2>&1
    )
)
exit /b

:DELETE_FOLDERS
if exist "%~2" (
    echo %~1
    if "%~3"=="" (
        rd /s /q "%~2" >nul 2>&1
    ) else (
        rd /s /q "%~2" >> "%~3" 2>&1
    )
)
exit /b

:MKDIR_PROMPT
set "MKDIR_DIR=%~1"

:: Create the folder if it does not exist
if not exist "%MKDIR_DIR%" (
    mkdir "%~1" >nul 2>&1
    if errorlevel 1 (
        echo Failed to create: %MKDIR_DIR%
        pause & goto MAIN_MENU
    )
)
exit /b

:RESTART
echo. & call :CHOICE "Do you want to restart your computer?"
if !errorlevel! equ 1 (
    echo Your computer will restart after 5 seconds
    shutdown /r /t 5
    timeout /t 3 >nul
    exit
)
exit /b

:: This section dynamically builds a menu based on variables set before calling it
:SUB_MENU
cls & echo. & echo.
echo      [1] %APPLY%
echo.
echo      [2] %REVERT%
echo.
echo      [0] Back
echo. & set "choice=" & set /p choice="Select an option: "

if "%choice%"=="1" set "SUBMENU_RESULT=%ROUTINE%" & exit /b
if "%choice%"=="2" set "SUBMENU_RESULT=%REV_ROUTINE%" & exit /b
if "%choice%"=="0" set "SUBMENU_RESULT=%MENU%" & exit /b
call :INVALID "(0-2)" & goto SUB_MENU

:CHOICE
choice /C YN /N /M "%~1 [Y/n]: "
exit /b

:CONFIRM
cls & echo %~1
call :CHOICE "Continue anyway?"
exit /b

:LOG
echo. & echo More details in: %LOG_FILE%
echo. & echo The operation is done.
pause
exit /b

:INVALID
echo. & echo [ERROR] Invalid selection. Please choose a valid option between %~1
pause
exit /b

:GO
echo. & echo The operation is done.
pause
exit /b
