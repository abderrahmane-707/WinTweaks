@echo off
setlocal enabledelayedexpansion
title WinTweaks

:: Check for administrator privileges
fltmc >nul 2>&1
if errorlevel 1 (
    echo This script must be run with Administrator privileges
    pause
    exit
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
echo                            [3] Network                                            [4] Programs
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
if "%choice%"=="4" goto PROGRAMS_MANAGER_MENU
if "%choice%"=="5" goto CUSTOMIZATION_MENU
if "%choice%"=="6" goto SYSTEM_MENU
if "%choice%"=="7" goto TOOLS_MENU
if "%choice%"=="8" goto OTHER_MENU
if "%choice%"=="0" exit /b

call :INVALID "(0-8)" "MAIN_MENU"


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
    goto SUB_MENU
)
if "%choice%"=="3" (
    set ROUTINE=BOOT_TWEAKS
    set REV_ROUTINE=REV_BOOT_TWEAKS
	set APPLY=Enhance boot-up settings
    set REVERT=Set boot-up settings to default
    set MENU=PERFORMANCE_MENU
    goto SUB_MENU
)
if "%choice%"=="4" goto CLEAN_UP
if "%choice%"=="5" goto POWER_PLAN_MENU
if "%choice%"=="6" goto HW_INFO_MENU
if "%choice%"=="0" goto MAIN_MENU

call :INVALID "(0-6)" "PERFORMANCE_MENU"

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
    set MESSAGE=Tweaking Windows services
    set LOG=ServicesTweaks
    goto SET_SERVICES
)
if "%choice%"=="2" (
    set FILE=Files\Performance\SafeServicesTweaks.txt
    set MESSAGE=Tweaking Windows services in safe mode
    set LOG=SafeServicesTweaks
    goto SET_SERVICES
)
if "%choice%"=="3" (
    set FILE=Files\Performance\DefaultServicesSettings.txt
    set MESSAGE=Restore most Windows services to default startup
    set LOG=DefaultServicesSettings
    goto SET_SERVICES
)
if "%choice%"=="4" goto EXPORT_SERVICES
if "%choice%"=="0" goto PERFORMANCE_MENU

call :INVALID "(0-4)" "SERVICES_MENU"

:SET_SERVICES
call :PATH "Performance" "%LOG%"
echo. & echo %MESSAGE%

:: Process each line in the configuration file
for /f "usebackq tokens=1,2 delims=," %%A in ("%FILE%") do (
    set "SERVICE_NAME=%%A"
    set "SERVICE_STATUS=%%B"
    set "SC_PARAM="
    
    :: Check if service exists in the system
    sc query "!SERVICE_NAME!" >nul 2>&1
    if !errorlevel! equ 0 (
        set "SC_PARAM="
        
        :: Map configuration status to SC command parameters
        if /i "!SERVICE_STATUS!"=="Disabled"  set "SC_PARAM=disabled"
        if /i "!SERVICE_STATUS!"=="Manual"  set "SC_PARAM=demand"
        if /i "!SERVICE_STATUS!"=="Automatic"  set "SC_PARAM=auto"
        if /i "!SERVICE_STATUS!"=="AutomaticDelayedStart"  set "SC_PARAM=delayed-auto"
        
        :: Execute configuration if status is valid
        if defined SC_PARAM (
            sc config "!SERVICE_NAME!" start= !SC_PARAM! >nul 2>&1
            
            :: Evaluate command result
            if !errorlevel! equ 0 (
                set "RESULT_TAG=[SUCCESS]"
            ) else (
                set "RESULT_TAG=[FAILED]"
            )
            echo !RESULT_TAG!: !SERVICE_NAME! _ !SERVICE_STATUS! >> "%LOG_FILE%" 2>&1
        )
        
    ) else (
        :: Log if service is not found
        echo [NOT FOUND]: !SERVICE_NAME! >> "%LOG_FILE%" 2>&1
    )
)

call :LOG SERVICES_MENU

:: Create a snapshot of all current Service startup types
:EXPORT_SERVICES
call :CREATE_FILE "Performance" "ServiceStartupStatus.log"
echo. & echo Exporting service startup status
powershell -Command "Get-Service | Sort-Object Name | ForEach-Object { Write-Output ($_.Name + ',' + $_.StartType) }" >> "%TARGET_FILE%" 2>&1
echo. & echo Service Startup Status file saved in: %TARGET_FILE%
call :GO PERFORMANCE_MENU

:DISABLE_TASKS
call :PATH "Performance" "DisableScheduledTasks"

echo. & echo Disabling unnecessary scheduled tasks
call :SET_TASKS "Disable" "Files\Performance\TasksList.txt"
call :LOG PERFORMANCE_MENU
    
:ENABLE_TASKS
call :PATH "Performance" "EnableScheduledTasks"

echo. & echo Re-enable previously disabled scheduled tasks
call :SET_TASKS "Enable" "Files\Performance\TasksList.txt"
call :LOG PERFORMANCE_MENU

:BOOT_TWEAKS
echo. & echo Import Boot up tweaks registry settings
reg import "Files\Performance\BootTweaks.reg"

echo Deleting startup shortcuts
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\*.lnk" (
    del /f /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\*.lnk" >nul
)

if exist "%PROGRAMDATA%\Microsoft\Windows\Start Menu\Programs\Startup\*.lnk" (
    del /f /q "%PROGRAMDATA%\Microsoft\Windows\Start Menu\Programs\Startup\*.lnk" >nul
)

call :GO PERFORMANCE_MENU

:REV_BOOT_TWEAKS
echo. & echo Import default Boot up registry settings
reg import "Files\Performance\DefaultBootSettings.reg"

call :GO PERFORMANCE_MENU

:CLEAN_UP
cls
call :RUNNING_BROWSERS

if "!BROWSERS_OPEN!"=="1" (
    call :CHOICE "Close browsers to clean them?"
    echo.
    if errorlevel 2 (
        echo Skipping cleaning browsers
    ) else (
        echo Closing browsers
        for %%B in (%BROWSERS%) do (
            taskkill /IM "%%B" /F /T >nul 2>&1
        )
        timeout /t 2 >nul
        call :CLEAN_BROWSER
    )
)

call :CLEANING_FUNCTION
call :GO PERFORMANCE_MENU

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
    goto SUB_MENU
)
if "%choice%"=="2" goto PLAN_HIGH
if "%choice%"=="3" goto PLAN_BALANCED
if "%choice%"=="4" goto PLAN_SAVER
if "%choice%"=="5" goto ACTIVE_PLAN
if "%choice%"=="0" goto PERFORMANCE_MENU

call :INVALID "(0-5)" "POWER_PLAN_MENU"

:: Unlock and add the "Ultimate Performance" plan
:ADD_ULTIMATE_PLAN
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\AddUltimatePerformance.ps1"
call :GO POWER_PLAN_MENU

:: Remove the "Ultimate Performance" plan
:REMOVE_ULTIMATE_PLAN
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\RemoveUltimatePerformance.ps1"
call :GO POWER_PLAN_MENU

:PLAN_HIGH
echo. & echo Activate high performance power plan
:: This is the standard Windows GUID for High Performance
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul
call :GO POWER_PLAN_MENU

:PLAN_BALANCED
echo. & echo Activate balanced power plan
:: This is the standard Windows GUID for Balanced (Windows default)
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e >nul
call :GO POWER_PLAN_MENU

:PLAN_SAVER
echo. & echo Activate power saver plan
:: This is the standard Windows GUID for Power Saver
powercfg /setactive a1841308-3541-4fab-bc81-f71556f20b4a >nul
call :GO POWER_PLAN_MENU

:ACTIVE_PLAN
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\ActivePlan.ps1"
call :GO POWER_PLAN_MENU

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
if "%choice%"=="1" goto CPU_INFO
if "%choice%"=="2" goto GPU_INFO
if "%choice%"=="3" goto HARD_DISK_INFO
if "%choice%"=="4" goto RAM_INFO
if "%choice%"=="5" goto MOTHERBOARD_INFO
if "%choice%"=="6" goto BATTERY_INFO
if "%choice%"=="0" goto PERFORMANCE_MENU

call :INVALID "(0-6)" "HW_INFO_MENU"

:: Display detailed processor
:CPU_INFO
call :PATH "Performance" "CPUInfo"
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\CPUInfo.ps1" "%LOG_FILE%"
call :LOG HW_INFO_MENU

:: Display Graphics Card details
:GPU_INFO
call :PATH "Performance" "GPUInfo"
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\GPUInfo.ps1" "%LOG_FILE%"
call :LOG HW_INFO_MENU

:: Display Storage stats
:HARD_DISK_INFO
call :PATH "Performance" "HardDiskInfo"
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\HardDiskInfo.ps1" "%LOG_FILE%"
call :LOG HW_INFO_MENU

:: Display RAM information
:RAM_INFO
call :PATH "Performance" "MemoryInfo"
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\MemoryInfo.ps1" "%LOG_FILE%"
call :LOG HW_INFO_MENU

:: Display Motherboard information
:MOTHERBOARD_INFO
call :PATH "Performance" "MotherboardInfo"
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\MotherboardInfo.ps1" "%LOG_FILE%"
call :LOG HW_INFO_MENU

:: Generate an advanced HTML report regarding battery health and cycle count
:BATTERY_INFO
call :MKDIR_PROMPT "%PROGRAMDATA%\WinTweaks\Performance"
set "BATTERY_REPORT=%MKDIR_DIR%\BatteryReport.html"

cls & echo Creating battery report
powercfg /batteryreport /output "%BATTERY_REPORT%"

:: Opening battery report
start "" "%BATTERY_REPORT%"
call :GO HW_INFO_MENU


