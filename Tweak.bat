@echo off
setlocal enabledelayedexpansion
title Win_Tweaks

net session >nul 2>&1
if errorlevel 1 (
    echo This script must be run with Administrator privileges
    pause & exit
)

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
if "%choice%"=="4" goto PROGRAMS_MANAGER
if "%choice%"=="5" goto CUSTOMIZATION_MENU
if "%choice%"=="6" goto SYSTEM_MENU
if "%choice%"=="7" goto TOOLS_MENU
if "%choice%"=="8" goto OTHER_MENU
if "%choice%"=="0" exit

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-8)
pause & goto MAIN_MENU

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
    set Routine=DISABLE_TASKS
    set Rev_Routine=ENABLE_TASKS
    set Apply=Disable unnecessary scheduled tasks
	set Revert=Enable unnecessary scheduled tasks
    set Menu=PERFORMANCE_MENU
    goto SUB_MENU
)
if "%choice%"=="3" (
    set Routine=BOOT_TWEAKS
    set Rev_Routine=REV_BOOT_TWEAKS
    set Apply=Enhance boot up settings
	set Revert=Set boot up settings to default
    set Menu=PERFORMANCE_MENU
    goto SUB_MENU
)
if "%choice%"=="4" goto CLEAN_UP
if "%choice%"=="5" goto POWER_PLAN_MENU
if "%choice%"=="6" goto HW_INFO_MENU
if "%choice%"=="0" goto MAIN_MENU

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-7)
pause & goto PERFORMANCE_MENU

:SERVICES_MENU
cls & echo. & echo.
echo                        -------------------------------- Services ---------------------------------
echo.
echo                          [1] Services Tweaks                                [2] Services Tweaks (Safe)
echo.
echo                          [3] Default Services                               [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" (
    set File=%~dp0Files\Performance\ServicesTweaks.txt
    set Message=Tweaking windows services
    set Log=ServicesTweaks
    goto SET_SERVICES
)
if "%choice%"=="2" (
    set File=%~dp0Files\Performance\SafeServicesTweaks.txt
    set Message=Tweaking windows services in Safely mode
    set Log=SafeServicesTweaks
    goto SET_SERVICES
)
if "%choice%"=="3" (
    set File=%~dp0Files\Performance\DefaultServicesSettings.txt
    set Message=Revert most windows services to default settings
    set Log=DefaultServicesSettings
    goto SET_SERVICES
)
if "%choice%"=="0" goto PERFORMANCE_MENU

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-3)
pause & goto SERVICES_MENU

:SET_SERVICES
echo. & echo %Message%
call :PATH "Performance" "%Log%"

for /f "usebackq tokens=1,2 delims=," %%A in ("%File%") do (
    if not "%%A"=="" (
	set "line=%%A"
    if not "!line:~0,1!"=="#" (
            set "SVC=%%A"
            set "MODE=%%B"
            echo !SVC! -> !MODE!
            set "RESULT=SUCCESS"            
            if /I "!MODE!"=="Automatic" (
                sc config "!SVC!" start= auto >nul 2>&1
                if errorlevel 1 (
                    sc query "!SVC!" >nul 2>&1
                    if errorlevel 1 (
                        set "RESULT=NOT_FOUND"
                    ) else (
                        set "RESULT=FAILED"
                    )
                )
            ) else if /I "!MODE!"=="Manual" (
                sc config "!SVC!" start= demand >nul 2>&1
                if errorlevel 1 (
                    sc query "!SVC!" >nul 2>&1
                    if errorlevel 1 (
                        set "RESULT=NOT_FOUND"
                    ) else (
                        set "RESULT=FAILED"
                    )
                )
            ) else if /I "!MODE!"=="Disabled" (
                sc config "!SVC!" start= disabled >nul 2>&1
                if errorlevel 1 (
                    sc query "!SVC!" >nul 2>&1
                    if errorlevel 1 (
                        set "RESULT=NOT_FOUND"
                    ) else (
                        set "RESULT=FAILED"
                    )
                )
            ) else if /I "!MODE!"=="AutomaticDelayedStart" (
                sc config "!SVC!" start= delayed-auto >nul 2>&1
                if errorlevel 1 (
                    sc query "!SVC!" >nul 2>&1
                    if errorlevel 1 (
                        set "RESULT=NOT_FOUND"
                    ) else (
                        set "RESULT=FAILED"
                    )
                )
            )
            echo !RESULT!: !SVC! _ !MODE! >> "%LogFile%" 2>&1
        )
    )
)

echo More details in: %LogFile%
call :GO PERFORMANCE_MENU

:DISABLE_TASKS
call :PATH "Performance" "DisableScheduledTasks"
call :SET_TASKS "Disable" "%~dp0Files\Performance\TasksList.txt"
call :SET_TASKS "Disable" "%~dp0Files\Security\TelemetryTasks.txt"
echo More details in: %LogFile%
call :GO PERFORMANCE_MENU

:ENABLE_TASKS
call :PATH "Performance" "EnableScheduledTasks"
call :SET_TASKS "Enable" "%~dp0Files\Performance\TasksList.txt"
call :SET_TASKS "Enable" "%~dp0Files\Security\TelemetryTasks.txt"
echo More details in: %LogFile%
call :GO PERFORMANCE_MENU

:BOOT_TWEAKS
call :PATH "Performance" "BootTweaks"

echo. & echo Import Boot up tweaks registry settings
reg import "%~dp0Files\Performance\BootTweaks.reg" >> "%LogFile%" 2>&1

echo Deleting startup shortcuts
del /f /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\*.lnk" >> "%LogFile%" 2>&1
del /f /q "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Startup\*.lnk" >> "%LogFile%" 2>&1

echo More details in: %LogFile%
call :GO PERFORMANCE_MENU

:REV_BOOT_TWEAKS
call :PATH "Performance" "DefaultBootSettings"

echo. & echo Import default Boot up registry settings
reg import "%~dp0Files\Performance\DefaultBootSettings.reg" >> "%LogFile%" 2>&1

echo More details in: %LogFile%
call :GO PERFORMANCE_MENU

:CLEAN_UP
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
    echo Browsers are currently open
    choice /C YN /N /M "Close them? (Y/N)"
    if errorlevel 2 (
        echo Skipping files currently used by browsers
    ) else (
        echo Closing browsers
        for %%B in (%BROWSERS%) do (
            taskkill /IM "%%B" /F /T  >nul 2>&1
        )
        timeout /t 2 >nul
    )
)

for %%B in (
    "Google\Chrome|Google Chrome"
    "Microsoft\Edge|Microsoft Edge"
    "BraveSoftware\Brave-Browser|Brave"
) do (
    for /f "tokens=1,2 delims=|" %%A in ("%%~B") do (
        if exist "%LOCALAPPDATA%\%%A\User Data" (
            echo Cleaning %%B
            for %%D in (
                "Default\Cache"
                "Default\Code Cache"
                "Default\GPUCache"
                "ShaderCache"
                "Default\File System"
                "Default\Service Worker"
                "Default\Application Cache"
                "Default\Media Cache"
            ) do (
                if exist "%LOCALAPPDATA%\%%A\User Data\%%~D" (
                    rd /s /q "%LOCALAPPDATA%\%%A\User Data\%%~D"  >nul 2>&1
                )
            )
            del /f /q "%LOCALAPPDATA%\%%A\User Data\*.tmp"  >nul 2>&1
        )
    )
)

for %%B in (
    "Mozilla\Firefox|Mozilla Firefox"
) do (
    for /f "tokens=1,2 delims=|" %%A in ("%%~B") do (
        if exist "%AppData%\%%A\Profiles" (
            echo Cleaning %%B
            for /d %%P in ("%AppData%\%%A\Profiles\*") do (
                for %%D in (
                    "cache2"
                    "thumbnails"
                    "jumpListCache"
                    "OfflineCache"
                    "minidumps"
                ) do (
                    if exist "%%P\%%~D" (
                        rd /s /q "%%P\%%~D" >nul 2>&1
                    )
                )
            )
            if exist "%AppData%\%%A\Crash Reports" (
                rd /s /q "%AppData%\%%A\Crash Reports" >nul 2>&1
            )
        )
    )
)

call :CLEANING_FUNCTION

echo Cleaning Recent Files
del /f /q "%APPDATA%\Microsoft\Windows\Recent\*.lnk" >nul 2>&1

call :FINAL_CLEAN
call :GO PERFORMANCE_MENU

