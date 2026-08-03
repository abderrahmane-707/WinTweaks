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
set "F=Files\Common\Functions.bat"

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
if "%choice%"=="0" exit

call "%F%" INVALID "(0-8)" & goto MAIN_MENU

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

call "%F%" INVALID "(0-8)" & goto PERFORMANCE_MENU

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

call "%F%" INVALID "(0-4)" & goto SERVICES_MENU

:SET_SERVICES
call "%F%" PATH_DIR "Performance" "%LOG%"
echo. & echo %MESSAGE%

:: Process each line in the configuration file
for /f "usebackq tokens=1,2 delims=," %%A in ("%FILE%") do (
    set "SERVICE_NAME=%%A"
    set "SERVICE_STATUS=%%B"
    set "SC_PARAM="
    
    sc query "!SERVICE_NAME!" >nul 2>&1
    if !errorlevel! equ 0 (
        set "SC_PARAM="
        
        if /i "!SERVICE_STATUS!"=="Disabled"  set "SC_PARAM=disabled"
        if /i "!SERVICE_STATUS!"=="Manual"  set "SC_PARAM=demand"
        if /i "!SERVICE_STATUS!"=="Automatic"  set "SC_PARAM=auto"
        if /i "!SERVICE_STATUS!"=="AutomaticDelayedStart"  set "SC_PARAM=delayed-auto"
        
        if defined SC_PARAM (
            sc config "!SERVICE_NAME!" start= !SC_PARAM! >nul 2>&1
            
            if !errorlevel! equ 0 (
                set "RESULT_TAG=[SUCCESS]"
            ) else (
                set "RESULT_TAG=[FAILED]"
            )
            echo !RESULT_TAG!: !SERVICE_NAME! _ !SERVICE_STATUS! >> "%LOG_FILE%" 2>&1
        )
        
    ) else (
        echo [NOT FOUND]: !SERVICE_NAME! >> "%LOG_FILE%" 2>&1
    )
)

call "%F%" LOG & goto SERVICES_MENU

:: Create a snapshot of all current Service startup types
:EXPORT_SERVICES
call "%F%" CREATE_FILE "Performance" "ServiceStartupStatus.log"
if !errorlevel! equ 1 goto PERFORMANCE_MENU

echo. & echo Exporting service startup status
powershell -Command "Get-Service | Sort-Object Name | ForEach-Object { Write-Output ($_.Name + ',' + $_.StartType) }" >> "%TARGET_FILE%" 2>&1

echo. & echo Service Startup Status file saved in: %TARGET_FILE%
call "%F%" GO & goto PERFORMANCE_MENU

:DISABLE_TASKS
call "%F%" PATH_DIR "Performance" "DisableScheduledTasks"

echo. & echo Disabling unnecessary scheduled tasks
call "%F%" SET_TASKS "Disable" "Files\Performance\TasksList.txt"
call "%F%" LOG & goto PERFORMANCE_MENU
    
:ENABLE_TASKS
call "%F%" PATH_DIR "Performance" "EnableScheduledTasks"

echo. & echo Re-enable previously disabled scheduled tasks
call "%F%" SET_TASKS "Enable" "Files\Performance\TasksList.txt"
call "%F%" LOG & goto PERFORMANCE_MENU

:BOOT_TWEAKS
call "%F%" CREATE_FOLDER "Performance" "StartupBackup"
if !errorlevel! equ 1 goto PERFORMANCE_MENU

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

for %%F in (
    "%BACKUP_USER%\*.lnk"
    "%BACKUP_ALL%\*.lnk"
    "%HKCU_RUN_BACKUP%"
    "%HKLM_RUN_BACKUP%"
) do (
    if exist "%%~F" goto :FOUND_BACKUP
)

echo No backup files found to restore
call "%F%" LOG & goto PERFORMANCE_MENU

:FOUND_BACKUP
echo. & call "%F%" CHOICE "WARNING: Restoring previous startup settings is NOT recommended. Press (N) if you are unsure"
if errorlevel 2 (call "%F%" LOG & goto PERFORMANCE_MENU)

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
call "%F%" RUNNING_BROWSERS

if "!BROWSERS_OPEN!"=="1" (
    call "%F%" CHOICE "Close browsers to clean them?"
    echo.
    if errorlevel 2 (
        echo Skipping cleaning browsers
		call "%F%" CLEANING_FUNCTION
    ) else (
        echo Closing browsers
        for %%B in (%BROWSERS%) do (
            taskkill /IM "%%B" /F /T >nul 2>&1
        )
        timeout /t 2 >nul     
    )
)

call "%F%" CLEAN_BROWSER
call "%F%" CLEANING_FUNCTION
call "%F%" GO & goto PERFORMANCE_MENU

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
if "%choice%"=="2" call "%F%" SET_POWER_PLAN "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" "high performance"  & goto POWER_PLAN_MENU
if "%choice%"=="3" call "%F%" SET_POWER_PLAN "381b4222-f694-41f0-9685-ff5bb260df2e" "balanced"          & goto POWER_PLAN_MENU
if "%choice%"=="4" call "%F%" SET_POWER_PLAN "a1841308-3541-4fab-bc81-f71556f20b4a" "power saver"       & goto POWER_PLAN_MENU
if "%choice%"=="5" goto ACTIVE_PLAN
if "%choice%"=="0" goto PERFORMANCE_MENU

call "%F%" INVALID "(0-5)" & goto POWER_PLAN_MENU