:PRIVACY_SECURITY_MENU
cls & echo. & echo.
echo                        --------------------------- Privacy and Security --------------------------
echo.
echo                          [1] Telemetry                                       [2] Privacy Cleanup
echo.
echo                          [3] Windows Updates                                 [4] Windows Defender
echo.
echo                          [5] Enhance Security                                [6] Remove all policies
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
    goto SUB_MENU
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
    goto SUB_MENU
)
if "%choice%"=="6" goto REMOVE_POLICIES
if "%choice%"=="7" goto SECURITY_INFO
if "%choice%"=="0" goto MAIN_MENU

call :INVALID "(0-7)" "PRIVACY_SECURITY_MENU"

:DISABLE_TELEMETRY
call :PATH "Security" "DisableTelemetry"
call :CREATE_FILE "Security" "HostsOriginal"

set "HOSTS_PATH=%SYSTEMROOT%\System32\drivers\etc\hosts"

echo. & echo Disabling Windows telemetry via registry
reg import "Files\Security\DisableTelemetry.reg" >> "%LOG_FILE%" 2>&1

echo Disabling Windows telemetry services

:: DiagTrack:      Connected User Experiences and Telemetry
:: dmwappushsvc:   WAP Push Message Routing Service
:: WerSvc:         Windows Error Reporting Service
for %%S in (DiagTrack dmwappushsvc WerSvc) do call :SC_CONFIGURE "%%S" "disabled" >> "%LOG_FILE%" 2>&1

echo Backing up original Hosts file
copy /y "%HOSTS_PATH%" "%TARGET_FILE%" >> "%LOG_FILE%" 2>&1

echo Blocking windows telemetry and trash domains
set "HOSTS_PATH=%SYSTEMROOT%\System32\drivers\etc\hosts"
for /f "usebackq delims=" %%L in ("Files\Security\TrackingDomains.txt") do (
    findstr /C:"%%L" "%HOSTS_PATH%" >nul
    if errorlevel 1 (
        :: Add domain if not exist
        echo %%L >> "%HOSTS_PATH%"
    )
)

echo Flushing DNS cache
ipconfig /flushdns >> "%LOG_FILE%" 2>&1

call :LOG PRIVACY_SECURITY_MENU

:REV_DISABLE_TELEMETRY
call :PATH "Security" "DefaultTelemetry"

set "HOSTS_PATH=%SYSTEMROOT%\System32\drivers\etc\hosts"
set "TEMP_FILE=%TEMP%\HostsClean.txt"

echo. & echo Restoring default telemetry registry settings
reg import "Files\Security\DefaultTelemetry.reg" >> "%LOG_FILE%" 2>&1

echo Setting telemetry services to manual startup
for %%S in (DiagTrack dmwappushsvc WerSvc) do call :SC_CONFIGURE "%%S" "demand" >> "%LOG_FILE%" 2>&1

echo Removing telemetry and trash domain entries from the Hosts file
:: Backing up the Hosts file
copy /y "%HOSTS_PATH%" "%ProgramData%\WinTweaks\Security\HostsOriginal" >> "%LOG_FILE%" 2>&1

:: Filter out blocked domains listed in TrackingDomains.txt from the HOSTS file
findstr /V /L /G:"Files\Security\TrackingDomains.txt" "%HOSTS_PATH%" > "%TEMP_FILE%"

:: Overwrite the original HOSTS file with the filtered version
copy /y "%TEMP_FILE%" "%HOSTS_PATH%" >> "%LOG_FILE%" 2>&1
del "%TEMP_FILE%" >nul 2>&1

echo Flushing DNS cache
ipconfig /flushdns >> "%LOG_FILE%" 2>&1

call :LOG PRIVACY_SECURITY_MENU

:PRIVACY_CLEANUP
call :CONFIRM "WARNING: This will PERMANENTLY DELETE browser data, logs, and privacy-related information!"
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

:: Remove all Chromium-based browsers personal data
if exist "%LOCALAPPDATA%\Google\Chrome\User Data" (
    echo Cleaning Google Chrome data
    rd /s /q "%LOCALAPPDATA%\Google\Chrome\User Data" >nul 2>&1
)

if exist "%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data" (
    echo Cleaning Brave data
    rd /s /q "%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data" >nul 2>&1
)

if exist "%LOCALAPPDATA%\Microsoft\Edge\User Data" (
    echo Cleaning Microsoft Edge data
    rd /s /q "%LOCALAPPDATA%\Microsoft\Edge\User Data" >nul 2>&1
)

:: Remove all Mozilla Firefox personal data
echo Cleaning Mozilla Firefox data
if exist "%APPDATA%\Mozilla\Firefox" (
    rd /s /q "%APPDATA%\Mozilla\Firefox" >nul 2>&1
)

if exist "%LOCALAPPDATA%\Mozilla\Firefox" (
    rd /s /q "%LOCALAPPDATA%\Mozilla\Firefox" >nul 2>&1
)

echo Cleaning registry entries
reg import "Files\Security\PrivacyCleanup.reg" >nul 2>&1

:: Clear application launch history and start fresh
echo Cleaning prefetch files
del /f /s /q "%SYSTEMROOT%\Prefetch\*" >nul 2>&1

:: Clean System Log files
echo Cleaning system log files
for /d %%L in ("%SYSTEMROOT%\Logs\*" "%SYSTEMROOT%\System32\LogFiles\*" ) do "Files\Security\PowerRun.exe" /TI /SW:0 cmd.exe /c "del /f /s /q %%L\*" >nul 2>&1

:: Clear Windows Event Viewer logs
echo Cleaning Windows Event Logs
for %%L in ("Application" "Security" "System" "Setup") do wevtutil clear-log %%L >nul 2>&1

echo Clearing clipboard content
echo. | clip >nul

echo Flushing DNS cache
ipconfig /flushdns >nul 2>&1

call :CLEANING_FUNCTION
call :GO PRIVACY_SECURITY_MENU

