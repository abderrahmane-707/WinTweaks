@echo off
setlocal enabledelayedexpansion
title Win_Tweaks

:: Check for administrator privileges
fltmc >nul 2>&1
if errorlevel 1 (
    echo This script must be run with Administrator privileges
    pause
	exit /b 1
)

:: Go to script's directory
cd /d "%~dp0"

:: Win_Tweaks Script main menu
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

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-8)
pause
goto MAIN_MENU

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
	set REVERT=Enable unnecessary scheduled tasks
    set MENU=PERFORMANCE_MENU
    goto SUB_MENU
)
if "%choice%"=="3" (
    set ROUTINE=BOOT_TWEAKS
    set REV_ROUTINE=REV_BOOT_TWEAKS
    set APPLY=Enhance boot up settings
	set REVERT=Set boot up settings to default
    set MENU=PERFORMANCE_MENU
    goto SUB_MENU
)
if "%choice%"=="4" goto CLEAN_UP
if "%choice%"=="5" goto POWER_PLAN_MENU
if "%choice%"=="6" goto HW_INFO_MENU
if "%choice%"=="0" goto MAIN_MENU

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-6)
pause
goto PERFORMANCE_MENU


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
    set MESSAGE=Tweaking windows services
    set LOG=ServicesTweaks
    goto SET_SERVICES
)
if "%choice%"=="2" (
    set FILE=Files\Performance\SafeServicesTweaks.txt
    set MESSAGE=Tweaking windows services in safe mode
    set LOG=SafeServicesTweaks
    goto SET_SERVICES
)
if "%choice%"=="3" (
    set FILE=Files\Performance\DefaultServicesSettings.txt
    set MESSAGE=Restore most windows services to default settings
    set LOG=DefaultServicesSettings
    goto SET_SERVICES
)
if "%choice%"=="4" goto EXPORT_SERVICES
if "%choice%"=="0" goto PERFORMANCE_MENU

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-4)
pause
goto SERVICES_MENU

:SET_SERVICES
echo. & echo %MESSAGE%
call :PATH "Performance" "%LOG%"

:: Process each line in the configuration file
for /f "usebackq tokens=1,2 delims=," %%A in ("%FILE%") do (
    set "SERVICE_NAME=%%A"
    set "SERVICE_STATUS=%%B"
    
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
        echo [NOT FOUND]: !SERVICE_NAME! _ !SERVICE_STATUS! >> "%LOG_FILE%" 2>&1
    )
)

call :LOG SERVICES_MENU

:: Create a snapshot of all current Service startup types
:EXPORT_SERVICES
call :TIME_STAMP_FILE "Performance" "ServiceStartupStatus"

echo. & echo Exporting the service startup status
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\ExportServices.ps1" >> "%REPORT_FILE%" 2>&1

call :LOG SERVICES_MENU

:: Disable a list of scheduled tasks
:DISABLE_TASKS
call :PATH "Performance" "DisableScheduledTasks"

:: Call the internal :SET_TASKS function using "Disable" mode
call :SET_TASKS "Disable" "Files\Performance\TasksList.txt"


:: Enable the scheduled tasks previously disabled
call :LOG PERFORMANCE_MENU
	
:ENABLE_TASKS
call :PATH "Performance" "EnableScheduledTasks"

:: Call the internal :SET_TASKS function using "Enable" mode
call :SET_TASKS "Enable" "Files\Performance\TasksList.txt"

call :LOG PERFORMANCE_MENU

:BOOT_TWEAKS
call :PATH "Performance" "BootTweaks"

echo. & echo Import Boot up tweaks registry settings
reg import "Files\Performance\BootTweaks.reg" >> "%LOG_FILE%" 2>&1

:: Wipe out all startup programs
echo Deleting startup shortcuts
del /f /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\*.lnk" >> "%LOG_FILE%" 2>&1
del /f /q "%PROGRAMDATA%\Microsoft\Windows\Start Menu\Programs\Startup\*.lnk" >> "%LOG_FILE%" 2>&1

call :LOG PERFORMANCE_MENU

:REV_BOOT_TWEAKS
call :PATH "Performance" "DefaultBootSettings"

echo. & echo Import default Boot up registry settings
reg import "Files\Performance\DefaultBootSettings.reg" >> "%LOG_FILE%" 2>&1

call :LOG PERFORMANCE_MENU

:CLEAN_UP
cls
:: List of browser processes to check
set "BROWSERS=chrome.exe brave.exe msedge.exe firefox.exe"
set BROWSERS_OPEN=0

:: Check if any browser is currently running
for %%A in (%BROWSERS%) do (
    tasklist /FI "IMAGENAME eq %%B" 2>nul | find /I "%%B" >nul
    if not errorlevel 1 (
        set BROWSERS_OPEN=1
    )
)

if "!BROWSERS_OPEN!"=="1" (
    echo Browsers are currently open
    choice /C YN /N /M "Close them? (Y/N)"
    if errorlevel 2 (
        echo Skipping files currently used by browsers
    ) else (
        echo Closing browsers
        for %%B in (%BROWSERS%) do (
            taskkill /IM "%%B" /F /T >nul 2>&1
        )
        timeout /t 2 >nul
    )
)

:: Chromium-based browsers (Chrome, Edge, Brave)
for %%A in (
    "Google\Chrome\User Data|Google Chrome"
    "Microsoft\Edge\User Data|Microsoft Edge"
    "BraveSoftware\Brave-Browser\User Data|Brave"
) do (
    for /f "tokens=1,2 delims=|" %%A in ("%%~B") do (
        if exist "%LOCALAPPDATA%\%%A" (
            echo Cleaning: %%B
            for /d %%P in ("%LOCALAPPDATA%\%%~A\*") do (
                :: Remove caches and folders
                for %%D in ("Cache" "Code Cache" "GPUCache" "ShaderCache" "File System" "Service Worker" "Media Cache" "Download Service") do (
                    rd /s /q "%%P\%%~D" >nul 2>&1
                )
                :: Remove cookie/history files
                for %%F in ("Cookies" "Cookies-journal" "Network\Cookies" "Network\Cookies-journal" "History" "History-journal") do (
                    del /f /q "%%P\%%~F" >nul 2>&1
                )
            )
        )
    )
)

:: Mozilla Firefox
for %%B in (
    "Mozilla\Firefox|Mozilla Firefox"
) do (
    for /f "tokens=1,2 delims=|" %%A in ("%%~B") do (
        if exist "%APPDATA%\%%A" (
            echo Cleaning: %%B

            :: Remove cache
            if exist "%LOCALAPPDATA%\%%A\Profiles" (
                for /d %%P in ("%LOCALAPPDATA%\%%A\Profiles\*") do (
                    for %%D in ("cache2" "thumbnails" "jumpListCache" "startupCache") do (
                        rd /s /q "%%P\%%~D" >nul 2>&1
                    )
                )
            )

            :: Clean profile data
            if exist "%APPDATA%\%%A\Profiles" (
                for /d %%P in ("%APPDATA%\%%A\Profiles\*") do (
                    :: Delete cookies and other sqlite files
                    for %%F in ("cookies.sqlite" "cookies.sqlite-wal" "favicons.sqlite" "formhistory.sqlite") do (
                        del /f /q "%%P\%%~F" >nul 2>&1
                    )
					:: Session data (directory)
                    rd /s /q "%%P\sessionstore-backups" >nul 2>&1
					
					:: Storage (directory)
                    rd /s /q "%%P\storage" >nul 2>&1
                )
            )

            :: Delete crash reports
            rd /s /q "%APPDATA%\%%A\Crash Reports" >nul 2>&1
        )
    )
)

call :CLEANING_FUNCTION

call :FINAL_CLEAN
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

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-5)
pause
goto POWER_PLAN_MENU

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
:: Output of the active power scheme
set "TEMP_FILE=%TEMP%\ActivePowerPlan.guid"

:: Get the currently active power plan
powercfg /getactivescheme > "%TEMP_FILE%" 2>&1

:: Extract the power plan GUID from the command output
for /f "tokens=4" %%A in (%TEMP_FILE%) do set "PLAN_GUID=%%A"

:: Remove any accidental spaces from the extracted GUID
set "PLAN_GUID=%PLAN_GUID: =%"

