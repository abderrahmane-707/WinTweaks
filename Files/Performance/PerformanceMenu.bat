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
    call "%F%" SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="3" (
    set ROUTINE=BOOT_TWEAKS
    set REV_ROUTINE=REV_BOOT_TWEAKS
    set APPLY=Enhance boot-up settings
    set REVERT=Set boot-up settings to default
    set MENU=PERFORMANCE_MENU
    call "%F%" SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="4" goto CLEAN_UP
if "%choice%"=="5" goto POWER_PLAN_MENU
if "%choice%"=="6" goto HW_INFO_MENU
if "%choice%"=="0" exit /b

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
    call "%F%" SUB_MENU
    goto !SUBMENU_RESULT!
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