:WINDOWS_UPDATES_MENU
cls & echo. & echo.
echo                        ------------------------------ Windows Updates ----------------------------
echo.
echo                          [1] Disable Updates                              [2] Enable Updates
echo.
echo                          [3] Reset / Repair Updates                       [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto DISABLE_UPDATES
if "%choice%"=="2" goto ENABLE_UPDATES
if "%choice%"=="3" goto RESET_UPDATES
if "%choice%"=="0" goto PRIVACY_SECURITY_MENU

call :INVALID "(0-3)" "WINDOWS_UPDATES_MENU"

:DISABLE_UPDATES
call :PATH "Security" "DisableUpdates"

echo. & echo Disabling Windows Updates via registry
reg import "Files\Security\DisableUpdates.reg" >> "%LOG_FILE%" 2>&1

echo Disabling Windows Update services
for %%S in (BITS UsoSvc wuauserv) do call :SC_CONFIGURE "%%S" "disabled" >> "%LOG_FILE%" 2>&1

echo Stopping Windows Update services
for %%S in (BITS UsoSvc wuauserv) do call :NET_CONTROL "%%S" "stop" >> "%LOG_FILE%" 2>&1

echo echo Deleting SoftwareDistribution folder
rd /s /q "%SYSTEMROOT%\SoftwareDistribution" >> "%LOG_FILE%" 2>&1

echo Deleting Windows Update log
del /f /q "%SYSTEMROOT%\WindowsUpdate.log" >> "%LOG_FILE%" 2>&1

call :LOG WINDOWS_UPDATES_MENU

:ENABLE_UPDATES
call :PATH "Security" "DefaultUpdates"

echo. & echo Restoring default Windows Update registry settings
reg import "Files\Security\DefaultUpdates.reg" >> "%LOG_FILE%" 2>&1

echo Setting Windows Update services to default startup
call :SC_CONFIGURE "UsoSvc" "delayed-auto"
for %%S in (BITS wuauserv) do call :SC_CONFIGURE "%%S" "demand" >> "%LOG_FILE%" 2>&1

call :LOG WINDOWS_UPDATES_MENU

:RESET_UPDATES
call :CONFIRM "WARNING: This will purge all Windows Update data and reset security policies!"
if errorlevel 2 goto WINDOWS_UPDATES_MENU

call :PATH "Security" "ResetUpdates"

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
for %%S in (BITS CryptSvc DoSvc UsoSvc WaaSMedicSvc wuauserv WinHttpAutoProxySvc) do call :NET_CONTROL "%%S" "stop" >> "%LOG_FILE%" 2>&1

:: Remove pending Updates and update history
echo echo Deleting SoftwareDistribution folder
rd /s /q "%SYSTEMROOT%\SoftwareDistribution" >> "%LOG_FILE%" 2>&1

:: Force Windows to rebuild the update database and signatures
echo Deleting Catroot2 folder
rd /s /q "%SYSTEMROOT%\System32\catroot2" >> "%LOG_FILE%" 2>&1

:: Remove BITS Queue Manager (QMGR) data files to clear stuck download jobs
echo Clearing BITS queue manager data files
del /f /q "%ALLUSERSPROFILE%\Microsoft\Network\Downloader\qmgr*.dat" >> "%LOG_FILE%" 2>&1

echo Deleting Windows Update log
del /f /q "%SYSTEMROOT%\WindowsUpdate.log" >> "%LOG_FILE%" 2>&1

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
echo Apply default security settings
secedit /configure /cfg "%SYSTEMROOT%\inf\defltbase.inf" /db "%TEMP%\defltbase.sdb" /verbose >> "%LOG_FILE%" 2>&1

:: Forcefully clear all BITS download jobs for all users on the system
echo Clearing all BITS download jobs
bitsadmin /reset /allusers >> "%LOG_FILE%" 2>&1

echo Setting Windows Update services to default startup
call :SC_CONFIGURE "CryptSvc" "auto"
for %%S in (UsoSvc DoSvc) do call :SC_CONFIGURE "%%S" "delayed-auto" >> "%LOG_FILE%" 2>&1
for %%S in (BITS wuauserv WaaSMedicSvc WinHttpAutoProxySvc) do call :SC_CONFIGURE "%%S" "demand" >> "%LOG_FILE%" 2>&1

echo Starting Windows Update services
for %%S in (BITS CryptSvc DoSvc UsoSvc WaaSMedicSvc wuauserv WinHttpAutoProxySvc) do call :NET_CONTROL "%%S" "start" >> "%LOG_FILE%" 2>&1

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
call :LOG WINDOWS_UPDATES_MENU

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

call :INVALID "(0-3)" "WINDOWS_DEFENDER_MENU"

:DISABLE_DEFENDER
call :CONFIRM "WARNING: This will PERMANENTLY DISABLE Windows Defender real-time protection!"
if errorlevel 2 goto WINDOWS_DEFENDER_MENU

echo. & echo Disabling Windows defender via registry
reg import "Files\Security\DisableDefender.reg"

call :RESTART
call :GO WINDOWS_DEFENDER_MENU

:ENABLE_DEFENDER
echo. & echo Restoring default Windows Defender registry settings
reg import "Files\Security\DefaultDefender.reg"
call :GO WINDOWS_DEFENDER_MENU

:REMOVE_DEFENDER
call :CONFIRM "WARNING: This will PERMANENTLY remove Windows Defender core files and services from your system!"
if errorlevel 2 goto WINDOWS_DEFENDER_MENU

echo. & echo Removing Windows Defender Security Health UI component
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Security\RemoveSecHealthUI.ps1" >nul

echo Removing Windows Defender entries from the registry
for %%f in ("Files\Security\RemoveDefenderModule\*.reg") do "Files\Security\PowerRun.exe" /TI /SW:0 regedit.exe /s "%%f"

echo Deleting Windows Defender files
"Files\Security\PowerRun.exe" /TI /SW:0 "Files\Security\DefenderFileRemover.bat"

call :RESTART
call :GO WINDOWS_DEFENDER_MENU

:ENHANCE_SECURITY
call :PATH "Security" "EnhanceSecurity"

echo. & echo Applying security hardening registry settings
reg import "Files\Security\EnhanceSecurity.reg" >> "%LOG_FILE%" 2>&1

echo Disabling unsafe Windows features
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Security\DisableUnsafeFeature.ps1" >> "%LOG_FILE%" 2>&1

echo Disabling unsafe Windows services

:: mrxsmb10:        SMB 1.0/CIFS File Server Driver (High security risk)
:: RemoteRegistry:  Allows remote users to modify Windows Registry settings
:: SNMP:            Simple Network Management Protocol (Often used for network reconnaissance)
:: SNMPTRAP:        Receives trap messages generated by local or remote SNMP agents
for %%S in (mrxsmb10 RemoteRegistry SNMP SNMPTRAP) do (
    call :NET_CONTROL "%%S" "stop" >> "%LOG_FILE%" 2>&1
    call :SC_CONFIGURE "%%S" "disabled" >> "%LOG_FILE%" 2>&1
)

:: Remove 'defaultuser0', a temporary account often left behind after Windows installation
echo Removing temporary default user account
net user defaultuser0 /delete >> "%LOG_FILE%" 2>&1

call :LOG PRIVACY_SECURITY_MENU

:REV_ENHANCE_SECURITY
echo. & echo Restoring default Windows security registry settings
reg import "Files\Security\DefaultSecurity.reg"

call :GO PRIVACY_SECURITY_MENU

:REMOVE_POLICIES
call :CONFIRM "WARNING: This script will RESET all Group Policy settings to system defaults!"
if errorlevel 2 goto PRIVACY_SECURITY_MENU

call :PATH "Security" "RemoveAllPolicies"
call :CREATE_FOLDER "Security" "GroupPolicyBackup"
if %errorlevel% equ 1 call :GO PRIVACY_SECURITY_MENU

set "GP_DIR=%WinDir%\System32\GroupPolicy"
set "GPU_DIR=%WinDir%\System32\GroupPolicyUsers"

set "GP_KEY=HKLM\Software\Policies"
set "GPU_KEY=HKCU\Software\Policies"

set "HKLM_POLICIES="
set "HKCU_POLICIES="

echo.
if exist "%GP_DIR%" (
    echo Backing up GroupPolicy folder
    robocopy "%GP_DIR%" "%BACKUP_DIR%\GroupPolicy" /E /COPYALL /R:0 /W:0 >> "%LOG_FILE%" 2>&1
    if !errorlevel! geq 8 (
        echo [ERROR] Failed to backup GroupPolicy. Operation aborted
        call :GO PRIVACY_SECURITY_MENU
    )
)

if exist "%GPU_DIR%" (
    echo Backing up GroupPolicyUsers folder
    robocopy "%GPU_DIR%" "%BACKUP_DIR%\GroupPolicyUsers" /E /COPYALL /R:0 /W:0 >> "%LOG_FILE%" 2>&1
    if !errorlevel! geq 8 (
        echo [ERROR] Failed to backup GroupPolicyUsers. Operation aborted
        call :GO PRIVACY_SECURITY_MENU
    )
)

reg query "%GP_KEY%" >nul 2>&1
if !errorlevel! equ 0 (
    set "HKLM_POLICIES=0"
    echo Backing up HKLM Policies registry key
    reg export "%GP_KEY%" "%BACKUP_DIR%\HKLM_Policies_Backup.reg" >> "%LOG_FILE%" 2>&1
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to backup HKLM Policies. Operation aborted
        call :GO PRIVACY_SECURITY_MENU
    )
)

reg query "%GPU_KEY%" >nul 2>&1
if !errorlevel! equ 0 (
    set "HKCU_POLICIES=0"
    echo Backing up HKCU Policies registry key
    reg export "%GPU_KEY%" "%BACKUP_DIR%\HKCU_Policies_Backup.reg" >> "%LOG_FILE%" 2>&1
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to backup HKCU Policies. Operation aborted
        call :GO PRIVACY_SECURITY_MENU
    )
)

echo.
if exist "%GP_DIR%" (
    echo Deleting GroupPolicy folder
    rd /s /q "%GP_DIR%" >> "%LOG_FILE%" 2>&1
)

if exist "%GPU_DIR%" (
    echo Deleting GroupPolicyUsers folder
    rd /s /q "%GPU_DIR%" >> "%LOG_FILE%" 2>&1
)

if "!HKLM_POLICIES!"=="0" (
    echo Deleting HKLM Policies registry key
    reg delete "%GP_KEY%" /f >> "%LOG_FILE%" 2>&1
)

if "!HKCU_POLICIES!"=="0" (
    echo Deleting HKCU Policies registry key
    reg delete "%GPU_KEY%" /f >> "%LOG_FILE%" 2>&1
)

echo. & echo Applying Group Policy Update
gpupdate /force >nul 2>&1

echo. & echo Backup files saved in: %BACKUP_DIR%
call :LOG PRIVACY_SECURITY_MENU

:SECURITY_INFO
call :PATH "Security" "SecurityInfo"
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Security\SecurityInfo.ps1" "%LOG_FILE%"
call :LOG PRIVACY_SECURITY_MENU


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
    goto SUB_MENU
)
if "%choice%"=="2" goto DNS_MENU
if "%choice%"=="3" goto WIFI_PASSWORDS
if "%choice%"=="4" goto NETWORK_RESET
if "%choice%"=="5" goto NETWORK_INFO
if "%choice%"=="0" goto MAIN_MENU

call :INVALID "(0-5)" "NETWORK_MENU"

:NETWORK_TWEAKS
call :PATH "Network" "NetworkTweaks"

echo. & echo Improve network settings via registry
reg import "Files\Network\NetworkTweaks.reg" >> "%LOG_FILE%" 2>&1

echo Configuring TCP global parameters

:: fastopen=enabled :          Speeds up successive TCP connections
:: fastopenfallback=enabled :  Allows fallback to standard TCP if Fast Open fails
:: rss=enabled :               Distributes network processing across multiple CPU cores
:: autotuninglevel=high :      Optimizes the TCP receive window for high-speed connections
for %%P in ("fastopen=enabled" "fastopenfallback=enabled" "rss=enabled" "autotuninglevel=high") do (
    echo  - %%~P
    netsh int tcp set global %%~P >> "%LOG_FILE%" 2>&1
)

echo Setting Cloudflare DNS on all connected interfaces
set DNS_IPv4_1=1.1.1.1
set DNS_IPv4_2=1.0.0.1
set DNS_IPv6_1=2606:4700:4700::1111
set DNS_IPv6_2=2606:4700:4700::1001
call :INTERFACE

echo Flushing DNS cache
ipconfig /flushdns >> "%LOG_FILE%" 2>&1

call :LOG NETWORK_MENU

:REV_NETWORK_TWEAKS
call :PATH "Network" "DefaultNetworkSettings"

echo. & echo Restoring default network registry settings
reg import "Files\Network\DefaultNetworkSettings.reg" >> "%LOG_FILE%" 2>&1

echo Resetting TCP global parameters to default
for %%P in ("fastopen=default" "fastopenfallback=default" "rss=default" "autotuninglevel=normal") do (
    echo  - %%~P
    netsh int tcp set global %%~P >> "%LOG_FILE%" 2>&1
)

call :DHCP

call :LOG NETWORK_MENU

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

:: Google DNS: Highly reliable and fast global infrastructure
if "%choice%"=="1" (
    set DNS_NAME=Google Public DNS
    set DNS_IPv4_1=8.8.8.8
    set DNS_IPv4_2=8.8.4.4
    set DNS_IPv6_1=2001:4860:4860::8888
    set DNS_IPv6_2=2001:4860:4860::8844
    goto SET_DNS
)

:: Cloudflare DNS: Focused on speed and strict user privacy
if "%choice%"=="2" (
    set DNS_NAME=Cloudflare DNS
    set DNS_IPv4_1=1.1.1.1
    set DNS_IPv4_2=1.0.0.1
    set DNS_IPv6_1=2606:4700:4700::1111
    set DNS_IPv6_2=2606:4700:4700::1001
    goto SET_DNS
)