:: Compare the GUID
if /I "!PLAN_GUID!"=="381b4222-f694-41f0-9685-ff5bb260df2e" (
    set "PLAN_NAME=Balanced"

) else if /I "!PLAN_GUID!"=="8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" (
    set "PLAN_NAME=High Performance"

) else if /I "!PLAN_GUID!"=="a1841308-3541-4fab-bc81-f71556f20b4a" (
    set "PLAN_NAME=Power Saver"
	
) else (
    set "PLAN_NAME=Unknown Power Plan"
)

echo.
echo Active power plan GUID: !PLAN_GUID!
echo Active power plan Name: !PLAN_NAME!

del "%TEMP_FILE%" >nul 2>&1
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

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-6)
pause
goto HW_INFO_MENU

:: Display detailed processor
:CPU_INFO
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\CPUInfo.ps1"
call :GO HW_INFO_MENU

:: Display Graphics Card details
:GPU_INFO
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\GPUInfo.ps1"
call :GO HW_INFO_MENU

:: Display Storage stats
:HARD_DISK_INFO
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\HardDiskInfo.ps1"
call :GO HW_INFO_MENU

:: Display RAM information
:RAM_INFO
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\MemoryInfo.ps1"
call :GO HW_INFO_MENU

:: Display Motherboard information
:MOTHERBOARD_INFO
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Performance\MotherboardInfo.ps1"
call :GO HW_INFO_MENU

:: Generate an advanced HTML report regarding battery health and cycle count
:BATTERY_INFO
cls & echo Creating battery report
set "REPORT_FILE=%USERPROFILE%\Documents\BatteryReport.html"

powercfg /batteryreport /output "%REPORT_FILE%"
:: Opening battery report
start "" "%REPORT_FILE%"
call :GO HW_INFO_MENU


:PRIVACY_SECURITY_MENU
cls & echo. & echo.
echo                        --------------------------- Privacy and Security --------------------------
echo.
echo                          [1] Telemetry                                       [2] Privacy Cleanup
echo.
echo                          [3] Windows Updates                                 [4] Windows Defender
echo.
echo                          [5] Enhance Security                                [6] Security Info
echo.
echo                                                         [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" (
    set ROUTINE=DISABLE_TELEMETRY
    set REV_ROUTINE=REV_DISABLE_TELEMETRY
    set APPLY=Disable windows telemetry and some tracking components
	set REVERT=Default windows telemetry and some tracking components
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
	set REVERT=Set security settings to default
    set MENU=PRIVACY_SECURITY_MENU
    goto SUB_MENU
)
if "%choice%"=="6" goto SECURITY_INFO
if "%choice%"=="0" goto MAIN_MENU

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-6)
pause
goto PRIVACY_SECURITY_MENU

:DISABLE_TELEMETRY
call :PATH "Security" "DisableTelemetry"

echo. & echo Disable windows telemetry via registry
reg import "Files\Security\DisableTelemetry.reg" >> "%LOG_FILE%" 2>&1

echo Disabling windows telemetry services

:: DiagTrack :      Connected User Experiences and Telemetry
:: dmwappushsvc :   WAP Push Message Routing Service
:: WerSvc :         Windows Error Reporting Service
for %%S in ("DiagTrack" "dmwappushsvc" "WerSvc") do (
    call :SC_CONFIGURE "%%S" "disabled"
)

echo Blocking windows telemetry and trash domains
set "HOSTS_PATH=%SYSTEMROOT%\System32\drivers\etc\hosts"
:: Add empty line to host file first
echo. >> "%HOSTS_PATH%"
for /f "usebackq delims=" %%L in ("%~dp0Files\Security\TrackingDomains.txt") do (
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
set "TEMP_FILE=%temp%\HostsClean.txt"

echo. & echo Default windows telemetry registry value
reg import "Files\Security\DefaultTelemetry.reg" >> "%LOG_FILE%" 2>&1

echo Set windows telemetry services to manual startup
for %%S in ("DiagTrack" "dmwappushsvc" "WerSvc") do (
    call :SC_CONFIGURE "%%S" "demand"
)

echo Delete windows telemetry and trash domains
:: Filter out blocked domains listed in TrackingDomains.txt from the HOSTS file
findstr /V /L /G:"Files\Security\TrackingDomains.txt" "%HOSTS_PATH%" > "%TEMP_FILE%"

:: Overwrite the original HOSTS file with the filtered version
copy /y "%TEMP_FILE%" "%HOSTS_PATH%" >> "%LOG_FILE%" 2>&1
del "%TEMP_FILE%" >nul 2>&1

echo Flushing DNS cache
ipconfig /flushdns >> "%LOG_FILE%" 2>&1

call :LOG PRIVACY_SECURITY_MENU

:PRIVACY_CLEANUP
cls
set "BROWSERS=chrome.exe brave.exe msedge.exe firefox.exe"
set BROWSERS_OPEN=0

for %%B in (%BROWSERS%) do (
    tasklist /FI "IMAGENAME eq %%B" 2>nul | find /I "%%B" >nul
    if not errorlevel 1 (
        set BROWSERS_OPEN=1
    )
)

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
    rd /s /q "%APPDATA%\Mozilla\Firefox"
)

if exist "%LOCALAPPDATA%\Mozilla\Firefox" (
    rd /s /q "%LOCALAPPDATA%\Mozilla\Firefox"
)

echo Cleaning registry entries
reg import "Files\Security\PrivacyCleanup.reg" >nul 2>&1

call :CLEANING_FUNCTION

:: Clear application launch history and start fresh
echo Cleaning prefetch files
del /f /s /q "%SYSTEMROOT%\Prefetch\*" >nul 2>&1

:: Clean System Log files
echo Cleaning system log files
for /d %%G in ("%SYSTEMROOT%\Logs\*" "%SYSTEMROOT%\System32\LogFiles\*" ) do (
    :: Take ownership of the directory recursively
    takeown /f "%%G" /r /d y >nul 2>&1
    :: Grant full control to the Administrators group
    icacls "%%G" /grant Administrators:F /t /c >nul 2>&1
    :: Delete all files within the folder
    del /f /s /q "%%G" >nul 2>&1
)

:: Clear Windows Event Viewer logs
echo Cleaning Windows Event Logs
for %%L in ("Application" "Security" "System" "Setup") do (
    wevtutil clear-log %%L >nul 2>&1
)

echo Cleaning Clipboard
echo. | clip >nul

echo Flushing DNS cache
ipconfig /flushdns >nul 2>&1

call :FINAL_CLEAN
call :GO PRIVACY_SECURITY_MENU

:WINDOWS_UPDATES_MENU
cls & echo. & echo.
echo                        ------------------------------ Windows Updates ----------------------------
echo.
echo                          [1] Disable All Updates                        [2] Disable Feature Updates
echo.
echo                          [3] Reset Windows Updates                      [4] Default Updates Settings
echo.
echo                                                           [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto DISABLE_ALL_UPDATES
if "%choice%"=="2" goto DISABLE_FEATURE_UPDATES
if "%choice%"=="3" goto RESET_UPDATES
if "%choice%"=="4" goto ENABLE_UPDATES
if "%choice%"=="0" goto PRIVACY_SECURITY_MENU

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-4)
pause
goto WINDOWS_UPDATES_MENU

:DISABLE_ALL_UPDATES
call :PATH "Security" "DisableUpdates"

echo. & echo Disable windows update via registry
reg import "Files\Security\DisableUpdates.reg" >> "%LOG_FILE%" 2>&1

echo Disabling Windows Update services
for %%S in ("BITS" "DoSvc" "UsoSvc" "WaaSMedicSvc" "wuauserv") do (
    call :SC_CONTROL "%%S" "stop"
    call :SC_CONFIGURE "%%S" "disabled"   
)

echo Deleting SoftwareDistribution
rd /s /q "%SYSTEMROOT%\SoftwareDistribution" >> "%LOG_FILE%" 2>&1

echo Delete windows update log
del /f /q "%SYSTEMROOT%\WindowsUpdate.log" >> "%LOG_FILE%" 2>&1

call :LOG PRIVACY_SECURITY_MENU

:DISABLE_FEATURE_UPDATES
call :PATH "Security" "DisableFeatureUpdates"

echo. & echo Disable feature windows update from registry
reg import "Files\Security\DisableFeatureUpdates.reg" >> "%LOG_FILE%" 2>&1

call :LOG PRIVACY_SECURITY_MENU

:RESET_UPDATES
call :PATH "Security" "ResetUpdates"