:POWER_PLAN_MENU
cls & echo. & echo.
echo                        ------------------------------- Power Plan --------------------------------
echo.
echo                          [1] High Performance                                    [2] Balanced
echo.
echo                          [3] Power Saver                                         [4] Active Plan
echo.
echo                                                         [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto PLAN_HIGH
if "%choice%"=="2" goto PLAN_BALANCED
if "%choice%"=="3" goto PLAN_SAVER
if "%choice%"=="4" goto ACTIVE_PLAN
if "%choice%"=="0" goto PERFORMANCE_MENU

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-4)
pause & goto POWER_PLAN_MENU

:PLAN_HIGH
echo. & echo Activate high performance power plan
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
call :GO POWER_PLAN_MENU

:PLAN_BALANCED
echo. & echo Activate balanced power plan
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e >nul 2>&1
call :GO POWER_PLAN_MENU

:PLAN_SAVER
echo. & echo Activate power saver plan
powercfg /setactive a1841308-3541-4fab-bc81-f71556f20b4a >nul 2>&1
call :GO POWER_PLAN_MENU

:ACTIVE_PLAN
set "TEMP_FILE=%TEMP%\ActivePowerPlan.guid"
powercfg /getactivescheme > "%TEMP_FILE%" 2>&1

for /f "tokens=4" %%A in (%TEMP_FILE%) do (
    set "PLAN_GUID=%%A"
)
set "PLAN_GUID=%PLAN_GUID: =%"

if /I "!PLAN_GUID!"=="381b4222-f694-41f0-9685-ff5bb260df2e" (
    set "PLAN_NAME=Balanced"
) else if /I "!PLAN_GUID!"=="8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" (
    set "PLAN_NAME=High Performance"
) else if /I "!PLAN_GUID!"=="a1841308-3541-4fab-bc81-f71556f20b4a" (
    set "PLAN_NAME=Power Saver"
) else if /I "!PLAN_GUID!"=="e9a42b02-d5df-448d-aa00-03f14749eb61" (
    set "PLAN_NAME=Ultimate Performance"
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
pause & goto HW_INFO_MENU

:CPU_INFO
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Files\Performance\CPUInfo.ps1"
call :GO HW_INFO_MENU

:GPU_INFO
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Files\Performance\GPUInfo.ps1"
call :GO HW_INFO_MENU

:HARD_DISK_INFO
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Files\Performance\HardDiskInfo.ps1"
call :GO HW_INFO_MENU

:RAM_INFO
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Files\Performance\MemoryInfo.ps1"
call :GO HW_INFO_MENU

:MOTHERBOARD_INFO
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Files\Performance\MotherboardInfo.ps1"
call :GO HW_INFO_MENU

:BATTERY_INFO
cls & echo Creating battery report
powercfg /batteryreport /output "%USERPROFILE%\Documents\BatteryReport.html"
call :GO HW_INFO_MENU


:PRIVACY_SECURITY_MENU
cls & echo. & echo.
echo                        --------------------------- Privacy and security --------------------------
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
    set Routine=DISABLE_TELEMETRY
    set Rev_Routine=REV_DISABLE_TELEMETRY
    set Apply=Disable windows telemetry and some tracking components
	set Revert=Default windows telemetry and some tracking components
    set Menu=PRIVACY_SECURITY_MENU
    goto SUB_MENU
)
if "%choice%"=="2" goto PRIVACY_CLEANUP
if "%choice%"=="3" goto WINDOWS_UPDATES_MENU
if "%choice%"=="4" (
    set Routine=DISABLE_DEFENDER
    set Rev_Routine=ENABLE_DEFENDER
    set Apply=Disable Windows Defender
	set Revert=Enable Windows Defender
    set Menu=PRIVACY_SECURITY_MENU
    goto SUB_MENU
)
if "%choice%"=="5" (
    set Routine=ENHANCE_SECURITY
    set Rev_Routine=REV_ENHANCE_SECURITY
    set Apply=Enhance system security
	set Revert=Set security settings to default
    set Menu=PRIVACY_SECURITY_MENU
    goto SUB_MENU
)
if "%choice%"=="6" goto SECURITY_INFO
if "%choice%"=="0" goto MAIN_MENU

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-6)
pause & goto PRIVACY_SECURITY_MENU

:DISABLE_TELEMETRY
call :PATH "Security" "DisableTelemetry"

echo. & echo Disable windows telemetry via registry
reg import "%~dp0Files\Security\DisableTelemetry.reg" >> "%LogFile%" 2>&1

echo Disabling windows telemetry services
for %%S in (DiagTrack dmwappushsvc DiagSvcs WerSvc CDPUserSvc lfsvc) do call :CONFIGURE_SERVICE "%%S" "disabled"

echo Disable windows telemetry scheduled tasks
call :SET_TASKS "disable" "%~dp0Files\Security\TelemetryTasks.txt"

echo Blocking windows telemetry and trash domains
set "HOSTS_PATH=%SystemRoot%\System32\drivers\etc\hosts"
attrib -r "%HOSTS_PATH%" >> "%LogFile%" 2>&1
for /f "usebackq delims=" %%L in ("%~dp0Files\Security\TrackingDomains.txt") do (
    set "LINE=%%L"
    findstr /C:"!LINE!" "%HOSTS_PATH%" >nul
    if !errorLevel! neq 0 (
        echo !LINE! >> "%HOSTS_PATH%"
    )
)

echo Flushing DNS cache
ipconfig /flushdns >> "%LogFile%" 2>&1

echo More details in: %LogFile%
call :GO PRIVACY_SECURITY_MENU

:REV_DISABLE_TELEMETRY
call :PATH "Security" "DefaultTelemetry"
set "HOSTS_PATH=%SystemRoot%\System32\drivers\etc\hosts"
set "TEMP_FILE=%temp%\HostsClean.txt"

echo. & echo Default windows telemetry registry key
reg import "%~dp0Files\Security\DefaultTelemetry.reg" >> "%LogFile%" 2>&1

echo Set window telemetry services to manual startup
for %%S in (DiagTrack dmwappushsvc DiagSvcs WerSvc CDPUserSvc lfsvc) do call :CONFIGURE_SERVICE "%%S" "demand"

echo Delete window telemetry and trash domains
attrib -r "%HOSTS_PATH%" >> "%LogFile%" 2>&1
findstr /V /L /G:"%~dp0Files\Security\TrackingDomains.txt" "%HOSTS_PATH%" > "%TEMP_FILE%"

copy /y "%TEMP_FILE%" "%HOSTS_PATH%" >> "%LogFile%" 2>&1
del "%TEMP_FILE%" >nul 2>&1

echo Flushing DNS cache
ipconfig /flushdns >> "%LogFile%" 2>&1

echo More details in: %LogFile%
call :GO PRIVACY_SECURITY_MENU

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

if exist "%LOCALAPPDATA%\Google\Chrome\User Data\" (
    echo Cleaning Google Chrome data
    for /d %%i in ("%LOCALAPPDATA%\Google\Chrome\User Data\*") do (
        rd /s /q "%%i" >nul 2>&1
    )
)

if exist "%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\" (
    echo Cleaning Brave data
    for /d %%i in ("%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\*") do (
        rd /s /q "%%i" >nul 2>&1
    )
)

if exist "%LOCALAPPDATA%\Microsoft\Edge\User Data\" (
    echo Cleaning Microsoft Edge data
    for /d %%i in ("%LOCALAPPDATA%\Microsoft\Edge\User Data\*") do (
        rd /s /q "%%i" >nul 2>&1
    )
)

if exist "%LOCALAPPDATA%\Mozilla\Firefox\Profiles\" (
    echo Cleaning Firefox data
    for /d %%i in ("%LOCALAPPDATA%\Mozilla\Firefox\Profiles\*") do (
        rd /s /q "%%i" >nul 2>&1
    )
)

echo Cleaning registry entries
reg import "%~dp0Files\Security\PrivacyCleanup.reg" >nul 2>&1

call :CLEANING_FUNCTION

echo Cleaning Recent Files
del /f /s /q "%APPDATA%\Microsoft\Windows\Recent\*.*" >nul 2>&1

echo Cleaning prefetch files
del /f /q "%SystemRoot%\Prefetch\*.*" >nul 2>&1

echo Cleaning system log files
del /f /s /q "%SystemRoot%\System32\LogFiles\*.*" >nul 2>&1
del /f /s /q "%SystemRoot%\Logs\*.*" >nul 2>&1

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
pause & goto WINDOWS_UPDATES_MENU

:DISABLE_ALL_UPDATES
call :PATH "Security" "DisableWindowsUpdates"