:: Cloudflare Family: Blocks malware and adult content automatically
if "%choice%"=="3" (
    set DNS_NAME=Cloudflare Family DNS
    set DNS_IPv4_1=1.1.1.3
    set DNS_IPv4_2=1.0.0.3
    set DNS_IPv6_1=2606:4700:4700::1113
    set DNS_IPv6_2=2606:4700:4700::1003
    goto SET_DNS
)

:: AdGuard DNS: Filters out ads and trackers at the network level
if "%choice%"=="4" (
    set DNS_NAME=AdGuard DNS
    set DNS_IPv4_1=94.140.14.14
    set DNS_IPv4_2=94.140.15.15
    set DNS_IPv6_1=2a10:50c0::ad1:ff
    set DNS_IPv6_2=2a10:50c0::ad2:ff
    goto SET_DNS
)

:: Clean Browsing: Optimized for family safety and security filtering
if "%choice%"=="5" (
    set DNS_NAME=Clean Browsing DNS
    set DNS_IPv4_1=185.228.168.168
    set DNS_IPv4_2=185.228.169.168
    set DNS_IPv6_1=2a0d:2a00:1::
    set DNS_IPv6_2=2a0d:2a00:2::
    goto SET_DNS
)

:: Quad9 DNS: Strong emphasis on blocking malicious domains and phishing
if "%choice%"=="6" (
    set DNS_NAME=Quad9 DNS
    set DNS_IPv4_1=9.9.9.9
    set DNS_IPv4_2=149.112.112.112
    set DNS_IPv6_1=2620:fe::fe
    set DNS_IPv6_2=2620:fe::9
    goto SET_DNS
)

:: OpenDNS: Provides customizable web filtering and high uptime
if "%choice%"=="7" (
    set DNS_NAME=OpenDNS
    set DNS_IPv4_1=208.67.222.222
    set DNS_IPv4_2=208.67.220.220
    set DNS_IPv6_1=2620:119:35::35
    set DNS_IPv6_2=2620:119:53::53
    goto SET_DNS
)

if "%choice%"=="8" goto SET_DHCP
if "%choice%"=="9" goto DNS_SERVER_TEST
if "%choice%"=="10" goto DNS_STATUS
if "%choice%"=="0" goto NETWORK_MENU

call :INVALID "(0-10)" "DNS_MENU"

:SET_DNS
call :PATH "Network" "DNS"

echo. & echo Setting %DNS_NAME% server on all connected interfaces
call :INTERFACE

echo Flushing DNS cache
ipconfig /flushdns >> "%LOG_FILE%" 2>&1

call :LOG DNS_MENU

:SET_DHCP
call :PATH "Network" "DHCP"
cls
call :DHCP
call :LOG DNS_MENU

:DNS_SERVER_TEST
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\DNSTest.ps1"
call :GO DNS_MENU

:DNS_STATUS
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\DNSStatus.ps1"
call :GO DNS_MENU

:WIFI_PASSWORDS
call :CREATE_FILE "Network" "WifiPassword.log"
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\WifiPassword.ps1" "%TARGET_FILE%"
echo. & echo Wifi Password file saved in: %TARGET_FILE%
call :GO NETWORK_MENU

:NETWORK_RESET
call :CONFIRM "WARNING: This script will RESET ALL network configurations!"
if errorlevel 2 goto NETWORK_MENU

call :PATH "Network" "NetworkReset"
echo. & echo Stopping Network Services

:: Dhcp:      Obtains and renews IP configuration from DHCP servers
:: dnscache:  Temporarily stores DNS results to speed up queries
:: dot3svc:   Handles authentication for wired (Ethernet) network connections
:: netman:    Manages objects in the network
:: netprofm:  Identifies the networks the computer has connected to
:: nlasvc:    Collects and stores configuration information
:: WlanSvc:   Connects to Wi-Fi
:: WwanSvc:   Manages mobile broadband
for %%S in (dot3svc netman WlanSvc WwanSvc) do call :NET_CONTROL "%%S" "stop" >> "%LOG_FILE%" 2>&1

echo Resetting Network services to default startup
for %%S in (Dhcp dnscache nlasvc WlanSvc) do call :SC_CONFIGURE "%%S" "auto" >> "%LOG_FILE%" 2>&1
for %%S in (dot3svc netman netprofm WwanSvc) do call :SC_CONFIGURE "%%S" "demand" >> "%LOG_FILE%" 2>&1

echo Starting Network Services
for %%S in (dot3svc netman WlanSvc WwanSvc) do call :NET_CONTROL "%%S" "start" >> "%LOG_FILE%" 2>&1

:: Reset the core TCP/IP stack to factory defaults (rewrites registry keys)
echo Reset TCP/IP Stack
netsh int ip reset >> "%LOG_FILE%" 2>&1

:: Repair the Winsock Catalog (useful if internet is blocked by malware or bad drivers)
echo Reset Winsock catalog
netsh winsock reset >> "%LOG_FILE%" 2>&1

:: Clear any system-wide HTTP proxy settings that might redirect traffic
echo Reset WinHTTP proxy
netsh winhttp reset proxy >> "%LOG_FILE%" 2>&1

:: Reset IPv6 specific settings to their default state
echo Reset IPv6 settings
netsh interface ipv6 reset >> "%LOG_FILE%" 2>&1

:: Reset Windows Port Proxy configurations
echo Reset Port Proxies
netsh interface portproxy reset >> "%LOG_FILE%" 2>&1

:: Restore Windows Firewall to its default out-of-the-box rules
echo Reset Firewall Rules
netsh advfirewall reset >> "%LOG_FILE%" 2>&1

:: Clears the local cache used to optimize WAN traffic
echo Resetting BranchCache
netsh branchcache reset >> "%LOG_FILE%" 2>&1

:: Refresh NetBIOS names by purging and reloading the remote cache table
echo Refreshing NetBIOS names
nbtstat -RR >> "%LOG_FILE%" 2>&1

:: Clear the DNS Resolver cache to fix "Page Not Found" errors
echo Flushing DNS
ipconfig /flushdns >> "%LOG_FILE%" 2>&1

:: Clear the ARP (Address Resolution Protocol) cache to refresh local IP-to-MAC mappings
echo Cleaning ARP cache
arp -d * >> "%LOG_FILE%" 2>&1

:: Remove entries from the IPv6 neighbor cache (similar to ARP for IPv6)
echo Cleaning IPv6 Neighbor
netsh interface ipv6 delete neighbors >> "%LOG_FILE%" 2>&1

:: Clear the IPv6 destination cache to resolve routing issues
echo Cleaning IPv6 Destination Cache
netsh interface ipv6 delete destinationcache >> "%LOG_FILE%" 2>&1

:: Clear the Routing Table to remove static routes and corrupt gateway entries
echo Reset Routing Table
route -f >> "%LOG_FILE%" 2>&1

:: Release current DHCP IP addresses for all adapters
echo Releasing IP addresses
ipconfig /release >> "%LOG_FILE%" 2>&1
ipconfig /release6 >> "%LOG_FILE%" 2>&1

:: Restart all physically connected network interfaces
:: This effectively "plugs and unplugs" the cable via software
echo Restart all connected interfaces
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\RestartInterfaces.ps1"
timeout /t 3 /nobreak >nul

:: Request new IP addresses from the router/DHCP server
echo Renewing IP addresses
ipconfig /renew >> "%LOG_FILE%" 2>&1
ipconfig /renew6  >> "%LOG_FILE%" 2>&1

:: Refresh DHCP leases and re-register DNS names with the server
echo Registering DNS name
ipconfig /registerdns >> "%LOG_FILE%" 2>&1

call :RESTART
call :LOG NETWORK_MENU

:NETWORK_INFO
call :PATH "Network" "NetworkInfo"
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\NetworkInfo.ps1" "%LOG_FILE%"
call :LOG NETWORK_MENU