:: Unlock and add the "Ultimate Performance" plan
:ADD_ULTIMATE_PLAN
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\AddUltimatePerformance.ps1"
call "%F%" GO & goto POWER_PLAN_MENU

:: Remove the "Ultimate Performance" plan
:REMOVE_ULTIMATE_PLAN
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\RemoveUltimatePerformance.ps1"
call "%F%" GO & goto POWER_PLAN_MENU

:ACTIVE_PLAN
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\ActivePlan.ps1"
call "%F%" GO & goto POWER_PLAN_MENU

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
if "%choice%"=="1" (call "%F%" INFO_SCRIPT "Performance" "CPUInfo"          & goto HW_INFO_MENU)
if "%choice%"=="2" (call "%F%" INFO_SCRIPT "Performance" "GPUInfo"          & goto HW_INFO_MENU)
if "%choice%"=="3" (call "%F%" INFO_SCRIPT "Performance" "HardDiskInfo"     & goto HW_INFO_MENU)
if "%choice%"=="4" (call "%F%" INFO_SCRIPT "Performance" "MemoryInfo"       & goto HW_INFO_MENU)
if "%choice%"=="5" (call "%F%" INFO_SCRIPT "Performance" "MotherboardInfo"  & goto HW_INFO_MENU)
if "%choice%"=="6" goto BATTERY_INFO
if "%choice%"=="0" goto PERFORMANCE_MENU

call "%F%" INVALID "(0-6)" & goto HW_INFO_MENU

:: Generate an advanced HTML report regarding battery health and cycle count
:BATTERY_INFO
call "%F%" MKDIR_PROMPT "%PROGRAMDATA%\WinTweaks\Performance"
set "BATTERY_REPORT=%MKDIR_DIR%\BatteryReport.html"

cls & echo Creating battery report
powercfg /batteryreport /output "%BATTERY_REPORT%"

:: Check if the report was created successfully
if %errorlevel% equ 0 (
    start "" "%BATTERY_REPORT%"
) else (
    echo Failed to create battery report
)

call "%F%" GO & goto HW_INFO_MENU


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
if "%choice%"=="6" (
    set ROUTINE=REMOVE_POLICIES
    set REV_ROUTINE=REV_REMOVE_POLICIES
    set APPLY=Remove all policies setting
    set REVERT=Restore all policies setting
    set MENU=PRIVACY_SECURITY_MENU
    goto SUB_MENU
)

if "%choice%"=="7" (call "%F%" INFO_SCRIPT "Security" "SecurityInfo"  & goto PRIVACY_SECURITY_MENU)
if "%choice%"=="0" goto MAIN_MENU

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
if "%choice%"=="5" (call "%F%" INFO_SCRIPT "Network" "NetworkInfo"  & goto NETWORK_MENU)
if "%choice%"=="0" goto MAIN_MENU

call "%F%" INVALID "(0-5)" & goto NETWORK_MENU

:NETWORK_TWEAKS
call "%F%" PATH_DIR "Network" "NetworkTweaks"

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
call "%F%" UPDATE_DNS

call "%F%" LOG & goto NETWORK_MENU

:REV_NETWORK_TWEAKS
call "%F%" PATH_DIR "Network" "DefaultNetworkSettings"

echo. & echo Restoring default network registry settings
reg import "Files\Network\DefaultNetworkSettings.reg" >> "%LOG_FILE%" 2>&1

echo Resetting TCP global parameters to default
for %%P in ("fastopen=default" "fastopenfallback=default" "rss=default" "autotuninglevel=normal") do (
    echo  - %%~P
    netsh int tcp set global %%~P >> "%LOG_FILE%" 2>&1
)

echo. & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\SetDHCP.ps1"

call "%F%" LOG & goto NETWORK_MENU

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
if "%choice%"=="1" (set "DNS_NAME=Google Public DNS" & set "DNS_IPv4_1=8.8.8.8" & set "DNS_IPv4_2=8.8.4.4" & set "DNS_IPv6_1=2001:4860:4860::8888" & set "DNS_IPv6_2=2001:4860:4860::8844" & goto SET_DNS)

:: Cloudflare DNS: Focused on speed and strict user privacy
if "%choice%"=="2" (set "DNS_NAME=Cloudflare DNS" & set "DNS_IPv4_1=1.1.1.1" & set "DNS_IPv4_2=1.0.0.1" & set "DNS_IPv6_1=2606:4700:4700::1111" & set "DNS_IPv6_2=2606:4700:4700::1001" & goto SET_DNS)

:: Cloudflare Family: Blocks malware and adult content automatically
if "%choice%"=="3" (set "DNS_NAME=Cloudflare Family DNS" & set "DNS_IPv4_1=1.1.1.3" & set "DNS_IPv4_2=1.0.0.3" & set "DNS_IPv6_1=2606:4700:4700::1113" & set "DNS_IPv6_2=2606:4700:4700::1003" & goto SET_DNS)

:: AdGuard DNS: Filters out ads and trackers at the network level
if "%choice%"=="4" (set "DNS_NAME=AdGuard DNS" & set "DNS_IPv4_1=94.140.14.14" & set "DNS_IPv4_2=94.140.15.15" & set "DNS_IPv6_1=2a10:50c0::ad1:ff" & set "DNS_IPv6_2=2a10:50c0::ad2:ff" & goto SET_DNS)