echo. & echo Reset Update Registry
reg import "Files\Security\ResetUpdates.reg" >> "%LOG_FILE%" 2>&1

echo Stop update services

:: BITS :          Background Intelligent Transfer Service
:: CryptSvc :      System files signatures
:: DoSvc :         Delivery Optimization
:: UsoSvc :        Update Orchestrator Service
:: WaaSMedicSvc :  Windows Update Medic Service
:: wuauserv :      Windows Update Service
for %%S in ("BITS" "CryptSvc" "DoSvc" "UsoSvc" "WaaSMedicSvc" "wuauserv") do (
    call :SC_CONTROL "%%S" "stop"  
)

:: Remove pending updates and update history
echo Deleting SoftwareDistribution
rd /s /q "%SYSTEMROOT%\SoftwareDistribution" >> "%LOG_FILE%" 2>&1

:: Force Windows to rebuild the update database and signatures
echo Deleting Catroot2
rd /s /q "%SYSTEMROOT%\System32\catroot2" >> "%LOG_FILE%" 2>&1

:: Remove BITS Queue Manager (QMGR) data files to clear stuck download jobs
echo Deleting BITS QMGR
del /f /q "%ALLUSERSPROFILE%\Application Data\Microsoft\Network\Downloader\qmgr*.dat" >> "%LOG_FILE%" 2>&1

echo Delete update log file
del /f /q "%SYSTEMROOT%\WindowsUpdate.log" >> "%LOG_FILE%" 2>&1

:: Restore default Security Descriptors (Permissions) for BITS and Windows Update services
:: This fixes "Access Denied" errors that prevent services from starting
echo Resetting service security descriptors
sc sdset bits D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU) >> "%LOG_FILE%" 2>&1
sc sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU) >> "%LOG_FILE%" 2>&1

:: Re-register essential System DLLs (Libraries) for updates, web protocols, and encryption
echo Reregistering system DLL
for %%d in ("atl.dll urlmon.dll mshtml.dll shdocvw.dll browseui.dll jscript.dll vbscript.dll scrrun.dll msxml.dll msxml3.dll msxml6.dll actxprxy.dll softpub.dll wintrust.dll dssenh.dll rsaenh.dll gpkcsp.dll sccbase.dll slbcsp.dll cryptdlg.dll oleaut32.dll ole32.dll shell32.dll initpki.dll wuapi.dll wuaueng.dll wuaueng1.dll wucltui.dll wups.dll wups2.dll wuweb.dll qmgr.dll qmgrprxy.dll wucltux.dll muweb.dll wuwebv.dll") do (
    regsvr32 /s "%%d" >> "%LOG_FILE%" 2>&1
)

:: Revert system security policies to the Windows default baseline
echo Apply default security settings
secedit /configure /cfg %SYSTEMROOT%\inf\defltbase.inf /db defltbase.sdb /verbose >> "%LOG_FILE%" 2>&1

:: Forcefully clear all BITS download jobs for all users on the system
echo Cleaning BITS jobs
bitsadmin /reset /allusers >> "%LOG_FILE%" 2>&1

echo Enabling windows update services
for %%S in ("BITS" "CryptSvc" "DoSvc" "UsoSvc" "WaaSMedicSvc" "wuauserv") do (
    call :SC_CONFIGURE "%%S" "demand" 
    call :SC_CONTROL "%%S" "start"  
)

echo Reset TCP/IP Stack
netsh int ip reset >> "%LOG_FILE%" 2>&1

echo Reset Winsock
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

echo More details in: %LOG_FILE%
call :GO PRIVACY_SECURITY_MENU

:ENABLE_UPDATES
call :PATH "Security" "DefaultUpdates"

echo. & echo Default windows update registry value
reg import "Files\Security\DefaultUpdates.reg" >> "%LOG_FILE%" 2>&1

echo Enabling windows update services
for %%S in ("BITS" "DoSvc" "UsoSvc" "WaaSMedicSvc" "wuauserv") do (
    call :SC_CONFIGURE "%%S" "demand"   
	call :SC_CONTROL "%%S" "start" 
)



call :LOG PRIVACY_SECURITY_MENU

:WINDOWS_DEFENDER_MENU
cls & echo. & echo.
echo                        ------------------------------ Windows Defender ---------------------------
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

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-3)
pause
goto WINDOWS_DEFENDER_MENU

:DISABLE_DEFENDER
echo. & echo WARNING: This will disable WINDOWS DEFENDER COMPLETELY!
choice /C YN /N /M "Continue anyway? (Y/N): "
if errorlevel 2 goto PRIVACY_SECURITY_MENU

call :PATH "Security" "DisableDefender"

echo Disable windows defender via registry
reg import "Files\Security\DisableDefender.reg" >> "%LOG_FILE%" 2>&1

echo Disable windows defender services

:: WinDefend :              Microsoft Defender Antivirus Service
:: WdNisSvc :               Microsoft Defender Antivirus Network Inspection Service
:: wscsvc :                 Windows Security Center Service
:: SecurityHealthService :  Windows Security Health Service (Dashboard and Tray icon)
:: Sense :                  Windows Defender Advanced Threat Protection (Endpoint Detection)
:: webthreatdefsvc :        Microsoft Defender Antivirus Web Threat Protection
:: webthreatdefusersvc :    User-specific Web Threat Protection service
for %%S in ("WinDefend" "WdNisSvc" "wscsvc" "SecurityHealthService" "Sense" "webthreatdefsvc" "webthreatdefusersvc") do (
    call :REG_CONFIGURE  "%%S" "4"
)

call :LOG PRIVACY_SECURITY_MENU

:ENABLE_DEFENDER
call :PATH "Security" "DefaultDefender"

echo. & echo Default windows defender registry value
reg import "Files\Security\DefaultDefender.reg" >> "%LOG_FILE%" 2>&1

echo Enable windows defender services
for %%S in ("WinDefend" "WdNisSvc" "wscsvc" "SecurityHealthService" "Sense" "webthreatdefsvc" "webthreatdefusersvc") do (
    call :REG_CONFIGURE  "%%S" "2"
)

echo Enable tamper protection
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Set-MpPreference -DisableTamperProtection 0 -ErrorAction Stop" >> "%LOG_FILE%" 2>&1

call :LOG PRIVACY_SECURITY_MENU

:REMOVE_DEFENDER
echo. & echo WARNING: This script will permanently delete Windows Defender from your system
choice /C YN /N /M "Continue anyway? (Y/N): "
if errorlevel 2 goto PRIVACY_SECURITY_MENU

call :PATH "Security" "RemoveDefender"

echo Remove Windows Defender Security health UI
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Security\RemoveSecHealthUI.ps1" >> "%LOG_FILE%" 2>&1

echo Remove Windows Defender via registry
for %%f in ("Files\Security\RemoveDefenderModule\*.reg") do "Files\Security\PowerRun.exe" /TI /SW:0 regedit.exe /s "%%f"

echo Remove Windows Defender files
for %%D in (
    "C:\Program Files (x86)\Windows Defender"
    "C:\Program Files\Windows Defender Advanced Threat Protection"
    "C:\Program Files\Windows Defender"
    "C:\ProgramData\Microsoft\Windows Defender"
) do (
    "Files\Security\PowerRun.exe" /TI /SW:0 cmd.exe /c "rd /s /q ""%%~D"""
)

echo. & choice /C YN /N /M "Do you want to restart your computer? (Y/N): "

if errorlevel 2 call :LOG PRIVACY_SECURITY_MENU

echo. & echo Restarting your computer in 5 seconds
shutdown /r /t 5
timeout /t 3 >nul
exit

:ENHANCE_SECURITY
call :PATH "Security" "EnhanceSecurity"

echo. & echo Enhance security via registry
reg import "Files\Security\EnhanceSecurity.reg" >> "%LOG_FILE%" 2>&1

echo Disabling unsafe windows features