echo. & echo Disable windows update via registry
reg import "%~dp0Files\Security\DisableWindowsUpdates.reg" >> "%LogFile%" 2>&1

echo Disabling Windows Update services
for %%S in (BITS dosvc wuauserv UsoSvc WaaSMedicSvc) do call :CONFIGURE_SERVICE "%%S" "disabled"

echo Deleting SoftwareDistribution
rd /s /q "%SystemRoot%\SoftwareDistribution" >> "%LogFile%" 2>&1

echo Deleting Catroot2
rd /s /q "%SystemRoot%\System32\catroot2" >> "%LogFile%" 2>&1

echo Delete windows update log
del /f /q "%SystemRoot%\WindowsUpdate.log" >> "%LogFile%" 2>&1

echo More details in: %LogFile%
call :GO WINDOWS_UPDATES_MENU

:DISABLE_FEATURE_UPDATES
call :PATH "Security" "DisableFeatureWindowsUpdates"

echo. & echo Disable feature windows update from registry
reg import "%~dp0Files\Security\DisableFeatureWindowsUpdates.reg" >> "%LogFile%" 2>&1

echo More details in: %LogFile%
call :GO WINDOWS_UPDATES_MENU

:RESET_UPDATES
call :PATH "Security" "ResetWindowsUpdates"

echo. & echo Reset Update Registry
reg import "%~dp0Files\Security\ResetWindowsUpdates.reg" >> "%LogFile%" 2>&1

echo Stop update services
sc stop wuauserv >> "%LogFile%" 2>&1
sc stop BITS >> "%LogFile%" 2>&1
sc stop cryptsvc >> "%LogFile%" 2>&1
sc stop dosvc >> "%LogFile%" 2>&1
sc stop UsoSvc >> "%LogFile%" 2>&1
sc stop WaaSMedicSvc >> "%LogFile%" 2>&1

echo Deleting SoftwareDistribution
rd /s /q "%SystemRoot%\SoftwareDistribution" >> "%LogFile%" 2>&1

echo Deleting Catroot2
rd /s /q "%SystemRoot%\System32\catroot2" >> "%LogFile%" 2>&1

echo Deleting BITS QMGR
del "%ALLUSERSPROFILE%\Application Data\Microsoft\Network\Downloader\qmgr*.dat" /f /q >> "%LogFile%" 2>&1

echo Delete windows update log
del /f /q "%SystemRoot%\WindowsUpdate.log" >> "%LogFile%" 2>&1

echo Resetting service security descriptors
sc sdset bits D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU) >> "%LogFile%" 2>&1
sc sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU) >> "%LogFile%" 2>&1

echo Reregistering system DLL
for %%d in ("atl.dll urlmon.dll mshtml.dll shdocvw.dll browseui.dll jscript.dll vbscript.dll scrrun.dll msxml.dll msxml3.dll msxml6.dll actxprxy.dll softpub.dll wintrust.dll dssenh.dll rsaenh.dll gpkcsp.dll sccbase.dll slbcsp.dll cryptdlg.dll oleaut32.dll ole32.dll shell32.dll initpki.dll wuapi.dll wuaueng.dll wuaueng1.dll wucltui.dll wups.dll wups2.dll wuweb.dll qmgr.dll qmgrprxy.dll wucltux.dll muweb.dll wuwebv.dll") do (
    regsvr32 /s "%%d" >> "%LogFile%" 2>&1
)

echo Applying default security settings
secedit /configure /cfg %SystemRoot%\inf\defltbase.inf /db defltbase.sdb /verbose >> "%LogFile%" 2>&1

echo Cleaning BITS jobs
bitsadmin /reset /allusers >> "%LogFile%" 2>&1

echo Enabling windows update services
for %%S in (BITS dosvc CryptSvc wuauserv UsoSvc WaaSMedicSvc) do call :CONFIGURE_SERVICE "%%S" "demand"

echo Releasing IP addresses
ipconfig /release >> "%LogFile%" 2>&1

echo Renewing IP addresses
ipconfig /renew >> "%LogFile%" 2>&1

echo Flushing DNS
ipconfig /flushdns >> "%LogFile%" 2>&1

echo Registering DNS name
ipconfig /registerdns >> "%LogFile%" 2>&1

echo Reset Winsock
netsh winsock reset >> "%LogFile%" 2>&1

echo Reset WinHTTP proxy
netsh winhttp reset proxy >> "%LogFile%" 2>&1

echo Reset TCP/IP Stack
netsh int ip reset >> "%LogFile%" 2>&1

echo Updating policies
gpupdate /force >> "%LogFile%" 2>&1

echo More details in: %LogFile%
call :GO WINDOWS_UPDATES_MENU

:ENABLE_UPDATES
call :PATH "Security" "DefaultWindowsUpdates"

echo. & echo Default windows update registry key
reg import "%~dp0Files\Security\DefaultWindowsUpdates.reg" >> "%LogFile%" 2>&1

echo Enabling windows update services
for %%S in (BITS dosvc wuauserv UsoSvc WaaSMedicSvc cryptsvc msiserver) do call :CONFIGURE_SERVICE "%%S" "demand"

echo Update group policy
gpupdate /force >> "%LogFile%" 2>&1

echo More details in: %LogFile%
call :GO WINDOWS_UPDATES_MENU

:DISABLE_DEFENDER
echo. & echo WARNING: This will disable WINDOWS DEFENDER!
choice /C YN /N /M "Continue anyway? (Y/N): "
if errorlevel 2 goto PRIVACY_SECURITY_MENU

call :PATH "Security" "DisableWindowsDefender"

echo Disable windows defender via registry
reg import "%~dp0Files\Security\DisableWindowsDefender.reg" >> "%LogFile%" 2>&1

echo Disable windows defender services
for %%S in (WinDefend WdNisSvc wscsvc SecurityHealthService Sense SgrmAgent SgrmBroker webthreatdefsvc webthreatdefusersvc) do sc query "%%S" >nul 2>&1 && (
    sc config "%%S" start= disabled >nul 2>&1 && (echo [SUCCESS - SC] %%S >>"%LogFile%" 2>&1) || (
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\%%S" /v Start /t REG_DWORD /d 4 /f >nul 2>&1 && (echo [SUCCESS - REG] %%S >>"%LogFile%" 2>&1) || (echo [FAILED] %%S >>"%LogFile%" 2>&1)
    )
) || (echo [NOT FOUND] %%S >>"%LogFile%" 2>&1)

echo More details in: %LogFile%
call :GO PRIVACY_SECURITY_MENU

:ENABLE_DEFENDER
call :PATH "Security" "DefaultWindowsDefender"

echo. & echo Default windows defender registry key
reg import "%~dp0Files\Security\DefaultWindowsDefender.reg" >> "%LogFile%" 2>&1

echo Enable windows defender services
for %%S in (WinDefend WdNisSvc wscsvc SecurityHealthService Sense SgrmAgent SgrmBroker webthreatdefsvc webthreatdefusersvc) do sc query "%%S" >nul 2>&1 && (
    sc config "%%S" start= auto >nul 2>&1 && (echo [SUCCESS - SC] %%S >>"%LogFile%" 2>&1) || (
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\%%S" /v Start /t REG_DWORD /d 2 /f >nul 2>&1 && (echo [SUCCESS - REG] %%S >>"%LogFile%" 2>&1) || (echo [FAILED] %%S >>"%LogFile%" 2>&1)
    )
) || (echo [NOT FOUND] %%S >>"%LogFile%" 2>&1)

echo Enable tamper protection
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Set-MpPreference -DisableTamperProtection 0 -ErrorAction Stop" >> "%LogFile%" 2>&1

echo Updating policies
gpupdate /force >> "%LogFile%" 2>&1

echo More details in: %LogFile%
call :GO PRIVACY_SECURITY_MENU

:ENHANCE_SECURITY
call :PATH "Security" "EnhanceSecurity"

echo. & echo Enhance security via registry
reg import "%~dp0Files\Security\EnhanceSecurity.reg" >> "%LogFile%" 2>&1

echo Disabling unsafe windows features
for %%f in ("MicrosoftWindowsPowerShellV2" "MicrosoftWindowsPowerShellV2Root" "SMB1Protocol" "SmbDirect" "TFTP" "TelnetClient" "WCF-TCP-PortSharing45") do (
    dism /Online /Get-FeatureInfo /FeatureName:%%f | findstr /C:"State : Enabled" >nul
    if not errorlevel 1 (
        echo  - Disable %%f
        dism /Online /Disable-Feature /FeatureName:%%f /NoRestart >> "%LogFile%" 2>&1
    )
)