:: Clean Browsing: Optimized for family safety and security filtering
if "%choice%"=="5" (set "DNS_NAME=Clean Browsing DNS" & set "DNS_IPv4_1=185.228.168.168" & set "DNS_IPv4_2=185.228.169.168" & set "DNS_IPv6_1=2a0d:2a00:1::" & set "DNS_IPv6_2=2a0d:2a00:2::" & goto SET_DNS)

:: Quad9 DNS: Strong emphasis on blocking malicious domains and phishing
if "%choice%"=="6" (set "DNS_NAME=Quad9 DNS" & set "DNS_IPv4_1=9.9.9.9" & set "DNS_IPv4_2=149.112.112.112" & set "DNS_IPv6_1=2620:fe::fe" & set "DNS_IPv6_2=2620:fe::9" & goto SET_DNS)

:: OpenDNS: Provides customizable web filtering and high uptime
if "%choice%"=="7" (set "DNS_NAME=OpenDNS" & set "DNS_IPv4_1=208.67.222.222" & set "DNS_IPv4_2=208.67.220.220" & set "DNS_IPv6_1=2620:119:35::35" & set "DNS_IPv6_2=2620:119:53::53" & goto SET_DNS)

if "%choice%"=="8" goto SET_DHCP
if "%choice%"=="9" goto DNS_SERVER_TEST
if "%choice%"=="10" goto DNS_STATUS
if "%choice%"=="0" goto NETWORK_MENU

call "%F%" INVALID "(0-10)" & goto DNS_MENU

:SET_DNS
call "%F%" PATH_DIR "Network" "DNS"

echo. & echo Setting %DNS_NAME% server on all connected interfaces
call "%F%" UPDATE_DNS

call "%F%" LOG & goto DNS_MENU

:SET_DHCP
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\SetDHCP.ps1"
call "%F%" GO & goto DNS_MENU

:DNS_SERVER_TEST
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\DNSTest.ps1"
call "%F%" GO & goto DNS_MENU

:DNS_STATUS
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\DNSStatus.ps1"
call "%F%" GO & goto DNS_MENU

:WIFI_PASSWORDS
call "%F%" CREATE_FILE "Network" "WifiPassword.log"
if !errorlevel! equ 1 goto NETWORK_MENU

cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\WifiPassword.ps1" "%TARGET_FILE%"
echo. & echo Wifi Password file saved in: %TARGET_FILE%
call "%F%" GO & goto NETWORK_MENU

:NETWORK_RESET
call "%F%" CONFIRM "WARNING: This script will RESET ALL network configurations"
if errorlevel 2 goto NETWORK_MENU

call "%F%" PATH_DIR "Network" "NetworkReset"
echo. & echo Stopping Network Services

:: Dhcp:      Obtains and renews IP configuration from DHCP servers
:: dnscache:  Temporarily stores DNS results to speed up queries
:: dot3svc:   Handles authentication for wired (Ethernet) network connections
:: netman:    Manages objects in the network
:: netprofm:  Identifies the networks the computer has connected to
:: nlasvc:    Collects and stores configuration information
:: WlanSvc:   Connects to Wi-Fi
:: WwanSvc:   Manages mobile broadband
for %%S in ("dot3svc" "netman" "WlanSvc" "WwanSvc") do call "%F%" NET_CONTROL "%%S" "stop" >> "%LOG_FILE%" 2>&1

echo Resetting Network services to default startup
for %%S in ("Dhcp" "dnscache" "nlasvc" "WlanSvc") do call "%F%" SC_CONFIGURE "%%S" "auto" >> "%LOG_FILE%" 2>&1
for %%S in ("dot3svc" "netman" "netprofm" "WwanSvc") do call "%F%" SC_CONFIGURE "%%S" "demand" >> "%LOG_FILE%" 2>&1

echo Starting Network Services
for %%S in ("dot3svc" "netman" "WlanSvc" "WwanSvc") do call "%F%" NET_CONTROL "%%S" "start" >> "%LOG_FILE%" 2>&1

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

call "%F%" RESTART 
call "%F%" LOG & goto NETWORK_MENU