:: MicrosoftWindowsPowerShellV2 :      Legacy PowerShell version
:: MicrosoftWindowsPowerShellV2Root :  Root components for PowerShell 2.0
:: SMB1Protocol :                      Old file sharing protocol (vulnerable to ransomware like WannaCry)
:: SmbDirect:                          Remote Direct Memory Access (RDMA) for SMB
:: TFTP:                               Trivial File Transfer Protocol (unsecured file transfer)
:: TelnetClient :                      Unencrypted remote login client
:: WCF-TCP-PortSharing45 :             .NET Framework 4.5 TCP Port Sharing service
for %%F in ("MicrosoftWindowsPowerShellV2" "MicrosoftWindowsPowerShellV2Root" "SMB1Protocol" "SmbDirect" "TFTP" "TelnetClient" "WCF-TCP-PortSharing45") do (

    :: Check if the feature is currently enabled
    dism /Online /Get-FeatureInfo /FeatureName:%%F | findstr /C:"State : Enabled" >nul
    
    :: Disable if found
    if not errorlevel 1 (
        echo  - Disabling: %%F
        dism /Online /Disable-Feature /FeatureName:%%F /NoRestart >> "%LOG_FILE%" 2>&1
    )
)

echo Disabling unsafe windows services

:: mrxsmb10:        SMB 1.0/CIFS File Server Driver (High security risk)
:: RemoteRegistry : Allows remote users to modify Windows Registry settings
:: SNMP:            Simple Network Management Protocol (Often used for network reconnaissance)
:: SNMPTRAP:        Receives trap messages generated by local or remote SNMP agents
for %%S in ("mrxsmb10" "RemoteRegistry" "SNMP" "SNMPTRAP" ) do (
	call :SC_CONTROL "%%S" "stop"
    call :SC_CONFIGURE "%%S" "disabled"
)

:: Remove 'defaultuser0', a temporary account often left behind after Windows installation
echo Removing default user account
net user defaultuser0 /delete >> "%LOG_FILE%" 2>&1

call :LOG PRIVACY_SECURITY_MENU

:REV_ENHANCE_SECURITY
call :PATH "Security" "DefaultSecurity"

echo. & echo Default windows security registry value
reg import "Files\Security\DefaultSecurity.reg" >> "%LOG_FILE%" 2>&1

call :LOG PRIVACY_SECURITY_MENU

:SECURITY_INFO
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Security\SecurityInfo.ps1"
call :GO PRIVACY_SECURITY_MENU


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

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-5)
pause
goto NETWORK_MENU

:NETWORK_TWEAKS
call :PATH "Network" "NetworkTweaks"

echo. & echo Improve network settings via registry
reg import "Files\Network\NetworkTweaks.reg" >> "%LOG_FILE%" 2>&1

echo Optimizing TCP Global Parameters

:: fastopen=enabled :          Speeds up successive TCP connections
:: fastopenfallback=enabled :  Allows fallback to standard TCP if Fast Open fails
:: rss=enabled :               Distributes network processing across multiple CPU cores
:: autotuninglevel=high :      Optimizes the TCP receive window for high-speed connections
for %%P in ("fastopen=enabled" "fastopenfallback=enabled" "rss=enabled" "autotuninglevel=high") do (
    echo  - Setting: %%~P
    netsh int tcp set global %%~P >> "%LOG_FILE%" 2>&1
)

echo Set Cloudflare DNS on all connected interfaces
for /f "tokens=3,*" %%a in ('netsh interface show interface ^| findstr "Connected"') do (
    echo  - Set Cloudflare DNS on: %%b
    netsh interface ipv4 set dns name="%%b" static 1.1.1.1 primary >> "%LOG_FILE%" 2>&1
    netsh interface ipv4 add dns name="%%b" 1.0.0.1 index=2 >> "%LOG_FILE%" 2>&1
	
    netsh interface ipv6 set dns name="%%b" static 2606:4700:4700::1111 primary >> "%LOG_FILE%" 2>&1
    netsh interface ipv6 add dns name="%%b" 2606:4700:4700::1001 index=2 >> "%LOG_FILE%" 2>&1
)

echo Flushing DNS cache
ipconfig /flushdns >> "%LOG_FILE%" 2>&1

call :LOG NETWORK_MENU

:REV_NETWORK_TWEAKS
call :PATH "Network" "DefaultNetworkSettings"

echo. & echo Set default registry network settings
reg import "Files\Network\DefaultNetworkSettings.reg" >> "%LOG_FILE%" 2>&1

echo Reset TCP settings to default
for %%P in ("fastopen=default" "fastopenfallback=default" "rss=default" "autotuning=normal") do (
    echo  - Resetting: %%~P
    netsh int tcp set global %%~P >> "%LOG_FILE%" 2>&1
)

call :DHCP

call :LOG NETWORK_MENU

:NETWORK_RESET
cls
call :PATH "Network" "NetworkReset"

echo Stopping Network Services

:: Dhcp:      Registers and updates IP addresses and DNS
:: Dnscache:  Caches DNS names to resolve website addresses faster
:: dot3svc:   Handles authentication for wired (Ethernet) network connections
:: netman:    Manages objects in the Network
:: netprofm:  Identifies the networks the computer has connected to
:: nlasvc:    Collects and stores configuration information
:: Nsi:       Delivers network notifications
:: WlanSvc:   Connect to Wi-Fi
:: WwanSvc:   Manages mobile broadband
for %%S in ("Dhcp" "Dnscache" "dot3svc" "netman" "netprofm" "nlasvc" "Nsi" "WlanSvc" "WwanSvc") do (
    call :SC_CONTROL "%%S" "stop"
)

echo Configuring Essential Services
for %%S in ("Dhcp" "Dnscache" "nlasvc" "Nsi" "WlanSvc") do (
    call :SC_CONFIGURE "%%S" "auto"
    call :SC_CONTROL "%%S" "start"
)

echo Configuring Interface Services
for %%S in ("dot3svc" "netman" "netprofm" "WwanSvc") do (
    call :SC_CONFIGURE "%%S" "demand" 
    call :SC_CONTROL "%%S" "start"
)

:: Reset the core TCP/IP stack to factory defaults (rewrites registry keys)
echo Reset TCP/IP Stack
netsh int ip reset >> "%LOG_FILE%" 2>&1

:: Reset TCP and UDP protocols to clear any custom/corrupted configurations
echo Reset TCP/UDP
netsh int tcp reset >> "%LOG_FILE%" 2>&1
netsh int udp reset >> "%LOG_FILE%" 2>&1

:: Repair the Winsock Catalog (useful if internet is blocked by malware or bad drivers)
echo Reset Winsock
netsh winsock reset >> "%LOG_FILE%" 2>&1

:: Clear any system-wide HTTP proxy settings that might redirect traffic
echo Reset WinHTTP proxy
netsh winhttp reset proxy >> "%LOG_FILE%" 2>&1

:: Reset IPv6 specific settings to their default state
echo Reset IPv6 settings
netsh interface ipv6 reset >> "%LOG_FILE%" 2>&1

:: Restore Windows Firewall to its default out-of-the-box rules
echo Reset Firewall Rules
netsh advfirewall reset >> "%LOG_FILE%" 2>&1

:: Clears the local cache used to optimize WAN traffic
echo Resetting BranchCache
netsh branchcache reset

:: Forces the HTTP.sys driver to write all pending logs to the disk immediately
echo Flushing HTTP log buffers
netsh http flush logbuffer

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

:: Release current DHCP IP addresses for all adapters
echo Releasing IP addresses
ipconfig /release >> "%LOG_FILE%" 2>&1

:: Restart all physically connected network interfaces
:: This effectively "plugs and unplugs" the cable via software
echo Restart all connected interfaces
for /f "tokens=3,*" %%a in ('netsh interface show interface ^| findstr "Connected"') do (
    echo - Restart: %%b
    :: Disable the interface
    netsh interface set interface name="%%b" admin=disabled >> "%LOG_FILE%" 2>&1
    timeout /t 2 >nul
    :: Re-enable the interface
    netsh interface set interface name="%%b" admin=enabled >> "%LOG_FILE%" 2>&1
)

:: Request new IP addresses from the router/DHCP server
echo Renewing IP addresses
ipconfig /renew >> "%LOG_FILE%" 2>&1

:: Refresh DHCP leases and re-register DNS names with the server
echo Registering DNS name
ipconfig /registerdns >> "%LOG_FILE%" 2>&1

call :LOG NETWORK_MENU

:WIFI_PASSWORDS
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\WifiPassword.ps1"

echo. & choice /C YN /N /M "Export the results as a text file? (Y/N): "
if %errorlevel% equ 1 (
    call :TIME_STAMP_FILE "Network" "WifiPassword"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Files\Network\WifiPassword.ps1" >> "!REPORT_FILE!" 2>&1
    echo Report file saved in: !REPORT_FILE!
)
call :GO NETWORK_MENU

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

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-10)
pause
goto DNS_MENU