echo Disabling unsafe windows services
for %%S in (mrxsmb10 RemoteRegistry SNMP SNMPTRAP) do call :CONFIGURE_SERVICE "%%S" "disabled"

echo Removing default user account
net user defaultuser0 /delete >> "%LogFile%" 2>&1

echo More details in: %LogFile%
call :GO PRIVACY_SECURITY_MENU

:REV_ENHANCE_SECURITY
call :PATH "Security" "RevEnhanceSecurity"

echo. & echo Default windows security registry key
reg import "%~dp0Files\Security\RevEnhanceSecurity.reg" >> "%LogFile%" 2>&1

echo More details in: %LogFile%
call :GO PRIVACY_SECURITY_MENU

:SECURITY_INFO
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Files\Security\SecurityInfo.ps1"
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
    set Routine=NETWORK_TWEAKS
    set Rev_Routine=REV_NETWORK_TWEAKS
    set Apply=Improve Network settings
	set Revert=Default Network settings
    set Menu=NETWORK_MENU
    goto SUB_MENU
)
if "%choice%"=="2" goto DNS_MENU
if "%choice%"=="4" goto NETWORK_RESET
if "%choice%"=="3" goto WIFI_PASSWORDS
if "%choice%"=="5" goto NETWORK_INFO
if "%choice%"=="0" goto MAIN_MENU

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-5)
pause & goto NETWORK_MENU

:NETWORK_TWEAKS
call :PATH "Network" "NetworkTweaks"

echo. & echo Improve network settings via registry
reg import "%~dp0Files\Network\NetworkTweaks.reg" >> "%LogFile%" 2>&1

echo Applying TCP settings optimizations
netsh int tcp set global autotuninglevel=normal >> "%LogFile%" 2>&1
netsh int tcp set global fastopen=enabled >> "%LogFile%" 2>&1
netsh int tcp set global fastopenfallback=enabled >> "%LogFile%" 2>&1
netsh int tcp set global rss=enabled >> "%LogFile%" 2>&1

echo Set Cloudflare DNS on all connected interfaces
for /f "tokens=3,*" %%a in ('netsh interface show interface ^| findstr "Connected"') do (
    echo  - Set Cloudflare DNS on: %%b
    netsh interface ipv4 set dns name="%%b" static 1.1.1.1 primary >> "%LogFile%" 2>&1
    netsh interface ipv4 add dns name="%%b" 1.0.0.1 index=2 >> "%LogFile%" 2>&1
	
    netsh interface ipv6 set dns name="%%b" static 2606:4700:4700::1111 primary >> "%LogFile%" 2>&1
    netsh interface ipv6 add dns name="%%b" 2606:4700:4700::1001 index=2 >> "%LogFile%" 2>&1
)

echo Flushing DNS cache
ipconfig /flushdns >> "%LogFile%" 2>&1

echo More details in: %LogFile%
call :GO NETWORK_MENU

:REV_NETWORK_TWEAKS
call :PATH "Network" "DefaultNetworkSettings"

echo. & echo Set default registry network settings
reg import "%~dp0Files\Network\Rev_Improve_Net.reg" >> "%LogFile%" 2>&1

echo Reset TCP settings to default
netsh int tcp set global autotuninglevel=normal >> "%LogFile%" 2>&1
netsh int tcp set global fastopen=default >> "%LogFile%" 2>&1
netsh int tcp set global fastopenfallback=default >> "%LogFile%" 2>&1
netsh int tcp set global rss=default >> "%LogFile%" 2>&1

call :DHCP
echo More details in: %LogFile%
call :GO NETWORK_MENU

:NETWORK_RESET
cls
call :PATH "Network" "NetworkReset"

echo Releasing IP addresses
ipconfig /release >> "%LogFile%" 2>&1

echo Renewing IP addresses
ipconfig /renew >> "%LogFile%" 2>&1

echo Registering DNS name
ipconfig /registerdns >> "%LogFile%" 2>&1

echo Flushing DNS
ipconfig /flushdns >> "%LogFile%" 2>&1

echo Reset Winsock
netsh winsock reset >> "%LogFile%" 2>&1

echo Reset WinHTTP proxy
netsh winhttp reset proxy >> "%LogFile%" 2>&1

echo Reset TCP/IP Stack
netsh int ip reset >> "%LogFile%" 2>&1

echo Reset TCP/UDP
netsh int tcp reset >> "%LogFile%" 2>&1
netsh int udp reset >> "%LogFile%" 2>&1

echo Reset IPv6 settings
netsh interface ipv6 reset >> "%LogFile%" 2>&1

echo Cleaning IPv6 Neighbor
netsh interface ipv6 delete neighbors >> "%LogFile%" 2>&1

echo Reset Firewall Rules
netsh advfirewall reset >> "%LogFile%" 2>&1

echo Refreshing NetBIOS names
nbtstat -RR >> "%LogFile%" 2>&1

echo Cleaning ARP cache
arp -d * >> "%LogFile%" 2>&1

echo Restart all connected interfaces
for /f "tokens=3,*" %%a in ('netsh interface show interface ^| findstr "Connected"') do (
    echo - Restart: %%b
    netsh interface set interface name="%%b" admin=disabled >> "%LogFile%" 2>&1
    timeout /t 2 >nul
    netsh interface set interface name="%%b" admin=enabled >> "%LogFile%" 2>&1
)

echo More details in: %LogFile%
call :GO NETWORK_MENU