:PROGRAMS_MANAGER_MENU
cls & echo. & echo.
echo                        ------------------------------ Programs Manager ---------------------------
echo.
echo                         [1] Download Programs                                 [2] Microsoft Office
echo.
echo                         [3] Remove ALL MS Apps                                [4] Programs Info
echo.
echo                                                           [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto PROGRAMS_MENU_VAR
if "%choice%"=="2" goto DOWNLOAD_MO
if "%choice%"=="3" goto REMOVE_MS
if "%choice%"=="4" (call "%F%" INFO_SCRIPT "Programs" "ProgramsInfo"  & goto PROGRAMS_MANAGER_MENU)
if "%choice%"=="0" goto MAIN_MENU

call "%F%" INVALID "(0-4)" & goto PROGRAMS_MANAGER_MENU

:PROGRAMS_MENU_VAR
set "MAX_PROGS=18"
set "PKGMGR=CHOCO"
set "ON=(YES)"
set "OFF=(NO)"

call "%F%" DEFINE_SCOOP_PROGRAMS
call "%F%" DEFINE_CHOCO_PROGRAMS
call "%F%" DEFINE_SCOOP_BUCKETS
call "%F%" RESET_SELECTIONS
call "%F%" RESET_BUCKET_SELECTIONS
call "%F%" LOAD_PKGMGR_DATA

:PROGRAMS_MENU
call "%F%" ENSURE_PKGMGR
cls & echo.
echo [P] Package Manager: %PKGMGR%
echo.
echo                        ----------------------------------- Programs -----------------------------------
echo.
if "%PKGMGR%"=="CHOCO" (
    echo                            [1] Google Chrome             [7] K-Lite Codec              [13] qbittorrent
    echo.
    echo                            [2] Brave                     [8] IrfanView                 [14] VC++ 2015-2022
    echo.
    echo                            [3] Firefox                   [9] Sumatra PDF               [15] VirtualBox
    echo.
    echo                            [4] WinRAR                    [10] Notepad++                [16] IObit Unlocker
    echo.
    echo                            [5] 7-Zip                     [11] Visual Studio Code       [17] AutoHotkey
    echo.
    echo                            [6] VLC                       [12] Git                      [18] MEGA
) else (
    echo                            [1] Git                       [7] CMake                     [13] ripgrep
    echo.
    echo                            [2] SourceGit                 [8] Ninja                     [14] fd
    echo.
    echo                            [3] GCC                       [9] Visual Studio Code        [15] fzf
    echo.
    echo                            [4] LLVM / Clang              [10] Geany IDE                [16] bat
    echo.
    echo                            [5] GDB Debugger              [11] 7-Zip                    [17] Neovim
    echo.
    echo                            [6] Make                      [12] cURL                     [18] Python
)

echo.
echo                        --------------------------------------------------------------------------------
echo.
echo                             [A] Select All               [D] Deselect All             [M] More
echo.
echo                             [U] Update Programs          [X] Remove Programs          [0] Back

if "%PKGMGR%"=="SCOOP" (
    echo.
	echo                             [B] Manage Buckets
)

echo. & echo Selected programs:
call "%F%" SHOW_SELECTED

echo. & echo Tip: You can select multiple items, e.g. 1,3,5 or 1-5 or 1-3,7,10-12

echo. & set "choice=" & set /p "choice=--> Select option(s) and press [S] to Start: "

if "%choice%"=="" goto PROGRAMS_MENU
if "%choice%"=="0" goto PROGRAMS_MANAGER_MENU
if /i "%choice%"=="S" goto RUN_PROGRAMS
if /i "%choice%"=="A" goto SELECT_ALL
if /i "%choice%"=="D" goto DESELECT_ALL
if /i "%choice%"=="P" goto TOGGLE_AND_RETURN
if /i "%choice%"=="U" goto UPDATE_MENU
if /i "%choice%"=="X" goto REMOVE_MENU
if /i "%choice%"=="M" goto MORE_PROG
if /I "%choice%"=="B" goto BUCKET_MENU

call "%F%" MULTI_INPUT
goto PROGRAMS_MENU

:TOGGLE_AND_RETURN
call "%F%" TOGGLE_MANAGER
goto PROGRAMS_MENU

:SELECT_ALL
for /L %%i in (1,1,%MAX_PROGS%) do set "OPT%%i=%ON%"
goto PROGRAMS_MENU

:DESELECT_ALL
for /L %%i in (1,1,%MAX_PROGS%) do set "OPT%%i=%OFF%"
goto PROGRAMS_MENU

:RUN_PROGRAMS
cls
for /L %%i in (1,1,%MAX_PROGS%) do (
    if "!OPT%%i!"=="%ON%" (
        call "%F%" TRY_ACTION "!PKG%%i!" "!NAME%%i!"
    )
)
call "%F%" GO & call "%F%" RESET_SELECTIONS & goto PROGRAMS_MENU

:UPDATE_MENU
cls & echo Checking available updates

echo.
if "%PKGMGR%"=="CHOCO" (call choco outdated) else (call scoop status)
echo.
echo --------------------------------------------------------------------------------
echo Type ALL to update everything
echo Or type the exact program name(s) as shown above, separated by commas (e.g. git,cmake)
echo Type 0 to go back
echo --------------------------------------------------------------------------------

set "choice=" & set /p "choice=--> "
if "%choice%"=="0" goto PROGRAMS_MENU
if "%choice%"=="" goto UPDATE_MENU

if /i "%choice%"=="ALL" (
    cls & echo Updating all programs
    if "%PKGMGR%"=="CHOCO" (call choco upgrade all -y) else (call scoop update -k *)
) else (
    cls
	call scoop update -k
    for %%G in (%choice:,= %) do (
        echo. & echo Updating: %%G
        if "%PKGMGR%"=="CHOCO" (call choco upgrade %%G -y) else (call scoop update -k %%G)
    )
)

call "%F%" GO & goto PROGRAMS_MENU

:REMOVE_MENU
cls & echo Installed programs
echo.
if "%PKGMGR%"=="CHOCO" (call choco list --local-only) else (call scoop list)

echo.
echo --------------------------------------------------------------------------------
echo Type ALL to remove everything.
echo Or type the exact program name(s) as shown above, separated by commas (e.g. git,cmake)
echo Type 0 to go back.
echo --------------------------------------------------------------------------------

set "choice=" & set /p "choice=--> "
if "%choice%"=="0" goto PROGRAMS_MENU
if "%choice%"=="" goto REMOVE_MENU

if /i "%choice%"=="ALL" (
    cls & echo Removing all programs
    if "%PKGMGR%"=="CHOCO" (
        rem -r prints "name|version" with no header, so no skip needed and it's stable across choco versions
        for /f "tokens=1 delims=|" %%P in ('call choco list --local-only -r 2^>nul') do (
            if not "%%P"=="" call choco uninstall %%P -y
        )
    ) else (
        for /f "skip=1 tokens=1" %%P in ('call scoop list 2^>nul') do (
            if not "%%P"=="" call scoop uninstall %%P
        )
    )
) else (
    cls
    for %%G in (%choice:,= %) do (
        echo. & echo Removing: %%G
        if "%PKGMGR%"=="CHOCO" (call choco uninstall %%G -y) else (call scoop uninstall %%G)
    )
)

call "%F%" GO & goto PROGRAMS_MENU

:MORE_PROG
cls & set "apps=" & set /p apps="Enter app name(s) separated by spaces: "
if "%apps%"=="" goto MORE_PROG

for %%A in (%apps%) do call "%F%" PROCESS_APP "%%A"
call "%F%" GO & goto PROGRAMS_MENU

:BUCKET_MENU
if not "%PKGMGR%"=="SCOOP" (
    echo. & echo Buckets are only available when the package manager is Scoop
    pause
    goto PROGRAMS_MENU
)
cls & echo.
echo                        -------------------------------- Scoop Buckets ---------------------------------
echo.
echo                            [1] extras                     [4] php                 [7] nonportable
echo.
echo                            [2] versions                   [5] games               [8] sysinternals
echo.
echo                            [3] java                       [6] nerd-fonts          [9] nirsoft
echo.
echo                        --------------------------------------------------------------------------------
echo.
echo                             [A] Select All          [D] Deselect All          [0] Back
echo.
echo                             [I] Install Selected    [R] Remove Selected

echo. & echo Selected buckets:
call "%F%" SHOW_SELECTED_BUCKETS

echo. & echo Tip: You can select multiple items, e.g. 1,3,5 or 1-5 or 1-3,7,10-12

echo. & set "choice=" & set /p "choice=--> Select option(s): "

if "%choice%"=="" goto BUCKET_MENU
if "%choice%"=="0" goto PROGRAMS_MENU
if /i "%choice%"=="A" goto BUCKET_SELECT_ALL
if /i "%choice%"=="D" goto BUCKET_DESELECT_ALL
if /i "%choice%"=="I" goto INSTALL_BUCKETS
if /i "%choice%"=="R" goto REMOVE_BUCKETS

call "%F%" BUCKET_MULTI_INPUT
goto BUCKET_MENU

:BUCKET_SELECT_ALL
for /L %%i in (1,1,%BUCKET_COUNT%) do set "BOPT%%i=%ON%"
goto BUCKET_MENU

:BUCKET_DESELECT_ALL
for /L %%i in (1,1,%BUCKET_COUNT%) do set "BOPT%%i=%OFF%"
goto BUCKET_MENU

:INSTALL_BUCKETS
cls & echo Installing Buckets
echo.
for /L %%i in (1,1,%BUCKET_COUNT%) do (
    if "!BOPT%%i!"=="%ON%" (
        echo Installing: !BUCKET%%i!
        call scoop bucket add !BUCKET%%i!
    )
)
call "%F%" GO & call "%F%" RESET_BUCKET_SELECTIONS & goto BUCKET_MENU

:REMOVE_BUCKETS
cls & echo Removing Buckets
echo.
for /L %%i in (1,1,%BUCKET_COUNT%) do (
    if "!BOPT%%i!"=="%ON%" (
        echo Removing: !BUCKET%%i!
        call scoop bucket rm !BUCKET%%i!
    )
)
call "%F%" GO & call "%F%" RESET_BUCKET_SELECTIONS & goto BUCKET_MENU

:DOWNLOAD_MO
call "Files\Programs\Office.bat"
if %ERRORLEVEL%==99 goto PROGRAMS_MANAGER_MENU
call "%F%" GO & goto PROGRAMS_MANAGER_MENU

:REMOVE_MS
call "%F%" CONFIRM "WARNING: This will remove ALL Microsoft Store apps"
if errorlevel 2 goto PROGRAMS_MANAGER_MENU

powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Programs\Remove_All_MS.ps1"
call "%F%" GO & goto PROGRAMS_MANAGER_MENU


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

call "%F%" INVALID "(0-10)" & goto CUSTOMIZATION_MENU

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

call "%F%" INVALID "(0-4)" & goto FILE_EXPLORER_MENU

:: Enable the visibility of file extensions
:SHOW_EXTENSIONS
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f >nul 2>&1
call "%F%" GO & goto FILE_EXPLORER_MENU

:: Hide file extensions
:HIDE_EXTENSIONS
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 1 /f >nul 2>&1
call "%F%" GO & goto FILE_EXPLORER_MENU

:: Show both hidden files and protected operating system files
:SHOW_HIDDEN
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSuperHidden /t REG_DWORD /d 1 /f >nul 2>&1
call "%F%" GO & goto FILE_EXPLORER_MENU

:: Hide hidden files and protected system files
:DIS_HIDDEN
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSuperHidden /t REG_DWORD /d 0 /f >nul 2>&1
call "%F%" GO & goto FILE_EXPLORER_MENU

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
call "%F%" GO & goto FILE_EXPLORER_MENU

:: Configure File Explorer to open to "Quick Access" by default
:ON_QUICK_ACCESS
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 2 /f >nul 2>&1
call "%F%" GO & goto FILE_EXPLORER_MENU

:: Enable System-wide Dark Mode for both Apps and the Windows Taskbar/Start Menu
:DARK_MODE
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f >nul 2>&1
call "%F%" GO & goto CUSTOMIZATION_MENU

:: Enable Light Mode for Apps while keeping System components (Taskbar) Dark
:LIGHT_MODE
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f >nul 2>&1
call "%F%" GO & goto CUSTOMIZATION_MENU

:: Disable notifications
:DIS_NOTIFICATION
echo. & echo Disabling notification services
for %%S in ("WpnService" "WpnUserService") do call "%F%" SC_CONFIGURE "%%S" "disabled" >nul 2>&1

echo Disabling notification via registry
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v DisableNotificationCenter /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 0 /f >nul 2>&1
call "%F%" GO & goto CUSTOMIZATION_MENU

:: Re-enable notification
:ENA_NOTIFICATION
echo. & echo Enabling notification services
for %%S in ("WpnService" "WpnUserService") do call "%F%" SC_CONFIGURE "%%S" "auto" >nul 2>&1

echo Enabling notification via registry
reg delete "HKLM\Software\Policies\Microsoft\Windows\Explorer" /v DisableNotificationCenter /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 1 /f >nul 2>&1
call "%F%" GO & goto CUSTOMIZATION_MENU

:: Remove the small arrow icon that appears on desktop shortcuts
:HIDE_SHORTCUT_ARROW
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons" /v 29 /t REG_EXPAND_SZ /d "%SystemRoot%\System32\imageres.dll,197" /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v link /t REG_BINARY /d 00000000 /f >nul 2>&1
call "%F%" GO & goto CUSTOMIZATION_MENU

:: Restore the default Windows shortcut arrow icon
:SHOW_SHORTCUT_ARROW
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons" /v 29 /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v link /f >nul 2>&1
call "%F%" GO & goto CUSTOMIZATION_MENU

:: Ensure NumLock is OFF at the login screen and for the current user
:NUM_LOCK_OFF
reg add "HKCU\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 0 /f >nul 2>&1
reg add "HKU\.DEFAULT\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 2147483648 /f >nul 2>&1
call "%F%" GO & goto CUSTOMIZATION_MENU

:: Ensure NumLock is ON at the login screen and for the current user
:NUM_LOCK_ON
reg add "HKCU\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 2 /f >nul 2>&1
reg add "HKU\.DEFAULT\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 2147483650 /f >nul 2>&1
call "%F%" GO & goto CUSTOMIZATION_MENU

:: Set the Hardware Clock to UTC (recommended for Dual-Boot with Linux)
:UTC
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f >nul 2>&1
call "%F%" GO & goto CUSTOMIZATION_MENU

:: Set the Hardware Clock to Local Time
:LOCAL_TIME
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /f >nul 2>&1
call "%F%" GO & goto CUSTOMIZATION_MENU

:: Create the "God Mode" folder on the desktop (access to all Windows settings in one list)
:POWER_SETTINGS
call "%F%" MKDIR_PROMPT "%USERPROFILE%\Desktop\Powerful Settings.{ED7BA470-8E54-465E-825C-99712043E01C}"
call "%F%" GO & goto CUSTOMIZATION_MENU

:: Delete the "God Mode" folder from the desktop
:REMOVE_POWER_SETTINGS
rd /s /q "%USERPROFILE%\Desktop\Powerful Settings.{ED7BA470-8E54-465E-825C-99712043E01C}" >nul 2>&1
call "%F%" GO & goto CUSTOMIZATION_MENU

:: Disable Trash feature
:TRASH
reg import "Files\Customization\DisableTrash.reg" >nul 2>&1
reg import "Files\Security\DisableTelemetry.reg" >nul 2>&1
call "%F%" GO & goto CUSTOMIZATION_MENU

:: Restore default Windows Trash
:DEF_TRASH
reg import "Files\Customization\DefaultTrash.reg" >nul 2>&1
reg import "Files\Security\DefaultTelemetry.reg" >nul 2>&1
call "%F%" GO & goto CUSTOMIZATION_MENU

:: Restore the classic Windows Photo Viewer
:PHOTO_VIEWER
reg import "Files\Customization\RestoreClassicPhotoViewer.reg" >nul 2>&1
call "%F%" GO & goto CUSTOMIZATION_MENU

:: Remove the classic Windows Photo Viewer registry entries
:REMOVE_PHOTO_VIEWER
reg import "Files\Customization\RemoveClassicPhotoViewer.reg" >nul 2>&1
call "%F%" GO & goto CUSTOMIZATION_MENU

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

call "%F%" INVALID "(0-4)" & goto CONTEXT_MENU

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
call "%F%" GO & goto CONTEXT_MENU

:: Remove "Open Command Prompt Here"
:REV_CMD_CONTEXT
reg delete "HKCU\Software\Classes\Directory\shell\OpenCmdHere" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHere" /f >nul 2>&1
call "%F%" GO & goto CONTEXT_MENU

:: Add "Open Command Prompt Here (Admin)" to folder and background context menus
:CMD_CONTEXT_ADMIN
:: Define the menu text and add the UAC shield icon
reg add "HKCU\Software\Classes\Directory\shell\OpenCmdHereAdmin" /ve /d "Open CMD Here (Admin)" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\shell\OpenCmdHereAdmin" /v "HasLUAShield" /t REG_SZ /d "" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\shell\OpenCmdHereAdmin" /v "Icon" /d "cmd.exe,0" /f >nul 2>&1

:: Use PowerShell to trigger a CMD process with 'RunAs' (Administrator) privileges in the current directory
reg add "HKCU\Software\Classes\Directory\shell\OpenCmdHereAdmin\command" /ve /d "powershell -Command \"Start-Process cmd -ArgumentList '/s','/k','pushd %%1' -Verb RunAs\"" /f >nul 2>&1

:: Repeat the process for the background of a folder (right-clicking on empty space)
reg add "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHereAdmin" /ve /d "Open CMD Here (Admin)" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHereAdmin" /v "HasLUAShield" /t REG_SZ /d "" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHereAdmin" /v "Icon" /d "cmd.exe" /f >nul 2>&1
reg add "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHereAdmin\command" /ve /d "powershell -Command \"Start-Process cmd -ArgumentList '/s','/k','pushd %%V' -Verb RunAs\"" /f >nul 2>&1
call "%F%" GO & goto CONTEXT_MENU

:: Remove the "Open Command Prompt Here (Admin)"
:REV_CMD_CONTEXT_ADMIN
reg delete "HKCU\Software\Classes\Directory\shell\OpenCmdHereAdmin" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\Background\shell\OpenCmdHereAdmin" /f >nul 2>&1
call "%F%" GO & goto CONTEXT_MENU

:: Add "Restart Explorer" to the Desktop right-click menu
:RESTART_EXPLORER
reg add "HKCU\Software\Classes\DesktopBackground\Shell\RestartExplorer" /ve /d "Restart Explorer" /f >nul 2>&1
reg add "HKCU\Software\Classes\DesktopBackground\Shell\RestartExplorer" /v "Icon" /d "explorer.exe,0" /f >nul 2>&1

:: The command kills the explorer.exe process and immediately restarts it
reg add "HKCU\Software\Classes\DesktopBackground\Shell\RestartExplorer\command" /ve /d "cmd.exe /c taskkill /F /IM explorer.exe >nul 2>&1 & start explorer.exe" /f >nul 2>&1
call "%F%" GO & goto CONTEXT_MENU

:: Remove the "Restart Explorer" right-click menu
:REV_RESTART_EXPLORER
reg delete "HKCU\Software\Classes\DesktopBackground\Shell\RestartExplorer" /f >nul 2>&1
call "%F%" GO & goto CONTEXT_MENU

:: Add "Kill frozen process" to the Desktop right-click menu
:KILL_FROZEN
reg add "HKCU\Software\Classes\DesktopBackground\Shell\KillNotResponding" /v "MUIVerb" /d "Kill frozen process" /f >nul 2>&1
reg add "HKCU\Software\Classes\DesktopBackground\Shell\KillNotResponding" /v "Icon" /d "taskmgr.exe,0" /f >nul 2>&1

:: Targets only processes with the window status "NOT RESPONDING"
reg add "HKCU\Software\Classes\DesktopBackground\Shell\KillNotResponding\Command" /ve /d "cmd.exe /C taskkill.exe /F /FI \"status eq NOT RESPONDING\"" /f >nul 2>&1
call "%F%" GO & goto CONTEXT_MENU

:: Remove the "Kill frozen process" right-click menu
:REV_KILL_FROZEN
reg delete "HKCU\Software\Classes\DesktopBackground\Shell\KillNotResponding" /f >nul 2>&1
call "%F%" GO & goto CONTEXT_MENU

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
if "%choice%"=="4" (call "%F%" INFO_SCRIPT "System" "SystemInfo"  & goto SYSTEM_MENU)
if "%choice%"=="0" goto MAIN_MENU

call "%F%" INVALID "(0-4)" & goto SYSTEM_MENU

:RESTORE_POINT
:: RestorePointType: MODIFY_SETTINGS indicates settings were changed
cls & echo Creating a System Restore Point
powershell -Command "Checkpoint-Computer -Description 'WinTweaks Restore Point' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop"
if %errorlevel% equ 0 (call "%F%" GO & goto SYSTEM_MENU)

call "%F%" PATH_DIR "System" "RestorePoint"

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
for %%S in ("VSS" "swprv") do call "%F%" NET_CONTROL "%%S" "stop" >> "%LOG_FILE%" 2>&1

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
    call "%F%" SC_CONFIGURE "%%S" "demand" >> "%LOG_FILE%" 2>&1
    call "%F%" NET_CONTROL "%%S" "start" >> "%LOG_FILE%" 2>&1
)