:SET_DNS
call :PATH "Network" "DNS"

cls & echo Set %DNS_NAME% server on all connected interfaces
for /f "tokens=3,*" %%a in ('netsh interface show interface ^| findstr "Connected"') do (
    echo  - Configure: %%b
    
    :: Set the Primary and Secondary IPv4 DNS server
    netsh interface ipv4 set dns name="%%b" static %DNS_IPv4_1% primary >> "%LOG_FILE%" 2>&1
    netsh interface ipv4 add dns name="%%b" %DNS_IPv4_2% index=2 >> "%LOG_FILE%" 2>&1
    
    :: Set the Primary and Secondary IPv6 DNS server
    netsh interface ipv6 set dns name="%%b" static %DNS_IPv6_1% primary >> "%LOG_FILE%" 2>&1
    netsh interface ipv6 add dns name="%%b" %DNS_IPv6_2% index=2 >> "%LOG_FILE%" 2>&1
)

echo Flushing DNS cache
ipconfig /flushdns >> "%LOG_FILE%" 2>&1

call :LOG DNS_MENU

:SET_DHCP
cls
call :DHCP
call :PATH "Network" "DHCP"

call :LOG DNS_MENU

:DNS_SERVER_TEST
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\DNSTest.ps1"
call :GO DNS_MENU

:DNS_STATUS
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\DNSStatus.ps1"
call :GO DNS_MENU

:NETWORK_INFO
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\NetworkInfo.ps1"
call :GO NETWORK_MENU


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

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-5)
pause
goto PROGRAMS_MANAGER_MENU

:WHERE_CHOCO
:: Check if Chocolatey (Package Manager) is already installed
where choco >nul 2>&1 && goto PROGRAMS_MENU_VAR

:: Install Chocolatey If not found
cls & echo Install Chocolatey package manager
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Programs\InstallChoco.ps1"

where choco >nul 2>&1 || (
    echo Choco not found
    echo Install it manually from: https://chocolatey.org/install
    pause
    goto PROGRAMS_MANAGER_MENU
)

:PROGRAMS_MENU_VAR
set "ON=(YES)"
set "OFF=(NO)"

:: Initialize all 18 options to "OFF" by default
for %%A in (1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18) do set "OPT%%A=%OFF%"

:PROGRAMS_MENU
cls & echo. & echo.
echo                        -------------------------------- Programs ---------------------------------
echo.
echo                           [1] Google Chrome           [7] XnViewMP              [13] VC++ (2015_2026)
echo.
echo                           [2] Brave                   [8] Sumatra PDF           [14] DirectX
echo.
echo                           [3] WinRAR                  [9] Notepad++             [15] Virtual Box
echo.
echo                           [4] 7-Zip                   [10] VS Code              [16] IObit Unlocker
echo.
echo                           [5] K-Lite Codec            [11] Git                  [17] AutoHotkey
echo.
echo                           [6] IrfanView               [12] qbittorrent          [18] MEGA
echo.
echo                        ---------------------------------------------------------------------------
echo.
echo                           [A] Select All              [D] Deselect All           [0] Back
echo.

:: Display a real-time list of what the user has selected
echo. & echo Selected:
call :SHOW_SELECTED

echo. & set "choice=" & set /p "choice=--> Select an option and press [S] to Start: "
if "%choice%"=="" goto PROGRAMS_MENU
if "%choice%"=="0" goto PROGRAMS_MANAGER_MENU
if /i "%choice%"=="S" goto INSTALL_PROGRAMS
if /i "%choice%"=="A" goto SELECT_ALL
if /i "%choice%"=="D" goto DESELECT_ALL

:: Process numerical input to toggle selections (0-18)
set "tokens=%choice:,= %"
for %%G in (%tokens%) do (
    for %%N in (1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18) do (
        if "%%G"=="%%N" call :TOGGLE_SINGLE OPT%%N
    )
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

:: Checks each option; if ON, runs the 'choco install' command with the -y (auto-confirm)
:INSTALL_PROGRAMS
cls
call :IS_ON OPT1 && (
    echo Installing Google Chrome
    choco install googlechrome -y
)
call :IS_ON OPT2 && (
    echo Installing Brave
    choco install brave -y 
)
call :IS_ON OPT3 && (
    echo Installing WinRAR
    choco install winrar -y 
)
call :IS_ON OPT4 && (
    echo Installing 7-Zip
    choco install 7zip.install -y
)
call :IS_ON OPT5 && (
    echo Installing K-Lite Codec Pack Standard
    choco install k-litecodecpack-standard -y
)
call :IS_ON OPT6 && (
    echo Installing IrfanView
    choco install irfanview -y
)
call :IS_ON OPT7 && (
    echo Installing XnView MP
	choco install xnviewmp.install -y
)
call :IS_ON OPT8 && (
    echo Installing Sumatra PDF
    choco install sumatrapdf.install -y
)
call :IS_ON OPT9 && (
    echo Installing Notepad++
    choco install notepadplusplus.install -y
)
call :IS_ON OPT10 && (
    echo Installing Visual Studio Code
    choco install vscode.install -y
)
call :IS_ON OPT11 && (
    echo Installing Git
    choco install git -y
)
call :IS_ON OPT12 && (
    echo Installing qbittorrent
    choco install qbittorrent -y
)
call :IS_ON OPT13 && (
    echo Installing VC++ Redistributables (2015_2026)
    choco install vcredist140 -y
)
call :IS_ON OPT14 && (
    echo Installing DirectX
    choco install directx -y
)
call :IS_ON OPT15 && (
    echo Installing Virtual Box
    choco install virtualbox -y
)
call :IS_ON OPT16 && (
    echo Installing IObit Unlocker
    choco install io-unlocker -y
)
call :IS_ON OPT17 && (
    echo Installing AutoHotkey
    choco install autohotkey -y
)
call :IS_ON OPT18 && (
    echo Installing MEGA
    choco install megasync -y
)
call :GO PROGRAMS_MANAGER_MENU

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

:UPDATE_PROGRAMS
cls & echo Update all installed programs from chocolatey

:: Chocolatey must be available to upgrade the programs
where choco >nul 2>&1 || (
    echo Choco not found
	pause
    goto PROGRAMS_MANAGER_MENU
)

:: Execute the upgrade command for every package managed by Chocolatey
choco upgrade all -y
call :GO PROGRAMS_MANAGER_MENU

:DOWNLOAD_MO
start "" cmd /c "Files\Programs\office.bat"
call :GO PROGRAMS_MANAGER_MENU

:REMOVE_MS
cls & echo WARNING: This will remove ALL Microsoft Store apps!
choice /C YN /N /M "Continue anyway? (Y/N): "
if errorlevel 2 goto PROGRAMS_MANAGER_MENU

powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Programs\Remove_All_MS.ps1"
call :GO PROGRAMS_MANAGER_MENU

:: Get information about all installed and startup programs
:PROGRAMS_INFO
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Programs\ProgramsInfo.ps1"
call :GO PROGRAMS_MANAGER_MENU

:CUSTOMIZATION_MENU
cls & echo. & echo.
echo                        ------------------------------ Customization ------------------------------
echo.
echo                           [1] File Explorer                                    [2] Dark Mode
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

echo. & set "choice=" & set /p "choice=Select an option: "
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
    set APPLY=Remove arrow from shortcut
	set REVERT=Default arrow shortcut
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
    set APPLY=Set Time to UTC recommended for Dual Boot with Linux Systems
	set REVERT=Set Time to Local Time
    set MENU=CUSTOMIZATION_MENU
    goto SUB_MENU
)
if "%choice%"=="7" (
    set ROUTINE=POWER_SETTINGS
    set REV_ROUTINE=REMOVE_POWER_SETTINGS
    set APPLY=Activate power settings
	set REVERT=Deleting power settings
    set MENU=CUSTOMIZATION_MENU
    goto SUB_MENU
)
if "%choice%"=="8" (
    set ROUTINE=TRASH
    set REV_ROUTINE=DEF_TRASH
    set APPLY=Disable unnecessary windows features
	set REVERT=Default unnecessary windows features
    set MENU=CUSTOMIZATION_MENU
    goto SUB_MENU
)
if "%choice%"=="9" (
    set ROUTINE=PHOTO_VIEWER
    set REV_ROUTINE=REMOVE_PHOTO_VIEWER
    set APPLY=Restore classic windows photo viewer
	set REVERT=Remove classic windows photo viewer
    set MENU=CUSTOMIZATION_MENU
    goto SUB_MENU
)
if "%choice%"=="10" goto CONTEXT_MENU
if "%choice%"=="0" goto MAIN_MENU

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-10)
pause
goto CUSTOMIZATION_MENU

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
	set REVERT=Disable display files extensions
    set MENU=FILE_EXPLORER_MENU
    goto SUB_MENU
)
if "%choice%"=="2" (
    set ROUTINE=SHOW_HIDDEN
    set REV_ROUTINE=DIS_HIDDEN
    set APPLY=Show hidden files
	set REVERT=Disable display hidden files
    set MENU=FILE_EXPLORER_MENU
    goto SUB_MENU
)
if "%choice%"=="3" (
    set ROUTINE=HIDE_RECENT
    set REV_ROUTINE=SHOW_RECENT
    set APPLY=Disable display recent files
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

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-4)
pause
goto FILE_EXPLORER_MENU

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