:WIFI_PASSWORDS
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Files\Network\WifiPassword.ps1"
echo. & choice /C YN /N /M "Export the results as a text file? (Y/N): "
if errorlevel 1 (
    set "WIFI_PASSWORD=%USERPROFILE%\Documents\WifiPassword.txt"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Files\Network\WifiPassword.ps1" >> "%WIFI_PASSWORD%" 2>&1
    echo Wifi Report file was saved in: %WIFI_PASSWORD%
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
if "%choice%"=="1" (
    set DNS_NAME=Google Public DNS
    set DNS_IPv4_1=8.8.8.8
    set DNS_IPv4_2=8.8.4.4
    set DNS_IPv6_1=2001:4860:4860::8888
    set DNS_IPv6_2=2001:4860:4860::8844
    goto SET_DNS
)
if "%choice%"=="2" (
    set DNS_NAME=Cloudflare DNS
    set DNS_IPv4_1=1.1.1.1
    set DNS_IPv4_2=1.0.0.1
    set DNS_IPv6_1=2606:4700:4700::1111
    set DNS_IPv6_2=2606:4700:4700::1001
    goto SET_DNS
)
if "%choice%"=="3" (
    set DNS_NAME=Cloudflare Family DNS
    set DNS_IPv4_1=1.1.1.3
    set DNS_IPv4_2=1.0.0.3
    set DNS_IPv6_1=2606:4700:4700::1113
    set DNS_IPv6_2=2606:4700:4700::1003
    goto SET_DNS
)
if "%choice%"=="4" (
    set DNS_NAME=AdGuard DNS
    set DNS_IPv4_1=94.140.14.15
    set DNS_IPv4_2=94.140.15.16
    set DNS_IPv6_1=2a10:50c0::bad:ff
    set DNS_IPv6_2=2a10:50c0::b0d:ff
    goto SET_DNS
)
if "%choice%"=="5" (
    set DNS_NAME=Clean Browsing DNS
    set DNS_IPv4_1=185.228.168.168
    set DNS_IPv4_2=185.228.169.168
    set DNS_IPv6_1=2a0d:2a00:1::
    set DNS_IPv6_2=2a0d:2a00:2::
    goto SET_DNS
)
if "%choice%"=="6" (
    set DNS_NAME=Quad9 DNS
    set DNS_IPv4_1=9.9.9.9
    set DNS_IPv4_2=149.112.112.112
    set DNS_IPv6_1=2620:fe::fe
    set DNS_IPv6_2=2620:fe::9
    goto SET_DNS
)
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
pause & goto DNS_MENU

:SET_DNS
call :PATH "Network" "DNS"

cls & echo Set %DNS_NAME% server on all connected interfaces
for /f "tokens=3,*" %%a in ('netsh interface show interface ^| findstr "Connected"') do (
    echo  - Configure: %%b
    netsh interface ipv4 set dns name="%%b" static %DNS_IPv4_1% primary >> "%LogFile%" 2>&1
    netsh interface ipv4 add dns name="%%b" %DNS_IPv4_2% index=2 >> "%LogFile%" 2>&1
    
    netsh interface ipv6 set dns name="%%b" static %DNS_IPv6_1% primary >> "%LogFile%" 2>&1
    netsh interface ipv6 add dns name="%%b" %DNS_IPv6_2% index=2 >> "%LogFile%" 2>&1
)

echo Flushing DNS cache
ipconfig /flushdns >> "%LogFile%" 2>&1

echo More details in: %LogFile%
call :GO DNS_MENU

:SET_DHCP
cls & call :DHCP
call :PATH "Network" "DHCP"

echo More details in: %LogFile%
call :GO DNS_MENU

:DNS_SERVER_TEST
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Files\Network\DNSTest.ps1"
call :GO DNS_MENU

:DNS_STATUS
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Files\Network\DNSStatus.ps1"
call :GO DNS_MENU

:NETWORK_INFO
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Files\Network\NetworkInfo.ps1"
call :GO NETWORK_MENU


:PROGRAMS_MANAGER
cls & echo. & echo.
echo                        ------------------------------ Programs manager ---------------------------
echo.
echo                         [1] Download Programs                                 [2] Update Programs
echo.
echo                         [3] Programs Info                                     [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto WHERE_CHOCO
if "%choice%"=="2" goto UPDATE_PROGRAMS
if "%choice%"=="3" goto PROGRAMS_INFO
if "%choice%"=="0" goto MAIN_MENU

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-3)
pause & goto PROGRAMS_MANAGER

:WHERE_CHOCO
where choco >nul 2>&1
if %errorlevel%==0 goto PROGRAMS_MENU_VAR

cls & echo Install Chocolatey package manager
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Files\Programs\InstallChoco.ps1"

where choco >nul 2>&1
if %errorlevel% neq 0 (
    echo Choco not found
    echo Install it manually from: https://chocolatey.org/install
	pause & goto PROGRAMS_MANAGER
)

:PROGRAMS_MENU_VAR
set "ON=(YES)"
set "OFF=(NO)"
for %%A in (1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18) do set "opt%%A=%OFF%"

:PROGRAMS_MENU
cls & echo. & echo.
echo                        -------------------------------- Programs ---------------------------------
echo.
echo                           [1] Google Chrome           [7] XnViewMP              [13] All VC++
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

echo. & echo Selected Programs:
call :SHOW_SELECTED

echo. & set "choice=" & set /p "choice=--> Select an option and press [S] to Start: "
if "%choice%"=="" goto PROGRAMS_MENU
if /i "%choice%"=="S" goto INSTALL_PROGRAMS
if /i "%choice%"=="0" goto PROGRAMS_MANAGER
if /i "%choice%"=="A" goto SELECT_ALL
if /i "%choice%"=="D" goto DESELECT_ALL

set "tokens=%choice:,= %"
for %%G in (%tokens%) do (
    for %%N in (1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18) do (
        if "%%G"=="%%N" call :TOGGLE_SINGLE opt%%N
    )
)
goto PROGRAMS_MENU

:SELECT_ALL
for /L %%i in (1,1,18) do (
    set "opt%%i=%ON%"
)
goto PROGRAMS_MENU

:DESELECT_ALL
for /L %%i in (1,1,18) do (
    set "opt%%i=%OFF%"
)
goto PROGRAMS_MENU

:INSTALL_PROGRAMS
cls
call :IS_ON opt1 && (
    echo Installing Google Chrome
    choco install googlechrome -y
)
call :IS_ON opt2 && (
    echo Installing Brave
    choco install brave -y 
)
call :IS_ON opt3 && (
    echo Installing WinRAR
    choco install winrar -y 
)
call :IS_ON opt4 && (
    echo Installing 7-Zip
    choco install 7zip -y  
)
call :IS_ON opt5 && (
    echo Installing K-Lite Codec Pack
    choco install k-litecodecpackmega -y
)
call :IS_ON opt6 && (
    echo Installing IrfanView
    choco install irfanview -y
)
call :IS_ON opt7 && (
    echo Installing XnView MP
    choco install xnviewmp -y
)
call :IS_ON opt8 && (
    echo Installing Sumatra PDF
    choco install sumatrapdf -y
)
call :IS_ON opt9 && (
    echo Installing Notepad++
    choco install notepad++ -y
)
call :IS_ON opt10 && (
    echo Installing Visual Studio Code
    choco install vscode -y
)
call :IS_ON opt11 && (
    echo Installing Git
    choco install git -y
)
call :IS_ON opt12 && (
    echo Installing qbittorrent
    choco install qbittorrent -y
)
call :IS_ON opt13 && (
    echo Installing VC++ Redistributables
    choco install vcredist-all -y
)
call :IS_ON opt14 && (
    echo Installing DirectX
    choco install directx -y
)
call :IS_ON opt15 && (
    echo Installing Virtual Box
    choco install virtualbox -y
)
call :IS_ON opt16 && (
    echo Installing IObit Unlocker
    choco install iobit-unlocker -y
)
call :IS_ON opt17 && (
    echo Installing AutoHotkey
    choco install autohotkey -y
)
call :IS_ON opt18 && (
    echo Installing MEGA
    choco install mega -y
)

call :GO PROGRAMS_MANAGER

:IS_ON
if "!%1!"=="%ON%" exit /b 0
exit /b 1

:TOGGLE_SINGLE
if "!%1!"=="%ON%" (
    set "%1=%OFF%"
) else (
    set "%1=%ON%"
)
goto :eof

:SHOW_SELECTED
set "ANY=0"
if "!opt1!"=="%ON%" (echo  - Google Chrome & set "ANY=1")
if "!opt2!"=="%ON%" (echo  - Brave & set "ANY=1")
if "!opt3!"=="%ON%" (echo  - WinRAR & set "ANY=1")
if "!opt4!"=="%ON%" (echo  - 7-Zip & set "ANY=1")
if "!opt5!"=="%ON%" (echo  - K-Lite Codec Pack & set "ANY=1")
if "!opt6!"=="%ON%" (echo  - IrfanView & set "ANY=1")
if "!opt7!"=="%ON%" (echo  - XnView MP & set "ANY=1")
if "!opt8!"=="%ON%" (echo  - Sumatra PDF & set "ANY=1")
if "!opt9!"=="%ON%" (echo  - Notepad++ & set "ANY=1")
if "!opt10!"=="%ON%" (echo  - Visual Studio Code & set "ANY=1")
if "!opt11!"=="%ON%" (echo  - Git & set "ANY=1")
if "!opt12!"=="%ON%" (echo  - qbittorrent & set "ANY=1")
if "!opt13!"=="%ON%" (echo  - VC++ Redistributables & set "ANY=1")
if "!opt14!"=="%ON%" (echo  - DirectX & set "ANY=1")
if "!opt15!"=="%ON%" (echo  - Virtual Box & set "ANY=1")
if "!opt16!"=="%ON%" (echo  - IObit Unlocker & set "ANY=1")
if "!opt17!"=="%ON%" (echo  - AutoHotkey & set "ANY=1")
if "!opt18!"=="%ON%" (echo  - MEGA & set "ANY=1")
if "!ANY!"=="0" echo   No programs selected
goto :eof

:UPDATE_PROGRAMS
cls & echo Update all installed programs via chocolatey
where choco >nul 2>&1 || (
    echo Choco not found
	pause & goto PROGRAMS_MANAGER
)
choco upgrade all -y
call :GO PROGRAMS_MANAGER

:PROGRAMS_INFO
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Files\Programs\ProgramsInfo.ps1"
call :GO PROGRAMS_MANAGER

:CUSTOMIZATION_MENU
cls & echo. & echo.
echo                        ------------------------------ Customization ------------------------------
echo.
echo                           [1] File Explorer                                     [2] Dark Mode
echo.
echo                           [3] Power Setting                                     [4] Shortcut Arrow
echo.
echo                           [5] Classic Photo Viewer                              [6] Trash Options 
echo.
echo                           [7] Num Lock                                          [8] Notification
echo.
echo                           [9] Context Menu                                      [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p "choice=Select an option: "
if "%choice%"=="1" goto FILE_EXPLORER_MENU
if "%choice%"=="2" (
    set Routine=DARK_MODE
    set Rev_Routine=LIGHT_MODE
    set Apply=Activate dark mode
	set Revert=Activate light mode
    set Menu=CUSTOMIZATION_MENU
    goto SUB_MENU
)
if "%choice%"=="3" (
    set Routine=POWER_SETTINGS
    set Rev_Routine=REV_POWER_SETTINGS
    set Apply=Activate power settings
	set Revert=Deleting power settings
    set Menu=CUSTOMIZATION_MENU
    goto SUB_MENU
)
if "%choice%"=="4" (
    set Routine=SHORTCUT_ARROW
    set Rev_Routine=REV_SHORTCUT_ARROW
    set Apply=Remove arrow from shortcut
	set Revert=Default arrow shortcut
    set Menu=CUSTOMIZATION_MENU
    goto SUB_MENU
)
if "%choice%"=="5" (
    set Routine=PHOTO_VIEWER
    set Rev_Routine=REV_PHOTO_VIEWER
    set Apply=Restore classic windows photo viewer
	set Revert=Remove classic windows photo viewer
    set Menu=CUSTOMIZATION_MENU
    goto SUB_MENU
)
if "%choice%"=="6" (
    set Routine=TRASH_OPTIONS
    set Rev_Routine=REV_TRASH_OPTIONS
    set Apply=Disable unnecessary windows features
	set Revert=Default unnecessary windows features
    set Menu=CUSTOMIZATION_MENU
    goto SUB_MENU
)
if "%choice%"=="7" (
    set Routine=NUM_LOCK
    set Rev_Routine=REV_NUM_LOCK
    set Apply=Disable num lock when logging in
	set Revert=Enable num lock when logging in
    set Menu=CUSTOMIZATION_MENU
    goto SUB_MENU
)
if "%choice%"=="8" (
    set Routine=NOTIFICATION
    set Rev_Routine=REV_NOTIFICATION
    set Apply=Disable notification center
	set Revert=Enable notification center
    set Menu=CUSTOMIZATION_MENU
    goto SUB_MENU
)
if "%choice%"=="9" goto CONTEXT_MENU
if "%choice%"=="0" goto MAIN_MENU

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-9)
pause & goto CUSTOMIZATION_MENU

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
    set Routine=SHOW_EXTENSIONS
    set Rev_Routine=REV_SHOW_EXTENSIONS
    set Apply=Show files extensions
	set Revert=Disable display files extensions
    set Menu=FILE_EXPLORER_MENU
    goto SUB_MENU
)
if "%choice%"=="2" (
    set Routine=SHOW_HIDDEN
    set Rev_Routine=REV_SHOW_HIDDEN
    set Apply=Show hidden files
	set Revert=Disable display hidden files
    set Menu=FILE_EXPLORER_MENU
    goto SUB_MENU
)
if "%choice%"=="3" (
    set Routine=SHOW_RECENT
    set Rev_Routine=REV_SHOW_RECENT
    set Apply=Show recent files
	set Revert=Disable display recent files
    set Menu=FILE_EXPLORER_MENU
    goto SUB_MENU
)
if "%choice%"=="4" (
    set Routine=THIS_PC_OPEN
    set Rev_Routine=REV_THIS_PC_OPEN
    set Apply=Open file explorer on this PC
	set Revert=Open file explorer on Quick Access
    set Menu=FILE_EXPLORER_MENU
    goto SUB_MENU
)
if "%choice%"=="0" goto CUSTOMIZATION_MENU

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-4)
pause & goto FILE_EXPLORER_MENU