:PROGRAMS_MANAGER_MENU
cls & echo. & echo.
echo                        ------------------------------ Programs Manager ---------------------------
echo.
echo                         [1] Download Programs                                 [2] Update Programs
echo.
echo                         [3] Download Microsoft Office                         [4] Remove ALL MS Apps
echo.
echo                         [5] Programs Info                                     [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto WHERE_CHOCO
if "%choice%"=="2" goto UPDATE_PROGRAMS
if "%choice%"=="3" goto DOWNLOAD_MO
if "%choice%"=="4" goto REMOVE_MS
if "%choice%"=="5" goto PROGRAMS_INFO
if "%choice%"=="0" goto MAIN_MENU

call :INVALID "(0-5)" "PROGRAMS_MANAGER_MENU"

:WHERE_CHOCO
:: Check if Chocolatey (Package Manager) is already installed
where choco >nul 2>&1 && goto PROGRAMS_MENU_VAR

:: Install Chocolatey If not found
cls & echo Install Chocolatey package manager
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Programs\InstallChoco.ps1"

:: Update the environment (PATH) in the current CMD session
if exist "%ALLUSERSPROFILE%\chocolatey\bin" set "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"

call :CHECK_CHOCO


:PROGRAMS_MENU_VAR
set "ON=(YES)"
set "OFF=(NO)"

:: Initialize all 18 options to "OFF" by default
for %%A in (1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18) do set "OPT%%A=%OFF%"

:PROGRAMS_MENU
cls & echo. & echo.
echo                        ----------------------------------- Programs -----------------------------------
echo.
echo                           [1] Google Chrome            [7] XnViewMP               [13] VC++ (2015-2022)
echo.
echo                           [2] Brave                    [8] Sumatra PDF            [14] DirectX
echo.
echo                           [3] WinRAR                   [9] Notepad++              [15] Virtual Box
echo.
echo                           [4] 7-Zip                    [10] VS Code               [16] IObit Unlocker
echo.
echo                           [5] K-Lite Codec             [11] Git                   [17] AutoHotkey
echo.
echo                           [6] IrfanView                [12] qbittorrent           [18] MEGA
echo.
echo                        --------------------------------------------------------------------------------
echo.
echo                           [A] Select All              [D] Deselect All           [0] Back
echo.

:: Display a real-time list of what the user has selected
echo. & echo Selected:
call :SHOW_SELECTED

echo. & set "choice=" & set /p "choice=--> Select an option(s) and press [S] to Start: "
if "%choice%"=="" goto PROGRAMS_MENU
if "%choice%"=="0" goto PROGRAMS_MANAGER_MENU
if /i "%choice%"=="S" goto INSTALL_PROGRAMS
if /i "%choice%"=="A" goto SELECT_ALL
if /i "%choice%"=="D" goto DESELECT_ALL

:: Process numerical input to toggle selections (0-18)
set "tokens=%choice:,= %"
for %%G in (%tokens%) do (
    for %%N in (1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18) do if "%%G"=="%%N" call :TOGGLE_SINGLE OPT%%N
)
goto PROGRAMS_MENU

:: Set "ON" for all programs
:SELECT_ALL
for /L %%i in (1,1,18) do set "OPT%%i=%ON%"
goto PROGRAMS_MENU

:: Set "OFF" for all programs
:DESELECT_ALL
for /L %%i in (1,1,18) do set "OPT%%i=%OFF%"
goto PROGRAMS_MENU

:INSTALL_PROGRAMS
cls
call :IS_ON OPT1  && call :TRY_INSTALL googlechrome "Google Chrome"
call :IS_ON OPT2  && call :TRY_INSTALL brave "Brave"
call :IS_ON OPT3  && call :TRY_INSTALL winrar "WinRAR"
call :IS_ON OPT4  && call :TRY_INSTALL 7zip.install "7-Zip"
call :IS_ON OPT5  && call :TRY_INSTALL k-litecodecpack-standard "K-Lite Codec"
call :IS_ON OPT6  && call :TRY_INSTALL irfanview "IrfanView"
call :IS_ON OPT7  && call :TRY_INSTALL xnviewmp.install "XnView MP"
call :IS_ON OPT8  && call :TRY_INSTALL sumatrapdf.install "Sumatra PDF"
call :IS_ON OPT9  && call :TRY_INSTALL notepadplusplus.install "Notepad++"
call :IS_ON OPT10 && call :TRY_INSTALL vscode.install "Visual Studio Code"
call :IS_ON OPT11 && call :TRY_INSTALL git "Git"
call :IS_ON OPT12 && call :TRY_INSTALL qbittorrent "qbittorrent"
call :IS_ON OPT13 && call :TRY_INSTALL vcredist140 "VC++ Redistributables (2015-2022)"
call :IS_ON OPT14 && call :TRY_INSTALL directx "DirectX"
call :IS_ON OPT15 && call :TRY_INSTALL virtualbox "Virtual Box"
call :IS_ON OPT16 && call :TRY_INSTALL io-unlocker "IObit Unlocker"
call :IS_ON OPT17 && call :TRY_INSTALL autohotkey "AutoHotkey"
call :IS_ON OPT18 && call :TRY_INSTALL megasync "MEGA"

call :GO PROGRAMS_MANAGER_MENU

:TRY_INSTALL
echo. & echo Installing: %~2
choco install %~1 -y

if %errorlevel% neq 0 (
    echo. & echo Failed to install: %~2  
    call :CHOICE "Do you want to ignore checksum and retry?"
    if errorlevel 2 (
	    exit /b 1  
    ) else (
        echo. & echo Retrying with --ignore-checksums
        choco install %~1 --ignore-checksums -y
    )
)
goto :eof

:: Check if a flag is set to (YES)
:IS_ON
if "!%1!"=="%ON%" exit /b 0
exit /b 1

:: Switch (YES) to (NO) and vice-versa
:TOGGLE_SINGLE
if "!%1!"=="%ON%" (
    set "%1=%OFF%"
) else (
    set "%1=%ON%"
)
goto :eof

:: List of current selections to the screen
:SHOW_SELECTED
set "ANY=0"
if "!OPT1!"=="%ON%" echo  - Google Chrome & set "ANY=1"
if "!OPT2!"=="%ON%" echo  - Brave & set "ANY=1"
if "!OPT3!"=="%ON%" echo  - WinRAR & set "ANY=1"
if "!OPT4!"=="%ON%" echo  - 7-Zip & set "ANY=1"
if "!OPT5!"=="%ON%" echo  - K-Lite Codec & set "ANY=1"
if "!OPT6!"=="%ON%" echo  - IrfanView & set "ANY=1"
if "!OPT7!"=="%ON%" echo  - XnView MP & set "ANY=1"
if "!OPT8!"=="%ON%" echo  - Sumatra PDF & set "ANY=1"
if "!OPT9!"=="%ON%" echo  - Notepad++ & set "ANY=1"
if "!OPT10!"=="%ON%" echo  - Visual Studio Code & set "ANY=1"
if "!OPT11!"=="%ON%" echo  - Git & set "ANY=1"
if "!OPT12!"=="%ON%" echo  - qbittorrent & set "ANY=1"
if "!OPT13!"=="%ON%" echo  - VC++ Redistributables & set "ANY=1"
if "!OPT14!"=="%ON%" echo  - DirectX & set "ANY=1"
if "!OPT15!"=="%ON%" echo  - Virtual Box & set "ANY=1"
if "!OPT16!"=="%ON%" echo  - IObit Unlocker & set "ANY=1"
if "!OPT17!"=="%ON%" echo  - AutoHotkey & set "ANY=1"
if "!OPT18!"=="%ON%" echo  - MEGA & set "ANY=1"
if "!ANY!"=="0" echo  - No programs selected
goto :eof

:: Chocolatey must be available to upgrade the programs
:UPDATE_PROGRAMS
cls & echo Update all installed programs from Chocolatey
call :CHECK_CHOCO

:: Execute the upgrade command for every package managed by Chocolatey
choco upgrade all -y
call :GO PROGRAMS_MANAGER_MENU

:DOWNLOAD_MO
start "" cmd /c "Files\Programs\office.bat"
goto PROGRAMS_MANAGER_MENU

:REMOVE_MS
call :CONFIRM "WARNING: This will remove ALL Microsoft Store apps!"
if errorlevel 2 goto PROGRAMS_MANAGER_MENU

powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Programs\Remove_All_MS.ps1"
call :GO PROGRAMS_MANAGER_MENU

:: Get information about all installed and startup programs
:PROGRAMS_INFO
call :PATH "Programs" "ProgramsInfo"
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Programs\ProgramsInfo.ps1" "%LOG_FILE%"
call :LOG PROGRAMS_MANAGER_MENU

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
    goto SUB_MENU
)
if "%choice%"=="3" (
    set ROUTINE=DIS_NOTIFICATION
    set REV_ROUTINE=ENA_NOTIFICATION
    set APPLY=Disable notification center
    set REVERT=Enable notification center
    set MENU=CUSTOMIZATION_MENU
    goto SUB_MENU
)
if "%choice%"=="4" (
    set ROUTINE=HIDE_SHORTCUT_ARROW
    set REV_ROUTINE=SHOW_SHORTCUT_ARROW
    set APPLY=Remove shortcut arrow
    set REVERT=Show shortcut arrow
    set MENU=CUSTOMIZATION_MENU
    goto SUB_MENU
)
if "%choice%"=="5" (
    set ROUTINE=NUM_LOCK_OFF
    set REV_ROUTINE=NUM_LOCK_ON
    set APPLY=Disable num lock when logging in
    set REVERT=Enable num lock when logging in
    set MENU=CUSTOMIZATION_MENU
    goto SUB_MENU
)
if "%choice%"=="6" (
    set ROUTINE=UTC
    set REV_ROUTINE=LOCAL_TIME
    set APPLY=Setting hardware clock to UTC
    set REVERT=Setting hardware clock to Local Time
    set MENU=CUSTOMIZATION_MENU
    goto SUB_MENU
)
if "%choice%"=="7" (
    set ROUTINE=POWER_SETTINGS
    set REV_ROUTINE=REMOVE_POWER_SETTINGS
    set APPLY=Creating 'Powerful settings' folder on your Desktop
    set REVERT=Removing 'Powerful settings' folder from your Desktop
    set MENU=CUSTOMIZATION_MENU
    goto SUB_MENU
)
if "%choice%"=="8" (
    set ROUTINE=TRASH
    set REV_ROUTINE=DEF_TRASH
    set APPLY=Disable unnecessary Windows features
    set REVERT=Default unnecessary Windows features
    set MENU=CUSTOMIZATION_MENU
    goto SUB_MENU
)
if "%choice%"=="9" (
    set ROUTINE=PHOTO_VIEWER
    set REV_ROUTINE=REMOVE_PHOTO_VIEWER
    set APPLY=Restore classic Windows photo viewer
    set REVERT=Remove classic Windows photo viewer
    set MENU=CUSTOMIZATION_MENU
    goto SUB_MENU
)
if "%choice%"=="10" goto CONTEXT_MENU
if "%choice%"=="0" goto MAIN_MENU

call :INVALID "(0-10)" "CUSTOMIZATION_MENU"

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
    goto SUB_MENU
)
if "%choice%"=="2" (
    set ROUTINE=SHOW_HIDDEN
    set REV_ROUTINE=DIS_HIDDEN
    set APPLY=Show hidden files
    set REVERT=Hide hidden files
    set MENU=FILE_EXPLORER_MENU
    goto SUB_MENU
)
if "%choice%"=="3" (
    set ROUTINE=HIDE_RECENT
    set REV_ROUTINE=SHOW_RECENT
    set APPLY=Hide recent files
    set REVERT=Show recent files
    set MENU=FILE_EXPLORER_MENU
    goto SUB_MENU
)
if "%choice%"=="4" (
    set ROUTINE=ON_THIS_PC
    set REV_ROUTINE=ON_QUICK_ACCESS
    set APPLY=Open file explorer on: This PC
    set REVERT=Open file explorer on: Quick Access
    set MENU=FILE_EXPLORER_MENU
    goto SUB_MENU
)
if "%choice%"=="0" goto CUSTOMIZATION_MENU