:: Create the "God Mode" folder on the desktop (access to all Windows settings in one list)
:POWER_SETTINGS
mkdir "%USERPROFILE%\Desktop\Powerful Settings.{ED7BA470-8E54-465E-825C-99712043E01C}" >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Delete the "God Mode" folder from the desktop
:REMOVE_POWER_SETTINGS
rd /s /q "%USERPROFILE%\Desktop\Powerful Settings.{ED7BA470-8E54-465E-825C-99712043E01C}" >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Remove the small arrow icon that appears on desktop shortcuts
:HIDE_SHORTCUT_ARROW
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons" /v 29 /d "C:\Windows\System32\imageres.dll,197" /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v link /t REG_BINARY /d 00000000 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Restore the default Windows shortcut arrow icon
:SHOW_SHORTCUT_ARROW
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons" /v 29 /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v link /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Restore the classic Windows Photo Viewer
:PHOTO_VIEWER
reg import "Files\Customization\RestoreClassicPhotoViewer.reg" >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Remove the classic Windows Photo Viewer registry entries
:REMOVE_PHOTO_VIEWER
reg import "Files\Customization\RemoveClassicPhotoViewer.reg" >nul 2>&1
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

:: Ensure NumLock is OFF at the login screen and for the current user
:NUM_LOCK_OFF
reg add "HKCU\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 0 /f >nul 2>&1
reg add "HKU\.DEFAULT\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 0 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Ensure NumLock is ON at the login screen and for the current user
:NUM_LOCK_ON
reg add "HKCU\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 2 /f >nul 2>&1
reg add "HKU\.DEFAULT\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 2 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Disable notifications
:DIS_NOTIFICATION
reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v DisableNotificationCenter /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows Defender Security Center\Notifications" /v DisableNotifications /t REG_DWORD /d 1 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Re-enable notification
:ENA_NOTIFICATION
reg delete "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v DisableNotificationCenter /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows Defender Security Center\Notifications" /v DisableNotifications /t REG_DWORD /d 0 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Set the Hardware Clock to UTC
:UTC
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:: Set the Hardware Clock to Local Time
:LOCAL_TIME
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 0 /f >nul 2>&1
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
	set REVERT=Remove options
    set MENU=CONTEXT_MENU
    goto SUB_MENU
)
if "%choice%"=="2" (
    set ROUTINE=CMD_CONTEXT_ADMIN
    set REV_ROUTINE=REV_CMD_CONTEXT_ADMIN
    set APPLY=Add "Open CMD Here (Admin)" options to context menu
	set REVERT=Remove options
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
    set APPLY=Add "Kill frozen process" option context menu
	set REVERT=Remove option
    set MENU=CONTEXT_MENU
    goto SUB_MENU
)
if "%choice%"=="0" goto CUSTOMIZATION_MENU

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-4)
pause
goto CONTEXT_MENU

:CMD_CONTEXT
:: Define the menu text and add the cmd icon
reg add "HKEY_CURRENT_USER\Software\Classes\Directory\shell\OpenCmdHereUser" /ve /d "Open CMD Here" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Classes\Directory\shell\OpenCmdHereUser" /v "Icon" /d "cmd.exe" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Classes\Directory\shell\OpenCmdHereUser\command" /ve /d "cmd.exe /k pushd \"%%1\"" /f >nul 2>&1

:: Repeat the process for the background
reg add "HKEY_CURRENT_USER\Software\Classes\Directory\Background\shell\OpenCmdHereUser" /ve /d "Open CMD Here" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Classes\Directory\Background\shell\OpenCmdHereUser" /v "Icon" /d "cmd.exe" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Classes\Directory\Background\shell\OpenCmdHereUser\command" /ve /d "cmd.exe /k pushd \"%%V\"" /f >nul 2>&1
call :GO CONTEXT_MENU

:: Remove the "Open Command Prompt Here
:REV_CMD_CONTEXT
reg delete "HKEY_CURRENT_USER\Software\Classes\Directory\shell\OpenCmdHereUser" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Software\Classes\Directory\Background\shell\OpenCmdHereUser" /f >nul 2>&1
call :GO CONTEXT_MENU

:: Add "Open Command Prompt Here (Admin)" to folder and background context menus
:CMD_CONTEXT_ADMIN
:: Define the menu text and add the UAC shield icon
reg add "HKCR\Directory\shell\OpenCmdHere" /ve /d "Open CMD Here (Admin)" /f >nul 2>&1
reg add "HKCR\Directory\shell\OpenCmdHere" /v "HasLUAShield" /t REG_SZ /d "" /f >nul 2>&1
reg add "HKCR\Directory\shell\OpenCmdHere" /v "Icon" /d "cmd.exe" /f >nul 2>&1

:: Use PowerShell to trigger a CMD process with 'RunAs' (Administrator) privileges in the current directory
reg add "HKCR\Directory\shell\OpenCmdHere\command" /ve /d "powershell -Command \"Start-Process cmd -ArgumentList '/s','/k','pushd %%V' -Verb RunAs\"" /f >nul 2>&1

:: Repeat the process for the background of a folder (right-clicking on empty space)
reg add "HKCR\Directory\Background\shell\OpenCmdHere" /ve /d "Open CMD Here (Admin)" /f >nul 2>&1
reg add "HKCR\Directory\Background\shell\OpenCmdHere" /v "HasLUAShield" /t REG_SZ /d "" /f >nul 2>&1
reg add "HKCR\Directory\Background\shell\OpenCmdHere" /v "Icon" /d "cmd.exe" /f >nul 2>&1
reg add "HKCR\Directory\Background\shell\OpenCmdHere\command" /ve /d "powershell -Command \"Start-Process cmd -ArgumentList '/s','/k','pushd %%V' -Verb RunAs\"" /f >nul 2>&1
call :GO CONTEXT_MENU

:: Remove the "Open Command Prompt Here (Admin)"
:REV_CMD_CONTEXT_ADMIN
reg delete "HKCR\Directory\shell\OpenCmdHere" /f >nul 2>&1
reg delete "HKCR\Directory\Background\shell\OpenCmdHere" /f >nul 2>&1
call :GO CONTEXT_MENU

:: Add "Restart Explorer" to the Desktop right-click menu
:RESTART_EXPLORER
reg add "HKCU\Software\Classes\DesktopBackground\Shell\RestartExplorer" /ve /d "Restart Explorer" /f >nul 2>&1
reg add "HKCU\Software\Classes\DesktopBackground\Shell\RestartExplorer" /v "Icon" /d "explorer.exe,0" /f >nul 2>&1

:: The command kills the explorer.exe process and immediately restarts it
reg add "HKCU\Software\Classes\DesktopBackground\Shell\RestartExplorer\command" /ve /d "cmd.exe /c taskkill /f /im explorer.exe && start explorer.exe" /f >nul 2>&1
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
echo                          [3] Activate Windows                                [4] System Info
echo.
echo                                                         [0] Back
echo.  
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto RESTORE_POINT
if "%choice%"=="2" goto REGISTRY_BACKUP_MENU
if "%choice%"=="3" goto ACTIVATION_MENU
if "%choice%"=="4" goto SYSTEM_INFO
if "%choice%"=="0" goto MAIN_MENU

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-4)
pause
goto SYSTEM_MENU

:RESTORE_POINT
cls
call :PATH "System" "RestorePoint"