:SHOW_EXTENSIONS
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f >nul 2>&1
call :GO FILE_EXPLORER_MENU

:REV_SHOW_EXTENSIONS
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 1 /f >nul 2>&1
call :GO FILE_EXPLORER_MENU

:SHOW_HIDDEN
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSuperHidden /t REG_DWORD /d 1 /f >nul 2>&1
call :GO FILE_EXPLORER_MENU

:REV_SHOW_HIDDEN
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSuperHidden /t REG_DWORD /d 0 /f >nul 2>&1
call :GO FILE_EXPLORER_MENU

:SHOW_RECENT
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowRecent /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackDocs /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v NoRecentDocsHistory /t REG_DWORD /d 0 /f >nul 2>&1
call :GO FILE_EXPLORER_MENU

:REV_SHOW_RECENT
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowRecent /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackDocs /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v NoRecentDocsHistory /t REG_DWORD /d 1 /f >nul 2>&1
call :GO FILE_EXPLORER_MENU

:THIS_PC_OPEN
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 1 /f >nul 2>&1
call :GO FILE_EXPLORER_MENU

:REV_THIS_PC_OPEN
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 2 /f >nul 2>&1
call :GO FILE_EXPLORER_MENU

:DARK_MODE
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:LIGHT_MODE
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:POWER_SETTINGS
mkdir "%USERPROFILE%\Desktop\Powerful Settings.{ED7BA470-8E54-465E-825C-99712043E01C}" >nul 2>&1
call :GO CUSTOMIZATION_MENU

:REV_POWER_SETTINGS
rd /s /q "%USERPROFILE%\Desktop\Powerful Settings.{ED7BA470-8E54-465E-825C-99712043E01C}" >nul 2>&1
call :GO CUSTOMIZATION_MENU

:SHORTCUT_ARROW
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons" /v 29 /d "C:\Windows\System32\imageres.dll,197" /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v link /t REG_BINARY /d 00000000 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:REV_SHORTCUT_ARROW
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons" /v 29 /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v link /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:PHOTO_VIEWER
reg import "%~dp0Files\Customization\RestoreOldWindowsPhotoViewer.reg" >nul 2>&1
call :GO CUSTOMIZATION_MENU

:REV_PHOTO_VIEWER
reg import "%~dp0Files\Customization\RemovingOldWindowsPhotoViewer.reg" >nul 2>&1
call :GO CUSTOMIZATION_MENU

:TRASH_OPTIONS
reg import "%~dp0Files\Customization\DisableTrash.reg" >nul 2>&1
call :GO CUSTOMIZATION_MENU

:REV_TRASH_OPTIONS
reg import "%~dp0Files\Customization\DefaultTrash.reg" >nul 2>&1
call :GO CUSTOMIZATION_MENU

:NUM_LOCK
reg add "HKCU\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 0 /f >nul 2>&1
reg add "HKU\.DEFAULT\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 0 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:REV_NUM_LOCK
reg add "HKCU\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 2 /f >nul 2>&1
reg add "HKU\.DEFAULT\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_SZ /d 2 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:NOTIFICATION
reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v DisableNotificationCenter /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 0 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:REV_NOTIFICATION
reg delete "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v DisableNotificationCenter /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 1 /f >nul 2>&1
call :GO CUSTOMIZATION_MENU

:CONTEXT_MENU
cls & echo. & echo.
echo                        ------------------------------- Context Menu ------------------------------
echo.
echo                          [1] Command Prompt                                  [2] Restart Explorer
echo. 
echo                          [3] Killing Frozen                                  [0] Back
echo.    
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" (
    set Routine=CMD_CONTEXT
    set Rev_Routine=REV_CMD_CONTEXT
    set Apply=Add "Open Command Prompt Here (Admin)" options to context menu
	set Revert=Remove options
    set Menu=CONTEXT_MENU
    goto SUB_MENU
)
if "%choice%"=="2" (
    set Routine=EXPLORER_RESTART_CONTEXT
    set Rev_Routine=REV_EXPLORER_RESTART_CONTEXT
    set Apply=Add "Restart Explorer" option to context menu
	set Revert=Remove option
    set Menu=CONTEXT_MENU
    goto SUB_MENU
)
if "%choice%"=="3" (
    set Routine=KILL_FROZEN_CONTEXT
    set Rev_Routine=REV_KILL_FROZEN_CONTEXT
    set Apply=Add "Kill frozen process" option context menu
	set Revert=Remove option
    set Menu=CONTEXT_MENU
    goto SUB_MENU
)
if "%choice%"=="0" goto CUSTOMIZATION_MENU

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-3)
pause & goto CONTEXT_MENU

:CMD_CONTEXT
reg add "HKCR\Directory\shell\OpenCmdHere" /ve /d "Open Command Prompt Here (Admin)" /f >nul 2>&1
reg add "HKCR\Directory\shell\OpenCmdHere" /v "HasLUAShield" /t REG_SZ /d "" /f >nul 2>&1
reg add "HKCR\Directory\shell\OpenCmdHere" /v "Icon" /d "cmd.exe" /f >nul 2>&1
reg add "HKCR\Directory\shell\OpenCmdHere\command" /ve /d "powershell -Command \"Start-Process cmd -ArgumentList '/s','/k','pushd %%V' -Verb RunAs\"" /f >nul 2>&1