call :INVALID "(0-4)" "FILE_EXPLORER_MENU"

:: Enable the visibility of file extensions
:SHOW_EXTENSIONS
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f >nul 2>&1
call :GO FILE_EXPLORER_MENU

:: Hide file extensions
:HIDE_EXTENSIONS
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 1 /f >nul 2>&1
call :GO FILE_EXPLORER_MENU

:: Show both hidden files and protected operating system files
:SHOW_HIDDEN
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSuperHidden /t REG_DWORD /d 1 /f >nul 2>&1
call :GO FILE_EXPLORER_MENU

:: Hide hidden files and protected system files
:DIS_HIDDEN
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSuperHidden /t REG_DWORD /d 0 /f >nul 2>&1
call :GO FILE_EXPLORER_MENU

:: Disable "Recent Files" and "Frequent Folders" in Quick Access and the Start Menu
:HIDE_RECENT
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowRecent /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackDocs /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackProgs /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "ShowFrequent" /t REG_DWORD /d 0 /f >nul 2>&1
goto ON_THIS_PC

:: Re-enable "Recent Files" and "Frequent Folders" history tracking
:SHOW_RECENT
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowRecent /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackDocs /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackProgs /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "ShowFrequent" /t REG_DWORD /d 1 /f >nul 2>&1
goto ON_QUICK_ACCESS

:: Configure File Explorer to open to "This PC" by default
:ON_THIS_PC
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 1 /f >nul 2>&1
call :GO FILE_EXPLORER_MENU

:: Configure File Explorer to open to "Quick Access" by default
:ON_QUICK_ACCESS
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 2 /f >nul 2>&1
call :GO FILE_EXPLORER_MENU

:: Enable System-wide Dark Mode for both Apps and the Windows Taskbar/Start Menu
:DARK_MODE
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Enable Light Mode for Apps while keeping System components (Taskbar) Dark
:LIGHT_MODE
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Disable notifications
:DIS_NOTIFICATION
echo. & echo Disabling notification services
for %%S in (WpnService WpnUserService) do call :SC_CONFIGURE "%%S" "disabled" >nul 2>&1

echo Disabling notification via registry
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v DisableNotificationCenter /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 0 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Re-enable notification
:ENA_NOTIFICATION
echo. & echo Enabling notification services
for %%S in (WpnService WpnUserService) do call :SC_CONFIGURE "%%S" "auto" >nul 2>&1

echo Enabling notification via registry
reg delete "HKLM\Software\Policies\Microsoft\Windows\Explorer" /v DisableNotificationCenter /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 1 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Remove the small arrow icon that appears on desktop shortcuts
:HIDE_SHORTCUT_ARROW
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons" /v 29 /t REG_EXPAND_SZ /d "%SystemRoot%\System32\imageres.dll,197" /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v link /t REG_BINARY /d 00000000 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Restore the default Windows shortcut arrow icon
:SHOW_SHORTCUT_ARROW
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons" /v 29 /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v link /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Ensure NumLock is OFF at the login screen and for the current user
:NUM_LOCK_OFF
reg add "HKCU\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 0 /f >nul 2>&1
reg add "HKU\.DEFAULT\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 2147483648 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Ensure NumLock is ON at the login screen and for the current user
:NUM_LOCK_ON
reg add "HKCU\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 2 /f >nul 2>&1
reg add "HKU\.DEFAULT\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 2147483650 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Set the Hardware Clock to UTC (recommended for Dual-Boot with Linux)
:UTC
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Set the Hardware Clock to Local Time
:LOCAL_TIME
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Create the "God Mode" folder on the desktop (access to all Windows settings in one list)
:POWER_SETTINGS
call :MKDIR_PROMPT "%USERPROFILE%\Desktop\Powerful Settings.{ED7BA470-8E54-465E-825C-99712043E01C}"
call :GO CUSTOMIZATION_MENU

:: Delete the "God Mode" folder from the desktop
:REMOVE_POWER_SETTINGS
rd /s /q "%USERPROFILE%\Desktop\Powerful Settings.{ED7BA470-8E54-465E-825C-99712043E01C}" >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Disable Trash feature
:TRASH
reg import "Files\Customization\DisableTrash.reg" >nul 2>&1
reg import "Files\Security\DisableTelemetry.reg" >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Restore default Windows Trash
:DEF_TRASH
reg import "Files\Customization\DefaultTrash.reg" >nul 2>&1
reg import "Files\Security\DefaultTelemetry.reg" >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Restore the classic Windows Photo Viewer
:PHOTO_VIEWER
reg import "Files\Customization\RestoreClassicPhotoViewer.reg" >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Remove the classic Windows Photo Viewer registry entries
:REMOVE_PHOTO_VIEWER
reg import "Files\Customization\RemoveClassicPhotoViewer.reg" >nul 2>&1
call :GO CUSTOMIZATION_MENU

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
    goto SUB_MENU
)
if "%choice%"=="2" (
    set ROUTINE=CMD_CONTEXT_ADMIN
    set REV_ROUTINE=REV_CMD_CONTEXT_ADMIN
    set APPLY=Add "Open CMD Here (Admin)" options to context menu
    set REVERT=Remove option
    set MENU=CONTEXT_MENU
    goto SUB_MENU
)
if "%choice%"=="3" (
    set ROUTINE=RESTART_EXPLORER
    set REV_ROUTINE=REV_RESTART_EXPLORER
    set APPLY=Add "Restart Explorer" option to context menu
    set REVERT=Remove option
    set MENU=CONTEXT_MENU
    goto SUB_MENU
)
if "%choice%"=="4" (
    set ROUTINE=KILL_FROZEN
    set REV_ROUTINE=REV_KILL_FROZEN
    set APPLY=Add "Kill frozen process" option to context menu
    set REVERT=Remove option
    set MENU=CONTEXT_MENU
    goto SUB_MENU
)
if "%choice%"=="0" goto CUSTOMIZATION_MENU

call :INVALID "(0-4)" "CONTEXT_MENU"

:: Add the "Open Command Prompt Here"
:CMD_CONTEXT
:: Define the menu text and add the cmd icon
reg add "HKCU\Software\Classes\Directory\shell\OpenCmdHere" /ve /d "Open CMD Here" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\shell\OpenCmdHere" /v "Icon" /d "cmd.exe" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\shell\OpenCmdHere\command" /ve /d "cmd.exe /k pushd \"%%1\"" /f >nul 2>&1

:: Repeat the process for the background
reg add "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHere" /ve /d "Open CMD Here" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHere" /v "Icon" /d "cmd.exe" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHere\command" /ve /d "cmd.exe /k pushd \"%%V\"" /f >nul 2>&1
call :GO CONTEXT_MENU

:: Remove "Open Command Prompt Here"
:REV_CMD_CONTEXT
reg delete "HKCU\Software\Classes\Directory\shell\OpenCmdHere" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHere" /f >nul 2>&1
call :GO CONTEXT_MENU

:: Add "Open Command Prompt Here (Admin)" to folder and background context menus
:CMD_CONTEXT_ADMIN
:: Define the menu text and add the UAC shield icon
reg add "HKCU\Software\Classes\Directory\shell\OpenCmdHereAdmin" /ve /d "Open CMD Here (Admin)" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\shell\OpenCmdHereAdmin" /v "HasLUAShield" /t REG_SZ /d "" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\shell\OpenCmdHereAdmin" /v "Icon" /d "cmd.exe,0" /f >nul 2>&1

:: Use PowerShell to trigger a CMD process with 'RunAs' (Administrator) privileges in the current directory
reg add "HKCU\Software\Classes\Directory\shell\OpenCmdHereAdmin\command" /ve /d "powershell -Command \"Start-Process cmd -ArgumentList '/s','/k','pushd %%V' -Verb RunAs\"" /f >nul 2>&1

:: Repeat the process for the background of a folder (right-clicking on empty space)
reg add "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHereAdmin" /ve /d "Open CMD Here (Admin)" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHereAdmin" /v "HasLUAShield" /t REG_SZ /d "" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHereAdmin" /v "Icon" /d "cmd.exe" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHereAdmin\command" /ve /d "powershell -Command \"Start-Process cmd -ArgumentList '/s','/k','pushd %%V' -Verb RunAs\"" /f >nul 2>&1
call :GO CONTEXT_MENU

:: Remove the "Open Command Prompt Here (Admin)"
:REV_CMD_CONTEXT_ADMIN
reg delete "HKCU\Software\Classes\Directory\shell\OpenCmdHereAdmin" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHereAdmin" /f >nul 2>&1
call :GO CONTEXT_MENU

:: Add "Restart Explorer" to the Desktop right-click menu
:RESTART_EXPLORER
reg add "HKCU\Software\Classes\DesktopBackground\Shell\RestartExplorer" /ve /d "Restart Explorer" /f >nul 2>&1
reg add "HKCU\Software\Classes\DesktopBackground\Shell\RestartExplorer" /v "Icon" /d "explorer.exe,0" /f >nul 2>&1

:: The command kills the explorer.exe process and immediately restarts it
reg add "HKCU\Software\Classes\DesktopBackground\Shell\RestartExplorer\command" /ve /d "cmd.exe /c taskkill /F /IM explorer.exe >nul 2>&1 & start explorer.exe" /f >nul 2>&1
call :GO CONTEXT_MENU

:: Remove the "Restart Explorer" right-click menu
:REV_RESTART_EXPLORER
reg delete "HKCU\Software\Classes\DesktopBackground\Shell\RestartExplorer" /f >nul 2>&1
call :GO CONTEXT_MENU