:: RpcSs:         Remote Procedure Call (RPC) Service (Manages inter-process communication)
:: EventLog:      Windows Event Log Service (Records system, security, and application events)
:: EventSystem:   COM+ Event System (Distributes system events to subscribed components)
:: Schedule:      Task Scheduler Service (Manages scheduled tasks, including automatic restore point creation)
for %%S in ("RpcSs" "CryptSvc" "EventLog" "EventSystem" "Schedule") do (
    call "%F%" SC_CONFIGURE "%%S" "auto" >> "%LOG_FILE%" 2>&1
    call "%F%" NET_CONTROL "%%S" "start" >> "%LOG_FILE%" 2>&1
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
call "%F%" LOG & goto SYSTEM_MENU

:REG_BACK
cls
call "%F%" CREATE_FOLDER "System" "FullRegistryBackup"
if !errorlevel! equ 1 goto SYSTEM_MENU

call "%F%" PATH_DIR "System" "FullRegistryBackup"

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
        reg save "%%B" "%TARGET_FOLDER%\%%C.hive" /y >>"%LOG_FILE%" 2>&1      
        if !errorlevel! equ 0 set /a SUCCESS_COUNT+=1
    )
)

if exist "%TARGET_FOLDER%\*.hive" (
    echo. & echo Backup Process Finished. Total Success: !SUCCESS_COUNT!/7 
    call "%F%" CHOICE "Compress folder?"
    if errorlevel 2 (
        echo. & echo Backup saved in: %TARGET_FOLDER%
    ) else (
	    powershell -NoProfile -ExecutionPolicy Bypass -File "Files\System\CompressHiveFiles.ps1" "%TARGET_FOLDER%" "%LOG_FILE%"
    )
) else (
    echo No hive files were created. Backup failed
)
call "%F%" LOG & goto SYSTEM_MENU

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