reg add "HKCR\Directory\Background\shell\OpenCmdHere" /ve /d "Open Command Prompt Here (Admin)" /f >nul 2>&1
reg add "HKCR\Directory\Background\shell\OpenCmdHere" /v "HasLUAShield" /t REG_SZ /d "" /f >nul 2>&1
reg add "HKCR\Directory\Background\shell\OpenCmdHere" /v "Icon" /d "cmd.exe" /f >nul 2>&1
reg add "HKCR\Directory\Background\shell\OpenCmdHere\command" /ve /d "powershell -Command \"Start-Process cmd -ArgumentList '/s','/k','pushd %%V' -Verb RunAs\"" /f >nul 2>&1
call :GO CONTEXT_MENU

:REV_CMD_CONTEXT
reg delete "HKCR\Directory\shell\OpenCmdHere" /f >nul 2>&1
reg delete "HKCR\Directory\Background\shell\OpenCmdHere" /f >nul 2>&1
call :GO CONTEXT_MENU

:EXPLORER_RESTART_CONTEXT
reg add "HKCU\Software\Classes\DesktopBackground\Shell\RestartExplorer" /ve /d "Restart Explorer" /f >nul 2>&1
reg add "HKCU\Software\Classes\DesktopBackground\Shell\RestartExplorer" /v "Icon" /d "explorer.exe,0" /f >nul 2>&1
reg add "HKCU\Software\Classes\DesktopBackground\Shell\RestartExplorer\command" /ve /d "cmd.exe /c taskkill /f /im explorer.exe && start explorer.exe" /f >nul 2>&1
call :GO CONTEXT_MENU

:REV_EXPLORER_RESTART_CONTEXT
reg delete "HKCU\Software\Classes\DesktopBackground\Shell\RestartExplorer" /f >nul 2>&1
call :GO CONTEXT_MENU

:KILL_FROZEN_CONTEXT
reg add "HKCU\Software\Classes\DesktopBackground\Shell\KillNotResponding" /v "MUIVerb" /d "Kill frozen process" /f >nul 2>&1
reg add "HKCU\Software\Classes\DesktopBackground\Shell\KillNotResponding" /v "Icon" /d "taskmgr.exe,0" /f >nul 2>&1
reg add "HKCU\Software\Classes\DesktopBackground\Shell\KillNotResponding\Command" /ve /d "cmd.exe /C taskkill.exe /F /FI \"status eq NOT RESPONDING\"" /f >nul 2>&1
call :GO CONTEXT_MENU

:REV_KILL_FROZEN_CONTEXT
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
if "%choice%"=="2" goto REGISTRY_BACKUP
if "%choice%"=="3" goto ACTIVATION_MENU
if "%choice%"=="4" goto SYSTEM_INFO
if "%choice%"=="0" goto MAIN_MENU

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-4)
pause & goto SYSTEM_MENU

:RESTORE_POINT
cls
call :PATH "System" "RestorePoint"

echo Enabling System Restore from registry
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore" /v DisableSR /t REG_DWORD /d 0 /f >>"%LogFile%" 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore" /v DisableConfig /t REG_DWORD /d 0 /f >>"%LogFile%" 2>&1

echo Updating policies
gpupdate /force >>"%LogFile%" 2>&1

echo Starting Restore Point services
for %%S in (VSS swprv Schedule srservice) do call :CONFIGURE_SERVICE "%%S" "demand"

echo Creating System Restore Point
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Files\System\CreatRestorePoint.ps1" >>"%LogFile%" 2>&1

echo More details in: %LogFile%
call :GO SYSTEM_MENU


:REGISTRY_BACKUP
cls & echo. & echo.
echo                        ------------------------------ Registry Backup ----------------------------
echo.
echo                           [1] full Backup                                    [2] Important Backup
echo. 
echo                                                          [0]Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto FULL_BACKUP 
if "%choice%"=="2" goto IMPORTANT_BACKUP
if "%choice%"=="0" goto SYSTEM_MENU 

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-2)
pause & goto REGISTRY_BACKUP

:FULL_BACKUP
cls & echo Creating Full Registry Backup
call :PATH "System" "FullRegistryBackup"
call :TIME_STAMP "System" "FullRegistryBackup"

reg save HKLM\SYSTEM "%BACKUP_DIR%\SYSTEM.hive" /y >>"%LogFile%" 2>&1
reg save HKLM\SOFTWARE "%BACKUP_DIR%\SOFTWARE.hive" /y >>"%LogFile%" 2>&1
reg save HKLM\SAM "%BACKUP_DIR%\SAM.hive" /y >>"%LogFile%" 2>&1
reg save HKLM\SECURITY "%BACKUP_DIR%\SECURITY.hive" /y >>"%LogFile%" 2>&1
reg save HKU\.DEFAULT "%BACKUP_DIR%\DEFAULT.hive" /y >>"%LogFile%" 2>&1
reg save HKCU\Software\Classes "%BACKUP_DIR%\UsrClass.hive" /y >>"%LogFile%" 2>&1

if exist "%BACKUP_DIR%\*.hive" (
    choice /C YN /N /M "Compress files? (Y/N): "
    if errorlevel 2 (
        echo Backup files saved in: %BACKUP_DIR%
    ) else if errorlevel 1 (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Files\System\CompressHiveFiles.ps1" "%BACKUP_DIR%"
    )
) else (
    echo No hive files found
)

echo More details in: %LogFile%
call :GO REGISTRY_BACKUP

:IMPORTANT_BACKUP
cls & echo Creating Important Registry Backup
call :PATH "System" "ImportantRegistryBackup"
call :TIME_STAMP "System" "ImportantRegistryBackup"

reg export "HKLM\SYSTEM" "%BACKUP_DIR%\HKLM_SYSTEM.reg" /y  >>"%LogFile%" 2>&1
reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "%BACKUP_DIR%\HKLM_SystemProfile.reg" /y  >>"%LogFile%" 2>&1
reg export "HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" "%BACKUP_DIR%\HKLM_WOW6432_Run.reg" /y  >>"%LogFile%" 2>&1
reg export "HKLM\SOFTWARE\Microsoft\WindowsUpdate" "%BACKUP_DIR%\HKLM_WindowsUpdate.reg" /y  >>"%LogFile%" 2>&1
reg export "HKLM\SOFTWARE\Policies" "%BACKUP_DIR%\HKLM_Policies.reg" /y  >>"%LogFile%" 2>&1
reg export "HKLM\SOFTWARE\Microsoft\Windows Defender" "%BACKUP_DIR%\HKLM_WindowsDefender.reg" /y  >>"%LogFile%" 2>&1
reg export "HKLM\SOFTWARE\Microsoft\Security Center" "%BACKUP_DIR%\HKLM_SecurityCenter.reg" /y  >>"%LogFile%" 2>&1
reg export "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion" "%BACKUP_DIR%\HKLM_CurrentVersion.reg" /y  >>"%LogFile%" 2>&1
reg export "HKLM\SOFTWARE\Microsoft\.NETFramework" "%BACKUP_DIR%\HKLM_NETFramework.reg" /y  >>"%LogFile%" 2>&1
reg export "HKLM\SOFTWARE\WOW6432Node\Microsoft\.NETFramework" "%BACKUP_DIR%\HKLM_WOW6432_NETFramework.reg" /y  >>"%LogFile%" 2>&1
reg export "HKLM\SOFTWARE\Microsoft\PolicyManager" "%BACKUP_DIR%\HKLM_PolicyManager.reg" /y  >>"%LogFile%" 2>&1

reg export "HKCU\SOFTWARE\Policies" "%BACKUP_DIR%\HKCU_Policies.reg" /y  >>"%LogFile%" 2>&1
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion" "%BACKUP_DIR%\HKCU_CurrentVersion.reg" /y  >>"%LogFile%" 2>&1
reg export "HKCU\Control Panel" "%BACKUP_DIR%\HKCU_ControlPanel.reg" /y  >>"%LogFile%" 2>&1

echo Backup files saved in: %BACKUP_DIR%
echo More details in: %LogFile%
call :GO REGISTRY_BACKUP

:ACTIVATION_MENU
cls & echo. & echo.
echo                        -------------------------------- Activation -------------------------------
echo.
echo                          [1] Windows And Office                             [2] Activation Status
echo. 
echo                                                          [0]Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto RUN_ACTIVATION
if "%choice%"=="2" goto CHECK_ACTIVATION
if "%choice%"=="0" goto SYSTEM_MENU 

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-2)
pause & goto ACTIVATION_MENU

:RUN_ACTIVATION
cls & echo Activating Windows and Microsoft Office using MAS script
powershell -NoP -EP Bypass -c "irm https://get.activated.win | iex"
call :GO ACTIVATION_MENU

:CHECK_ACTIVATION
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Files\System\ActivateStatus.ps1"
call :GO ACTIVATION_MENU