:: Add "Kill frozen process" to the Desktop right-click menu
:KILL_FROZEN
reg add "HKCU\Software\Classes\DesktopBackground\Shell\KillNotResponding" /v "MUIVerb" /d "Kill frozen process" /f >nul 2>&1
reg add "HKCU\Software\Classes\DesktopBackground\Shell\KillNotResponding" /v "Icon" /d "taskmgr.exe,0" /f >nul 2>&1

:: Targets only processes with the window status "NOT RESPONDING"
reg add "HKCU\Software\Classes\DesktopBackground\Shell\KillNotResponding\Command" /ve /d "cmd.exe /C taskkill.exe /F /FI \"status eq NOT RESPONDING\"" /f >nul 2>&1
call :GO CONTEXT_MENU

:: Remove the "Kill frozen process" right-click menu
:REV_KILL_FROZEN
reg delete "HKCU\Software\Classes\DesktopBackground\Shell\KillNotResponding" /f >nul 2>&1
call :GO CONTEXT_MENU

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
if "%choice%"=="4" goto SYSTEM_INFO
if "%choice%"=="0" goto MAIN_MENU

call :INVALID "(0-4)" "SYSTEM_MENU"

:RESTORE_POINT
:: RestorePointType: MODIFY_SETTINGS indicates settings were changed
cls & echo Creating a System Restore Point
powershell -Command "Checkpoint-Computer -Description 'Hello world' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop"
if %errorlevel% equ 0 call :GO SYSTEM_MENU

call :PATH "System" "RestorePoint"

:: If Creating failed (errorlevel>0)
echo Creating a restore point failed. Attempting to fix system dependencies

echo Enable System Restore on the C: drive
powershell -Command "Enable-ComputerRestore -Drive 'C:\'" >> "%LOG_FILE%" 2>&1

:: Enable System Restore via registry if they were disabled by policy
echo. & echo Enabling System Restore via registry
reg import "Files\System\EnableRestorePoint.reg" >> "%LOG_FILE%" 2>&1

echo Stopping restore point services

:: VSS:      Volume Shadow Copy Service (Manages data backup/snapshots)
:: swprv:    Microsoft Software Shadow Copy Provider (Coordinates snapshot creation)
for %%S in (VSS swprv) do call :NET_CONTROL "%%S" "stop" >> "%LOG_FILE%" 2>&1

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
for %%S in (VSS swprv) do (
    call :SC_CONFIGURE "%%S" "demand" >> "%LOG_FILE%" 2>&1
    call :NET_CONTROL "%%S" "start" >> "%LOG_FILE%" 2>&1
)

:: RpcSs:         Remote Procedure Call (RPC) Service (Manages inter-process communication)
:: EventLog:      Windows Event Log Service (Records system, security, and application events)
:: EventSystem:   COM+ Event System (Distributes system events to subscribed components)
:: Schedule:      Task Scheduler Service (Manages scheduled tasks, including automatic restore point creation)
for %%S in (RpcSs CryptSvc EventLog EventSystem Schedule) do (
    call :SC_CONFIGURE "%%S" "auto" >> "%LOG_FILE%" 2>&1
    call :NET_CONTROL "%%S" "start" >> "%LOG_FILE%" 2>&1
)

echo Checking VSS Writers status
vssadmin list writers >> "%LOG_FILE%" 2>&1

echo Attempting to create System Restore Point again
powershell -Command "Checkpoint-Computer -Description 'Hello world' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop" >> "%LOG_FILE%" 2>&1
if %errorlevel% equ 0 (
    echo System Restore Point created successfully
) else (
    echo Creating system restore point has failed after troubleshooting 
)
call :LOG SYSTEM_MENU

:REG_BACK
cls
call :PATH "System" "FullRegistryBackup"
call :CREATE_FOLDER "System" "FullRegistryBackup"
if %errorlevel% equ 1 call :GO SYSTEM_MENU

set "SUCCESS_COUNT=0"

:: Define the main system Hives for binary export
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
        reg save "%%B" "%BACKUP_DIR%\%%C.hive" /y >>"%LOG_FILE%" 2>&1      
        if !errorlevel! equ 0 set /a SUCCESS_COUNT+=1
    )
)

if exist "%BACKUP_DIR%\*.hive" (
    echo. & echo Backup Process Finished. Total Success: !SUCCESS_COUNT!/7 
    call :CHOICE "Compress folder?"
	echo.
    if errorlevel 2 (
        echo Backup saved in: %BACKUP_DIR%
    ) else (
        set "PROCEED_COMPRESSION=1"
        if exist "%BACKUP_DIR%.zip" (
            call :CHOICE "FullRegistryBackup.zip already exists. Do you want to delete it?"
            if errorlevel 2 (
                echo Keeping the existing archive. Compression cancelled.
                set "PROCEED_COMPRESSION=0"
            )
        )
        
        if !PROCEED_COMPRESSION! equ 1 (
            powershell -NoProfile -ExecutionPolicy Bypass -File "Files\System\CompressHiveFiles.ps1" "%BACKUP_DIR%"
        )
    )
) else (
    echo No hive files were created. Backup failed
)
call :LOG SYSTEM_MENU

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

call :INVALID "(0-2)" "ACTIVATION_MENU"

:: Activating Windows and Microsoft Office using MAS script
:RUN_ACTIVATION
cls & echo Launching Microsoft Activation Script (MAS) to activate Windows and Office
echo The script will open in a new window. Follow the on-screen instructions.
powershell -NoP -EP Bypass -c "irm https://get.activated.win | iex"
call :GO ACTIVATION_MENU

:: Check if the Machine is Activated or not
:CHECK_ACTIVATION
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\System\ActivationStatus.ps1"
call :GO ACTIVATION_MENU

:: Display basic system information 
:SYSTEM_INFO
call :PATH "System" "SystemInfo"
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\System\SystemInfo.ps1" "%LOG_FILE%"
call :LOG SYSTEM_MENU

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

call :INVALID "(0-7)" "TOOLS_MENU"

:: Scan and verify the integrity of all protected system files and repair corrupted
:SFC_SCAN
cls & echo Running sfc scan
sfc /scannow
call :GO TOOLS_MENU

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

call :INVALID "(0-4)" "DISM_MENU"

:: Perform a quick check to see if the OS has already flagged any corruption
:DISM_CHECK_HEALTH
cls & echo Performing quick health check of Windows image
dism /Online /Cleanup-Image /CheckHealth
call :GO DISM_MENU

:: This does not fix errors, it only reports them
:DISM_SCAN_HEALTH
cls & echo Performing deep scan of Windows image
dism /Online /Cleanup-Image /ScanHealth
call :GO DISM_MENU

:: Repair the Windows Image by downloading healthy files from Windows Update
:DISM_RESTORE_HEALTH
cls & echo Fix Windows component
dism /Online /Cleanup-Image /RestoreHealth
call :GO DISM_MENU

:: Clean up the WinSxS folder by removing superseded (old) versions of components
:DISM_COMPONENT_CLEANUP
call :CONFIRM "WARNING: This will permanently remove rollback capability for Windows Updates!"
if errorlevel 2 goto DISM_MENU

echo Cleaning Windows components
dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase
call :GO DISM_MENU

:: Launch Windows Defragment
:DEFRAG
start "" dfrgui.exe
goto TOOLS_MENU

:CHKDSK
cls & echo Available drives on your system:

:: List all existing drive letters
for %%d in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist %%d:\ echo %%d\:
)

echo. & echo Enter drive letter to check
echo Enter "0" to go back

set "drive=" & set /p "drive= "
if "%drive%"=="0" goto TOOLS_MENU

:: Handle empty input
if not defined drive goto CHKDSK

:: Remove quotes if present
set "drive=%drive:"=%"

:: Trim to first character only
set "drive=%drive:~0,1%"

:: Validate that the drive exists
if not exist "%drive%:\" (
    echo. & echo Invalid drive letter: %drive%
    pause
    goto CHKDSK
)

:: Convert to uppercase
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

call :INVALID "(0-3)" "CHKDSK_MENU"

:: Scans for errors but does not fix anything
:DISK_STATUS
cls & echo Running read-only CHKDSK on drive %drive%:\ to check for errors
timeout /t 2 >nul
chkdsk %drive%:
call :GO CHKDSK_MENU

:FIX_FILE
cls & echo Running CHKDSK with /f option on drive %drive%:\ to fix file system errors
timeout /t 2 >nul

:: /f: Fixes errors on the disk
chkdsk %drive%: /f
call :GO CHKDSK_MENU

:FIX_SECTORS
cls & echo Running CHKDSK with /r option on drive %drive%:\ to find bad sectors and recover data
timeout /t 2 >nul

:: /r: Locates bad sectors and recovers readable information
chkdsk %drive%: /r
call :GO CHKDSK_MENU

:: Launch Memory Diagnostic
:MEMORY_DIAG
start "" mdsched.exe
goto TOOLS_MENU

:: Launch Disk Cleanup
:CLEAN_MGR
cleanmgr.exe /d %SYSTEMDRIVE% /VERYLOWDISK
goto TOOLS_MENU

:: Delete "%ProgramData%\WinTweaks" folder
:DELETE_SCRIPT_DATA
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Tools\DeleteScriptData.ps1"
call :GO TOOLS_MENU


:OTHER_MENU
cls
echo.
echo.
echo                        ---------------------------------- OTHER ----------------------------------
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

call :INVALID "(0-3)" "OTHER_MENU"

:: Launch CTT
:CTT
cls & echo Running Chris Titus tool
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb https://christitus.com/win | iex"
call :GO OTHER_MENU

:: Download and launch O&O Shutup 10 ++
:OO_SHUTUP
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Other\DownloadOOShutup.ps1"
call :GO OTHER_MENU

:: Download and launch Speedtest CLI 
:NET_SPEED_TEST
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Other\DownloadNetSpeed.ps1"
call :GO OTHER_MENU