:: Execute a PowerShell script to create restore point
echo Creating System Restore Point
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\System\CreateRestorePoint.ps1" >> "%LOG_FILE%" 2>&1

if %errorlevel% equ 0 call :LOG SYSTEM_MENU

:: If Creating failed (errorlevel>0)
echo Creating a restore point failed. Attempting to fix system dependencies
    
:: Enable System Restore via registry if they were disabled by policy
echo. & echo Enabling restore point from registry
reg import "Files\System\EnableRestorePoint.reg" >> "%LOG_FILE%" 2>&1
    
:: Force a Group Policy update to ensure the registry changes are applied immediately
echo Updating policies
gpupdate /force >> "%LOG_FILE%" 2>&1
    
echo Starting restore point services
	
:: VSS :    Volume Shadow Copy Service (Manages data backup/snapshots)
:: swprv :  Microsoft Software Shadow Copy Provider (Coordinates snapshot creation)
for %%S in ("VSS" "swprv") do (
    call :SC_CONFIGURE "%%S" "demand"
    call :SC_CONTROL "%%S" "start"
)

echo Creating system restore point
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\System\CreateRestorePoint.ps1" >> "%LOG_FILE%" 2>&1

if %errorlevel% neq 0 (
    echo. & echo Creating system restore point has failed
)

call :LOG SYSTEM_MENU

:REGISTRY_BACKUP_MENU
cls & echo. & echo.
echo                        ------------------------------ Registry Backup ----------------------------
echo.
echo                           [1] Full Backup                                    [2] Important Backup
echo. 
echo                           [3] Automatic Backup                               [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto FULL_BACKUP 
if "%choice%"=="2" goto IMPORTANT_BACKUP

if "%choice%"=="3" (
    set ROUTINE=AUTOMATIC_BACKUP
    set REV_ROUTINE=REV_AUTOMATIC_BACKUP
    set APPLY=Enable automatic registry backup task
	set REVERT=Disable automatic registry backup task
    set MENU=REGISTRY_BACKUP_MENU
    goto SUB_MENU
)
if "%choice%"=="0" goto SYSTEM_MENU 

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-3)
pause
goto REGISTRY_BACKUP_MENU

:FULL_BACKUP
cls
call :PATH "System" "FullRegistryBackup"
call :TIME_STAMP_DIR "System" "FullRegistryBackup"

:: Define the main system Hives for binary export
echo Creating Full Registry Backup

for %%A in (
    "HKLM\SYSTEM,SYSTEM"
    "HKLM\SOFTWARE,SOFTWARE"
    "HKLM\SAM,SAM"
    "HKLM\SECURITY,SECURITY"
    "HKU\.DEFAULT,DEFAULT"
    "HKCU\Software\Classes,UsrClass"
) do (
    for /f "tokens=1,2 delims=," %%B in (%%A) do (
        echo  Export: %%B
        reg save "%%B" "%BACKUP_DIR%\%%C.hive" /y >>"%LOG_FILE%" 2>&1
    )
)

if exist "%BACKUP_DIR%\*.hive" (
    choice /C YN /N /M "Compress files? (Y/N): "
    if errorlevel 2 (
        echo. & echo Backup files saved in: %BACKUP_DIR%
    ) else (
	    :: Call PowerShell to zip the hives files
        powershell -NoProfile -ExecutionPolicy Bypass -File "Files\System\CompressHiveFiles.ps1" "%BACKUP_DIR%"
    )
) else (
    echo No hive files found
)

call :LOG REGISTRY_BACKUP_MENU

:IMPORTANT_BACKUP
cls
call :PATH "System" "ImportantRegistryBackup"
call :TIME_STAMP_DIR "System" "ImportantRegistryBackup"

echo Creating Important Registry Backup
:: Read specific keys from an external text file for a targeted backup
for /f "usebackq tokens=1,2 delims=," %%K in ("Files\System\RegKey.txt") do (
    echo  Export: %%K
    reg export "%%K" "%BACKUP_DIR%\%%L" /y >>"%LOG_FILE%" 2>&1
)

if exist "%BACKUP_DIR%\*.reg" (
    choice /C YN /N /M "Compress files? (Y/N): "
    if errorlevel 2 (
        echo. & echo Backup files saved in: %BACKUP_DIR%
    ) else (
        powershell -NoProfile -ExecutionPolicy Bypass -File "Files\System\CompressHiveFiles.ps1" "%BACKUP_DIR%"
    )
) else (
    echo No hive files found
)

call :LOG REGISTRY_BACKUP_MENU

:: Enable periodic registry backup (RegBack)
:: The backup will be saved in: C:\Windows\System32\config\RegBack
:AUTOMATIC_BACKUP
reg add "HKLM\System\CurrentControlSet\Control\Session Manager\Configuration Manager" /v EnablePeriodicBackup /t REG_DWORD /d 1 /f >nul 2>&1
call :GO REGISTRY_BACKUP_MENU

:: Disable periodic registry backup
:REV_AUTOMATIC_BACKUP
reg add "HKLM\System\CurrentControlSet\Control\Session Manager\Configuration Manager" /v EnablePeriodicBackup /t REG_DWORD /d 0 /f >nul 2>&1
call :GO REGISTRY_BACKUP_MENU

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

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-2)
pause
goto ACTIVATION_MENU

:: Activating Windows and Microsoft Office using MAS script
:RUN_ACTIVATION
cls & echo Activating Windows and Microsoft Office
powershell -NoP -EP Bypass -c "irm https://get.activated.win | iex"
call :GO ACTIVATION_MENU

:: Check if the Machine is Activated or not
:CHECK_ACTIVATION
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\System\ActivationStatus.ps1"
call :GO ACTIVATION_MENU

:: Display basic system information 
:SYSTEM_INFO
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\System\SystemInfo.ps1"
call :GO SYSTEM_MENU


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

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-7)
pause
goto TOOLS_MENU

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

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-4)
pause
goto DISM_MENU

:: Perform a quick check to see if the OS has already flagged any corruption
:DISM_CHECK_HEALTH
cls & echo Checking windows component health
dism /Online /Cleanup-Image /CheckHealth
call :GO DISM_MENU

:: This does not fix errors, it only reports them
:DISM_SCAN_HEALTH
cls & echo Scanning windows component health
dism /Online /Cleanup-Image /ScanHealth
call :GO DISM_MENU

:: Repair the Windows Image by downloading healthy files from Windows Update
:DISM_RESTORE_HEALTH
cls & echo Fix Windows component
dism /Online /Cleanup-Image /RestoreHealth
call :GO DISM_MENU

:: Clean up the WinSxS folder by removing superseded (old) versions of components
:DISM_COMPONENT_CLEANUP
cls & echo Windows component
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
    if exist %%d:\ echo %%d:
)

echo. & echo Enter drive letter to check
echo Enter "0" to go back

set "drive=" & set /p "drive= "
if "%drive%"=="0" goto TOOLS_MENU

:: Handle empty input
if not defined drive (
    echo. & echo [ERROR] Invalid selection. Please enter a drive letter
    pause
    goto CHKDSK
)

:: Remove quotes if present
set "drive=%drive:"=%"

:: Trim to first character only
set "drive=%drive:~0,1%"

:: Convert to uppercase (optional but recommended)
for %%A in (%drive%) do set "drive=%%~A"

:: Validate that the drive exists
if not exist "%drive%:\" (
    echo. & echo Invalid drive letter: %drive%    
    pause
    goto CHKDSK
)

:CHKDSK_MENU
cls & echo. & echo.
echo                        --------------------------------- CHKDSK ----------------------------------
echo.
echo                          [1] Drive Status                                    [2] Fix File System
echo.
echo                          [3] Fix Bad Sectors                                 [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option for "%drive%" drive: "
if "%choice%"=="1" goto DISK_STATUS 
if "%choice%"=="2" goto FIX_FILE
if "%choice%"=="3" goto FIX_SECTORS
if "%choice%"=="0" goto CHKDSK

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-3)
pause
goto CHKDSK_MENU

:: Scans for errors but does not fix anything
:DISK_STATUS
cls & echo Displays status of drive: %drive%
timeout /t 2 >nul
chkdsk %drive%:
call :GO CHKDSK_MENU

:FIX_FILE
cls & echo Fix file system errors in drive: %drive%
timeout /t 2 >nul