:SYSTEM_INFO
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Files\System\SystemInfo.ps1"
call :GO SYSTEM_MENU


:TOOLS_MENU
cls & echo. & echo.
echo                        ---------------------------------- Tools ----------------------------------
echo.
echo                          [1] SFC Scan                                          [2] DISM Tools
echo.  
echo                          [3] Defragment Drive                                  [4] Check Disk 
echo. 
echo                          [5] Memory Diagnostic                                 [6] Disk Cleanup
echo.
echo                                                          [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto SFC_SCAN
if "%choice%"=="2" goto DISM_MENU
if "%choice%"=="3" goto DEFRAG
if "%choice%"=="4" goto CHKDSK
if "%choice%"=="5" goto MEMORY_DIAG
if "%choice%"=="6" goto CLEAN_MGR
if "%choice%"=="0" goto MAIN_MENU

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-6)
pause & goto TOOLS_MENU

:SFC_SCAN
cls & echo Running sfc scan
sfc /scannow
call :GO TOOLS_MENU

:DISM_MENU
cls & echo. & echo.
echo                        -------------------------------- DISM Tools -------------------------------
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
pause & goto DISM_MENU

:DISM_CHECK_HEALTH
cls & echo Checking windows component health
dism /Online /Cleanup-Image /CheckHealth
call :GO DISM_MENU

:DISM_SCAN_HEALTH
cls & echo Scanning windows component health
dism /Online /Cleanup-Image /ScanHealth
call :GO DISM_MENU

:DISM_RESTORE_HEALTH
cls & echo Fix Windows component
dism /Online /Cleanup-Image /RestoreHealth
call :GO DISM_MENU

:DISM_COMPONENT_CLEANUP
cls & echo Windows component
dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase
call :GO DISM_MENU

:DEFRAG
start "" dfrgui.exe
goto TOOLS_MENU

:CHKDSK
cls & echo Available drives on your system:
wmic logicaldisk get caption 2>nul | find ":" 
echo. & set /p "drive=Enter drive letter to check: "
set "DRIVE=%DRIVE:"=%"
set "DRIVE=%DRIVE:~0,1%"

if not defined drive goto CHKDSK
for /f %%A in ('echo %DRIVE%') do set "DRIVE=%%~A"

if not exist %DRIVE%:\ (
    echo Invalid drive letter: %DRIVE%
    pause & goto CHKDSK
)

:CHECK_MENU
cls & echo. & echo.
echo                        --------------------------------- CHKDSK ----------------------------------
echo.
echo                          [1] Drive Status                                    [2] Fix Files System
echo.
echo                          [3] Fix Bad Sectors                                 [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto DISK_STATUS 
if "%choice%"=="2" goto FIX_FILE
if "%choice%"=="3" goto FIX_SECTORS
if "%choice%"=="0" goto TOOLS_MENU

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-3)
pause & goto CHECK_MENU

:DISK_STATUS
cls & echo Displays status of drive: %DRIVE%
timeout /t 2 >nul
chkdsk %DRIVE%:
call :GO CHECK_MENU

:FIX_FILE
cls & echo Fix files system errors in drive: %DRIVE%
timeout /t 2 >nul
chkdsk %DRIVE%: /f /x
call :GO CHECK_MENU

:FIX_SECTORS
cls & echo Fix files system and recovering files from bad sectors in drive: %DRIVE%
timeout /t 2 >nul
chkdsk %DRIVE%: /r
call :GO CHECK_MENU

:MEMORY_DIAG
start "" mdsched.exe
goto TOOLS_MENU

:CLEAN_MGR
cleanmgr.exe /d C: /VERYLOWDISK
goto TOOLS_MENU

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
pause & goto OTHER_MENU

:CTT
cls & echo Running chris titus tool
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb https://christitus.com/win | iex"
call :GO OTHER_MENU

:OO_SHUTUP
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Files\Other\OOShutup.ps1"
call :GO OTHER_MENU

:NET_SPEED_TEST
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Files\Other\NetSpeed.ps1"
call :GO OTHER_MENU


:: FUNCTIONS
:SET_TASKS
for /f "tokens=*" %%i in (%~2) do (
    set "TASK_NAME=%%i"
    set "TASK_RESULT=SUCCESS"
    if "%~1"=="Disable" (
        schtasks /change /tn "%%i" /disable >nul 2>&1
    ) else (
        schtasks /change /tn "%%i" /enable >nul 2>&1
    )
    if errorlevel 1 (
        schtasks /query /tn "%%i" >nul 2>&1
        if errorlevel 1 (
            set "TASK_RESULT=NOT_FOUND"
        ) else (
            set "TASK_RESULT=FAILED"
        )
    )
    echo !TASK_RESULT!: !TASK_NAME! >> "%LogFile%" 2>&1
)
goto :eof

:CLEANING_FUNCTION
echo Cleaning Temp
for %%F in (
    "%TEMP%"
    "%AppData%\Temp"
	"%SystemRoot%\Temp"
	"%ALLUSERSPROFILE%\Temp"
    "%USERPROFILE%\AppData\LocalLow\Temp"
) do (
    if exist "%%~F" (
        del /f /q "%%~F\*.*" >nul 2>&1
        for /d %%D in ("%%~F\*") do (
            rd /s /q "%%D" >nul 2>&1
        )
    )
)

echo Cleaning Thumbnail and icons cache
del /f /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache*.db" >nul 2>&1
del /f /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache*.db" >nul 2>&1

echo Cleaning PowerShell command history
del /f /q "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" >nul 2>&1
goto :eof

:FINAL_CLEAN
choice /C YN /N /M "Run Disk Cleanup to complete the cleaning? (Y/N): "
if %errorlevel% == 1 (
    echo Running Disk Cleanup
    cleanmgr.exe /d C: /VERYLOWDISK
)
echo Empty Recycle Bin
powershell -Command "Clear-RecycleBin -Force" >nul 2>&1
goto :eof

:DHCP
echo Set DHCP on all connected interfaces
for /f "tokens=3,*" %%a in ('netsh interface show interface ^| findstr "Connected"') do (
    echo - Resetting DNS on: %%b
	netsh interface ipv4 set address name="%%b" source=dhcp >> "%LogFile%" 2>&1
    netsh interface ipv4 set dnsservers name="%%b" source=dhcp >> "%LogFile%" 2>&1

    netsh interface ipv6 set dnsservers name="%%b" source=dhcp >> "%LogFile%" 2>&1
)

echo Flushing DNS cache
ipconfig /flushdns >> "%LogFile%" 2>&1
goto :eof

:CONFIGURE_SERVICE
sc query "%~1" >nul 2>&1
if %errorlevel% == 0 (
    sc config "%~1" start= %~2 >nul 2>&1
    if %errorlevel% neq 0 (
        echo FAILED %~1 >>"%LogFile%" 2>&1
        goto :eof
    )
    echo [SUCCESS] %~1 >>"%LogFile%" 2>&1
) else (
    echo [NOT FOUND] %~1 >>"%LogFile%" 2>&1
)
goto :eof

:TIME_STAMP
for /f "tokens=2 delims==." %%a in ('wmic os get localdatetime /value') do set datetime=%%a
set "BACKUP_DIR=%ProgramData%\WindowsOptimizationScript\%~1\%~2_%datetime:~0,4%-%datetime:~4,2%-%datetime:~6,2%_%datetime:~8,2%-%datetime:~10,2%-%datetime:~12,2%"

if not exist "%BACKUP_DIR%" (
    mkdir "%BACKUP_DIR%" >nul 2>&1
    if errorlevel 1 (
        echo Failed to create directory: %BACKUP_DIR%
        pause & exit
    )
)
goto :eof

:PATH
set "TARGET_DIR=%ProgramData%\WindowsOptimizationScript\%~1"
if not exist "%TARGET_DIR%" (
    mkdir "%TARGET_DIR%" >nul 2>&1
    if errorlevel 1 (
        echo Failed to create directory: %TARGET_DIR%
        pause & exit
    )
)
set "LogFile=%TARGET_DIR%\%~2.log"
(echo   Start at %time% %date% & echo.) > "%LogFile%" 2>&1
goto :eof

:SUB_MENU
cls & echo. & echo.
echo      [1] %Apply%
echo.
echo      [2] %Revert%
echo.
echo      [0] Back

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto %Routine%
if "%choice%"=="2" goto %Rev_Routine%
if "%choice%"=="0" goto %Menu%

echo. & echo [ERROR] Invalid selection. Please choose a valid option between (0-2)
pause & goto SUB_MENU

:GO
echo. & echo The operation is done.
pause & goto %1