call "%F%" INVALID "(0-2)" & goto ACTIVATION_MENU

:: Activating Windows and Microsoft Office using MAS script
:RUN_ACTIVATION
cls & echo Launching Microsoft Activation Script (MAS) to activate Windows and Office
echo The script will open in a new window. Follow the on-screen instructions
powershell -NoP -EP Bypass -c "irm https://get.activated.win | iex"
call "%F%" GO & goto ACTIVATION_MENU

:: Check if the Machine is Activated or not
:CHECK_ACTIVATION
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\System\ActivationStatus.ps1"
call "%F%" GO & goto ACTIVATION_MENU


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

call "%F%" INVALID "(0-7)" & goto TOOLS_MENU

:: Scan and verify the integrity of all protected system files and repair corrupted
:SFC_SCAN
cls & echo Running sfc scan
sfc /scannow
call "%F%" GO & goto TOOLS_MENU

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

call "%F%" INVALID "(0-4)" & goto DISM_MENU

:: Perform a quick check to see if the OS has already flagged any corruption
:DISM_CHECK_HEALTH
cls & echo Performing quick health check of Windows image
dism /Online /Cleanup-Image /CheckHealth
call "%F%" GO & goto DISM_MENU

:: This does not fix errors, it only reports them
:DISM_SCAN_HEALTH
cls & echo Performing deep scan of Windows image
dism /Online /Cleanup-Image /ScanHealth
call "%F%" GO & goto DISM_MENU