:: ----------------------------------------------------------------< FUNCTIONS >----------------------------------------------------------------
:SET_TASKS
:: %~1 = Action (Enable/Disable)
:: %~2 = Path to text file containing task names
for /f "usebackq delims=" %%i in ("%~2") do (
    set "TASK_NAME=%%i"
    set "TASK_RESULT=[SUCCESS]"

    :: Verify the task if exists
    schtasks /query /tn "%%i" >nul 2>&1
    if errorlevel 1 (
        set "TASK_RESULT=[NOT_FOUND]"
    ) else (
        :: Apply the change (Disable or Enable)
        if /i "%~1"=="Disable" (
            schtasks /change /tn "%%i" /disable >nul 2>&1
        ) else (
            schtasks /change /tn "%%i" /enable >nul 2>&1
        )

        :: Check if the command is failed
        if errorlevel 1 (
            set "TASK_RESULT=[FAILED]"
        )
    )

    :: Log the result for every single task
    echo !TASK_RESULT!: !TASK_NAME! >>"%LOG_FILE%"
)
goto :eof

:RUNNING_BROWSERS
:: List of browser processes to check
set "BROWSERS=chrome.exe brave.exe msedge.exe firefox.exe"
set "BROWSERS_OPEN=0"

:: Check if any browser is currently running
for %%A in (%BROWSERS%) do (
    tasklist /FI "IMAGENAME eq %%A" 2>nul | find /I "%%A" >nul
    if not errorlevel 1 (
	    echo %%A are currently running
        set "BROWSERS_OPEN=1"
    )
)
goto :eof

:CLEAN_BROWSER
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
goto :eof

:CLEANING_FUNCTION
echo Cleaning Temp folders
for %%F in ("%TEMP%" "%SYSTEMROOT%\TEMP") do (
    if exist "%%~F" (
        del /f /q "%%~F\*" >nul 2>&1
        for /d %%D in ("%%~F\*") do (
            rd /s /q "%%D" >nul 2>&1
        )
    )
)

:: Clear the "Recent Items" list shown in File Explorer
echo Clearing Recent Files
del /f /q "%APPDATA%\Microsoft\Windows\Recent\*.lnk" >nul 2>&1

:: Rebuild icon and thumbnail cache
echo Rebuilding Thumbnail and Icon cache
taskkill /F /IM explorer.exe >nul 2>&1
timeout /t 2 /nobreak >nul
del /f /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache*.db" >nul 2>&1
del /f /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache*.db" >nul 2>&1
start explorer.exe >nul 2>&1

:: Delete PowerShell command history
echo Clearing PowerShell command history
del /f /q "%APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" >nul 2>&1

call :CHOICE "Run Disk Cleanup to complete the cleaning?"
if not errorlevel 2 if errorlevel 1 (
    echo Running Disk Cleanup
	cleanmgr.exe /d %SYSTEMDRIVE% /VERYLOWDISK
)

:: Force empty the Recycle Bin for all drives
echo Emptying Recycle Bin
powershell -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue"
goto :eof

:DHCP
echo Setting DHCP on all connected interfaces

:: Find all active network adapters
for /f "delims=" %%b in ('powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\GetInterfaces.ps1"') do (
    echo  - Resetting: %%~b
    
    :: Revert IPv4 to obtain an IP address automatically from the router
    netsh interface ipv4 set address name="%%~b" source=dhcp >> "%LOG_FILE%" 2>&1
    
    :: Revert IPv4 to obtain DNS servers automatically
    netsh interface ipv4 set dnsservers name="%%~b" source=dhcp >> "%LOG_FILE%" 2>&1

    :: Revert IPv6 to obtain DNS servers automatically
    netsh interface ipv6 set dnsservers name="%%~b" source=dhcp >> "%LOG_FILE%" 2>&1
)

echo Flushing DNS cache
ipconfig /flushdns >> "%LOG_FILE%" 2>&1
goto :eof

:NET_CONTROL
:: %~1 = Service Name
:: %~2 = Action (stop or start)

:: Check if the service exists
sc query "%~1" >nul 2>&1
if !errorlevel! neq 0 (
    echo [NOT FOUND]: %~1
    goto :eof
)

:: Execute the action based on the requested operation (stop or start)
if /i "%~2"=="stop" (
    :: Check if the service is already stopped
    sc query "%~1" | find /i "STOPPED" >nul
    if !errorlevel! equ 0 (
        echo [ALREADY STOPPED]: %~1
    ) else (
        :: Try to stop the service
        net stop "%~1" >nul 2>&1
        if !errorlevel! equ 0 (
            echo [SUCCESS]: %~1 _ %~2 
        ) else (
            echo [FAILED]: %~1 _ %~2 
        )
    )
) else if /i "%~2"=="start" (
    :: Check if the service is already running
    sc query "%~1" | find /i "RUNNING" >nul
    if !errorlevel! equ 0 (
        echo [ALREADY RUNNING]: %~1
    ) else (
        :: Try to start the service
        net start "%~1" >nul 2>&1
        if !errorlevel! equ 0 (
            echo [SUCCESS]: %~1 _ %~2 
        ) else (
            echo [FAILED]: %~1 _ %~2 
        )
    )
)
goto :eof

:SC_CONFIGURE
:: %~1 = Service Name
:: %~2 = Start Type
sc query %~1 >nul 2>&1
if !errorlevel! equ 0 (
    sc config %~1 start= %~2 >nul 2>&1
    if !errorlevel! equ 0 (
        echo [SUCCESS]: %~1 _ %~2
    ) else (
        echo [FAILED]: %~1 _ %~2
    )
) else (
    echo [NOT FOUND]: %~1
)
goto :eof

:INTERFACE
for /f "delims=" %%b in ('powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\GetInterfaces.ps1"') do (
    echo  - Configure: %%~b
    
    :: Set the Primary and Secondary IPv4 DNS server
    netsh interface ipv4 set dns name="%%~b" static %DNS_IPv4_1% primary >> "%LOG_FILE%" 2>&1
    netsh interface ipv4 add dns name="%%~b" %DNS_IPv4_2% index=2 >> "%LOG_FILE%" 2>&1
    
    :: Set the Primary and Secondary IPv6 DNS server
    netsh interface ipv6 set dns name="%%~b" static %DNS_IPv6_1% primary >> "%LOG_FILE%" 2>&1
    netsh interface ipv6 add dns name="%%~b" %DNS_IPv6_2% index=2 >> "%LOG_FILE%" 2>&1
)
goto :eof

:CHECK_CHOCO
where choco >nul 2>&1
if %errorlevel% equ 0 goto :eof

echo Choco not found
call :GO PROGRAMS_MANAGER_MENU

:CREATE_FILE
call :MKDIR_PROMPT "%PROGRAMDATA%\WinTweaks\%~1"

set "TARGET_FILE=%PROGRAMDATA%\WinTweaks\%~1\%~2"
if exist "%FILE%" (
    echo. & echo %FILE%: Already exists
    call :CHOICE "Do you want to delete the existing file and start fresh?"
    if errorlevel 2 exit /b 1

    del /f /q "%FILE%" >nul 2>&1
)

if exist "%FILE%" (
    echo. & echo Failed to delete old file
    exit /b 1
)

goto :eof

:CREATE_FOLDER
set "BACKUP_DIR=%ProgramData%\WinTweaks\%~1\%~2"

if exist "%BACKUP_DIR%" (
    echo.
    echo Backup directory already exists: %BACKUP_DIR% 
    
    call :CHOICE "Do you want to delete the existing backup and start fresh?"
    if errorlevel 2 exit /b 1
    rd /s /q "%BACKUP_DIR%" >nul 2>&1
)

if exist "%BACKUP_DIR%" (
    echo.
    echo Failed to delete old backup folder
    exit /b 1
) else (
    call :MKDIR_PROMPT "%PROGRAMDATA%\WinTweaks\%~1\%~2"
)
goto :eof

:PATH
:: %~1 = Subfolder name
:: %~2 = Log filename

:: Define the base directory within PROGRAMDATA for organizational consistency
call :MKDIR_PROMPT "%PROGRAMDATA%\WinTweaks\%~1"

:: Set the full path for the current log file
set "LOG_FILE=%MKDIR_DIR%\%~2.log"

:: Initialize the log file with a fresh timestamp header for every session
(echo Start at %time% %date% & echo.) > "%LOG_FILE%" 2>&1
goto :eof

:MKDIR_PROMPT
set "MKDIR_DIR=%~1"

:: Create the folder if it not exist
if not exist "%MKDIR_DIR%" (
    mkdir "%~1" >nul 2>&1
    if errorlevel 1 (
        echo Failed to create: %MKDIR_DIR%
        pause
        exit
    )
)
goto :eof

:: This section dynamically builds a menu based on variables set before calling it
:SUB_MENU
cls & echo. & echo.
echo      [1] %APPLY%
echo.
echo      [2] %REVERT%
echo.
echo      [0] Back

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto %ROUTINE%
if "%choice%"=="2" goto %REV_ROUTINE%
if "%choice%"=="0" goto %MENU%

call :INVALID "(0-2)" "SUB_MENU"

:RESTART
echo. & call :CHOICE "Do you want to restart your computer?"
if not errorlevel 2 if errorlevel 1 (
    echo Your computer will restart after 5 seconds
    shutdown /r /t 5
    timeout /t 3 >nul
    exit
)
goto :eof

:CHOICE
choice /C YN /N /M "%~1 (Y/N): "
goto :eof

:CONFIRM
cls & echo %~1
call :CHOICE "Continue anyway?"
goto :eof

:INVALID
echo. & echo [ERROR] Invalid selection. Please choose a valid option between %~1
pause
goto %~2

:LOG
echo. & echo More details in: %LOG_FILE%
call :GO %1

:GO
:: %1 = The label of the menu to return to
echo. & echo The operation is done.
pause
goto %1

:: ----------------------------------------------------------------< END >----------------------------------------------------------------