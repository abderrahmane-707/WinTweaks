@echo off

if "%~1" neq "" (
    call :%*
    exit /b
)
exit /b 1

:SET_SERVICES
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
exit /b

:SET_TASKS
for /f "usebackq delims=" %%i in ("%~2") do (
    set "TASK_NAME=%%i"
    set "TASK_RESULT=[SUCCESS]"

    schtasks /query /tn "%%i" >nul 2>&1
    if !errorlevel! neq 0 (
        set "TASK_RESULT=[NOT_FOUND]"
    ) else (
        if /i "%~1"=="Disable" (
            schtasks /change /tn "%%i" /disable >nul 2>&1
        ) else (
            schtasks /change /tn "%%i" /enable >nul 2>&1
        )

        if !errorlevel! neq 0 (
            set "TASK_RESULT=[FAILED]"
        )
    )

    echo !TASK_RESULT!: !TASK_NAME! >>"%LOG_FILE%"
)
exit /b

:BOOT_TWEAKS
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
exit /b

:REV_BOOT_TWEAKS
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
exit /b

:FOUND_BACKUP
echo. & call :CHOICE "WARNING: Restoring previous startup settings is NOT recommended. Press (N) if you are unsure"
if errorlevel 2 exit /b

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
call "%F%" PATH_DIR "%~1" "%~2"
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

call "%F%" PRINT_ACTION_PROMPT "%~1"

set "choice=" & set /p "choice=--> "
if "%choice%"=="0" (del "%listfile%" >nul 2>&1 & exit /b 2)

call "%F%" PKG_BULK_ACTION "%~4" "%listfile%"
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
:: %~1 = Service Name
:: %~2 = Start Type
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
call "%F%" MKDIR_PROMPT "%PROGRAMDATA%\WinTweaks\%~1"

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
    call "%F%" MKDIR_PROMPT "%PROGRAMDATA%\WinTweaks\%~1\%~2"
)
exit /b

:PATH_DIR
:: Define the base directory within PROGRAMDATA for organizational consistency
call "%F%" MKDIR_PROMPT "%PROGRAMDATA%\WinTweaks\%~1"

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