:: Repair the Windows Image by downloading healthy files from Windows Update
:DISM_RESTORE_HEALTH
cls & echo Fix Windows component
dism /Online /Cleanup-Image /RestoreHealth
call "%F%" GO & goto DISM_MENU

:: Clean up the WinSxS folder by removing superseded (old) versions of components
:DISM_COMPONENT_CLEANUP
call "%F%" CONFIRM "WARNING: This will permanently remove rollback capability for Windows Updates"
if errorlevel 2 goto DISM_MENU

echo Cleaning Windows components
dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase
call "%F%" GO & goto DISM_MENU

:: Launch Windows Defragment
:DEFRAG
start "" dfrgui.exe
goto TOOLS_MENU

:CHKDSK
cls & echo Available drives on your system:

:: List all existing drive letters
for %%d in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist %%d:\ echo %%d:\
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

call "%F%" INVALID "(0-3)" & goto CHKDSK_MENU

:: Scans for errors but does not fix anything
:DISK_STATUS
cls & echo Running read-only CHKDSK on drive %drive%:\ to check for errors
timeout /t 2 >nul
chkdsk %drive%:
call "%F%" GO & goto CHKDSK_MENU

:FIX_FILE
cls & echo Running CHKDSK with /f option on drive %drive%:\ to fix file system errors
timeout /t 2 >nul