:: /f: Fixes errors on the disk
:: /x: Forces the volume to dismount first if necessary
chkdsk %drive%: /f /x
call :GO CHKDSK_MENU

:FIX_SECTORS
cls & echo Fix file system and recovering files from bad sectors in drive: %drive%
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
cleanmgr.exe /d C: /VERYLOWDISK
goto TOOLS_MENU

:: Delete "%ProgramData%\Win_Tweaks" folder
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

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-3)
pause
goto OTHER_MENU

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
    set "TASK_RESULT=SUCCESS"

    :: Verify the task if exists
    schtasks /query /tn "%%i" >nul 2>&1
    if errorlevel 1 (
        set "TASK_RESULT=NOT_FOUND"
    ) else (
        :: Apply the change (Disable or Enable)
        if /i "%~1"=="Disable" (
            schtasks /change /tn "%%i" /disable >nul 2>&1
        ) else (
            schtasks /change /tn "%%i" /enable >nul 2>&1
        )

        :: Check if the command is failed
        if errorlevel 1 (
            set "TASK_RESULT=FAILED"
        )
    )

    :: Log the result for every single task
    echo !TASK_RESULT!: !TASK_NAME!>>"%LOG_FILE%"
)
goto :eof

:CLEANING_FUNCTION
echo Cleaning Temp
for %%F in ("%TEMP%" "%SYSTEMROOT%\TEMP") do (
    if exist "%%~F" (
        :: Delete all files in the directory
        del /f /q "%%~F\*" >nul 2>&1
        :: Remove all sub-directories
        for /d %%D in ("%%~F\*") do (
            rd /s /q "%%D" >nul 2>&1
        )
    )
)

:: Clear the "Recent Items" list shown in File Explorer
echo Cleaning Recent Files
del /f /q "%APPDATA%\Microsoft\Windows\Recent\*.lnk" >nul 2>&1

:: This forces Windows to recreate icons, which can fix "broken" file thumbnails
echo Cleaning Thumbnail and icons cache
del /f /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache*.db" >nul 2>&1
del /f /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache*.db" >nul 2>&1

:: Delete the text file that stores every command you've ever typed into PowerShell
echo Cleaning PowerShell command history
del /f /q "%APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" >nul 2>&1
goto :eof

:FINAL_CLEAN
choice /C YN /N /M "Run Disk Cleanup to complete the cleaning? (Y/N): "
if %errorlevel% equ 1 (
    echo Running Disk Cleanup
    :: /VERYLOWDISK: Runs cleanmgr with all boxes checked and no user prompts
    cleanmgr.exe /d C: /VERYLOWDISK
)

:: Force empty the Recycle Bin for all drives
echo Empty Recycle Bin
powershell -Command "Clear-RecycleBin -Force" >nul 2>&1
goto :eof

:DHCP
echo Set DHCP on all connected interfaces

:: Find all active network adapters
for /f "tokens=3,*" %%a in ('netsh interface show interface ^| findstr "Connected"') do (
    echo - Resetting DNS on: %%b
    
    :: Revert IPv4 to obtain an IP address automatically from the router
    netsh interface ipv4 set address name="%%b" source=dhcp >> "%LOG_FILE%" 2>&1
    
    :: Revert IPv4 to obtain DNS servers automatically
    netsh interface ipv4 set dnsservers name="%%b" source=dhcp >> "%LOG_FILE%" 2>&1

    :: Revert IPv6 to obtain DNS servers automatically
    netsh interface ipv6 set dnsservers name="%%b" source=dhcp >> "%LOG_FILE%" 2>&1
)

echo Flushing DNS cache
ipconfig /flushdns >> "%LOG_FILE%" 2>&1
goto :eof

:SC_CONTROL
:: %~1 = Service Name
:: %~2 = Action (stop or start)
sc query "%~1" >nul 2>&1
if %errorlevel% equ 0 (
    if /i "%~2"=="stop" (
        sc stop "%~1" >nul 2>&1
        if %errorlevel% equ 0 (
            echo [STOPPED] %~1 >>"%LOG_FILE%" 2>&1
        ) else (
            echo [FAILED TO STOP] %~1 >>"%LOG_FILE%" 2>&1
        )
    ) else if /i "%~2"=="start" (
        sc start "%~1" >nul 2>&1
        if %errorlevel% equ 0 (
            echo [STARTED] %~1 >>"%LOG_FILE%" 2>&1
        ) else (
            echo [FAILED TO START] %~1 >>"%LOG_FILE%" 2>&1
        )
    )
) else (
    echo [NOT FOUND] %~1 >>"%LOG_FILE%" 2>&1
)
goto :eof

:SC_CONFIGURE
:: %~1 = Service Name
:: %~2 = Start Type
sc query "%~1" >nul 2>&1
if %errorlevel% equ 0 (
    sc config "%~1" start= %~2 >nul 2>&1
    if %errorlevel% equ 0 (
        echo [SUCCESS] %~1 >>"%LOG_FILE%" 2>&1
    ) else (
        echo [FAILED] %~1 >>"%LOG_FILE%" 2>&1
    )
) else (
    echo [NOT FOUND] %~1 >>"%LOG_FILE%" 2>&1
)
goto :eof

:REG_CONFIGURE
:: Check if the service key exists
reg query "HKLM\SYSTEM\CurrentControlSet\Services\%1" >nul 2>&1
if %errorlevel% equ 0 (
    :: Set the Start Type value
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\%1" /v Start /t REG_DWORD /d %2 /f >nul 2>&1
    if %errorlevel% equ 0 (
        echo [SUCCESS] %1 >> "%LOG_FILE%" 2>&1
    ) else (
        echo [FAILED] %1 >> "%LOG_FILE%" 2>&1
    )
) else (
    echo [NOT FOUND] %1 >> "%LOG_FILE%" 2>&1
)
goto :eof

:TIME_STAMP_FILE
:: Retrieve current system time in a format that won't break file paths
for /f "tokens=*" %%a in ('powershell -Command "Get-Date -Format 'yyyyMMddHHmmss'"') do set datetime=%%a
set "REPORT_DIR=%ProgramData%\Win_Tweaks\%~1"

:: Construct the filename with a clean YYYY-MM-DD_HH-MM-SS format
set "REPORT_FILE=%REPORT_DIR%\%~2_%datetime:~0,4%-%datetime:~4,2%-%datetime:~6,2%_%datetime:~8,2%-%datetime:~10,2%-%datetime:~12,2%.txt"

if not exist "%REPORT_DIR%" (
    mkdir "%REPORT_DIR%" >nul 2>&1
    if errorlevel 1 (
        echo Failed to create directory: %REPORT_DIR%
        pause
		exit /b 1
    )
)
goto :eof

:TIME_STAMP_DIR
for /f "tokens=*" %%a in ('powershell -Command "Get-Date -Format 'yyyyMMddHHmmss'"') do set datetime=%%a
set "BACKUP_DIR=%ProgramData%\Win_Tweaks\%~1\%~2_%datetime:~0,4%-%datetime:~4,2%-%datetime:~6,2%_%datetime:~8,2%-%datetime:~10,2%-%datetime:~12,2%"

if not exist "%BACKUP_DIR%" (
    mkdir "%BACKUP_DIR%" >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Failed to create directory: %BACKUP_DIR%
        pause
		exit /b 1
    )
)
goto :eof

:PATH
:: %~1 = Subfolder name
:: %~2 = Log filename

:: Define the base directory within ProgramData for organizational consistency
set "TARGET_DIR=%ProgramData%\Win_Tweaks\%~1"

:: Create the folder if it not exist
:: Prompt to exit if creation is failed
if not exist "%TARGET_DIR%" (
    mkdir "%TARGET_DIR%" >nul 2>&1
    if errorlevel 1 (
        echo Failed to create directory: %TARGET_DIR%
        pause
        exit /b 1
    )
)

:: Set the full path for the current log file
set "LOG_FILE=%TARGET_DIR%\%~2.log"

:: Initialize the log file with a fresh timestamp header for every session
(echo Start at %time% %date% & echo.) > "%LOG_FILE%" 2>&1
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

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-2)
pause
goto SUB_MENU

:LOG
echo. & echo More details in: %LOG_FILE%
call :GO %1

:GO
:: %1 = The label of the menu to return to
echo. & echo The operation is done.
pause
goto %1

:: ----------------------------------------------------------------< END >----------------------------------------------------------------