:: /f: Fixes errors on the disk
chkdsk %drive%: /f
call "%F%" GO & goto CHKDSK_MENU

:FIX_SECTORS
cls & echo Running CHKDSK with /r option on drive %drive%:\ to find bad sectors and recover data
timeout /t 2 >nul

:: /r: Locates bad sectors and recovers readable information
chkdsk %drive%: /r
call "%F%" GO & goto CHKDSK_MENU

:: Launch Memory Diagnostic
:MEMORY_DIAG
start "" mdsched.exe
goto TOOLS_MENU

:: Launch Disk Cleanup
:CLEAN_MGR
cleanmgr.exe /d %SYSTEMDRIVE% /VERYLOWDISK
goto TOOLS_MENU

:: Delete "%PROGRAMDATA%\WinTweaks" folder
:DELETE_SCRIPT_DATA
set "MKDIR_DIR=%PROGRAMDATA%\WinTweaks"
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Tools\DeleteScriptData.ps1" "%MKDIR_DIR%"
call "%F%" GO & goto TOOLS_MENU


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

call "%F%" INVALID "(0-3)" & goto OTHER_MENU

:: Launch CTT
:CTT
cls & echo Running Chris Titus tool
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb https://christitus.com/win | iex"
call "%F%" GO & goto OTHER_MENU

:: Download and launch O&O Shutup 10 ++
:OO_SHUTUP
call "%F%" MKDIR_PROMPT "%PROGRAMDATA%\WinTweaks\Other\OOSU10"

cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Other\DownloadOOShutup.ps1" "%MKDIR_DIR%"
call "%F%" GO & goto OTHER_MENU

:: Download and launch Speedtest CLI
:NET_SPEED_TEST
call "%F%" MKDIR_PROMPT "%PROGRAMDATA%\WinTweaks\Other\speedtest_cli"

cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Other\DownloadNetSpeed.ps1" "%MKDIR_DIR%"
call "%F%" GO & goto OTHER_MENU


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

call "%F%" INVALID "(0-2)" & goto SUB_MENU
