@echo off

if "%~1" neq "" (
    call :%*
    exit /b
)
exit /b 1

:: ----------------------------------------------------------------< MAIN FUNCTIONS >----------------------------------------------------------------
:SET_TASKS
:: %~1 = Action (Enable/Disable)
:: %~2 = Path to text file containing task names

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

:SELECT_ALL
for /L %%i in (1,1,%~2) do set "%~1%%i=%ON%"
exit /b

:DESELECT_ALL
for /L %%i in (1,1,%~2) do set "%~1%%i=%OFF%"
exit /b

:: %1 = value var prefix (e.g. OPT), %2 = value to toggle against
:TOGGLE_SINGLE
if "!%~1!"=="%ON%" (set "%~1=%OFF%") else (set "%~1=%ON%")
exit /b

:IS_ON
if "!%~1!"=="%ON%" exit /b 0
exit /b 1

:: %1 = OPT-prefix, %2 = NAME-prefix, %3 = max
:SHOW_SELECTED
set "ANY=0"
for /L %%i in (1,1,%~3) do (
    set "cur=!%~1%%i!"
    set "lbl=!%~2%%i!"
    if "!cur!"=="%ON%" (
        echo    - !lbl!
        set "ANY=1"
    )
)
if "!ANY!"=="0" echo    - No selection
exit /b

:PROCESS_MULTI_INPUT
:: %1 = Option Prefix (e.g., OPT or BOPT)
:: %2 = Max Limit (e.g., %MAX_PROGS% or %BUCKET_COUNT%)

set "prefix=%~1"
set "maxLimit=%~2"
set "invalid="
set "tokens=%choice:,= %"

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
            if !rangeStart! geq 1 if !rangeEnd! leq !maxLimit! if !rangeStart! leq !rangeEnd! (
                for /L %%N in (!rangeStart!,1,!rangeEnd!) do call :TOGGLE_SINGLE !prefix!%%N
                set "matched=1"
            )
        )
    ) else (
        set "isNum=1" & for /f "delims=0123456789" %%C in ("!tok!") do set "isNum=0"
        if "!isNum!"=="1" if defined tok (
            if !tok! geq 1 if !tok! leq !maxLimit! (
                call :TOGGLE_SINGLE !prefix!!tok!
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

:DEFINE_SCOOP_PROGRAMS
set "SCOOP_PKG1=gcc"                          & set "SCOOP_NAME1=GCC"
set "SCOOP_PKG2=llvm"                         & set "SCOOP_NAME2=LLVM"
set "SCOOP_PKG3=gdb"                          & set "SCOOP_NAME3=GDB Debugger"
set "SCOOP_PKG4=make"                         & set "SCOOP_NAME4=Make"
set "SCOOP_PKG5=cmake"                        & set "SCOOP_NAME5=CMake"
set "SCOOP_PKG6=ninja"                        & set "SCOOP_NAME6=Ninja"
set "SCOOP_PKG7=git"                          & set "SCOOP_NAME7=Git"
set "SCOOP_PKG8=sourcegit"                    & set "SCOOP_NAME8=SourceGit"
set "SCOOP_PKG9=vscode"                       & set "SCOOP_NAME9=VS Code"
set "SCOOP_PKG10=neovim"                      & set "SCOOP_NAME10=Neovim"
set "SCOOP_PKG11=python"                      & set "SCOOP_NAME11=Python"
set "SCOOP_PKG12=curl"                        & set "SCOOP_NAME12=cURL"
set "SCOOP_PKG13=ripgrep"                     & set "SCOOP_NAME13=ripgrep"
set "SCOOP_PKG14=fd"                          & set "SCOOP_NAME14=fd"
set "SCOOP_PKG15=fastfetch"                         & set "SCOOP_NAME15=fastfetch"
set "SCOOP_PKG16=micro"                         & set "SCOOP_NAME16=micro"
set "SCOOP_PKG17=yazi"                         & set "SCOOP_NAME17=yazi"
set "SCOOP_PKG18=btop"                        & set "SCOOP_NAME18=btop"
exit /b

:DEFINE_CHOCO_PROGRAMS
set "CHOCO_PKG1=googlechrome"                & set "CHOCO_NAME1=Google Chrome"
set "CHOCO_PKG2=brave"                       & set "CHOCO_NAME2=Brave"
set "CHOCO_PKG3=firefox"                     & set "CHOCO_NAME3=Firefox"
set "CHOCO_PKG4=winrar"                      & set "CHOCO_NAME4=WinRAR"
set "CHOCO_PKG5=7zip.install"                & set "CHOCO_NAME5=7-Zip"
set "CHOCO_PKG6=vlc.install"                 & set "CHOCO_NAME6=VLC"
set "CHOCO_PKG7=k-litecodecpack-standard"    & set "CHOCO_NAME7=K-Lite Codec"
set "CHOCO_PKG8=irfanview irfanviewplugins"  & set "CHOCO_NAME8=IrfanView"
set "CHOCO_PKG9=sumatrapdf.install"          & set "CHOCO_NAME9=Sumatra PDF"
set "CHOCO_PKG10=notepadplusplus.install"    & set "CHOCO_NAME10=Notepad++"
set "CHOCO_PKG11=vscode.install"             & set "CHOCO_NAME11=VS Code"
set "CHOCO_PKG12=git.install"                & set "CHOCO_NAME12=Git"
set "CHOCO_PKG13=qbittorrent"                & set "CHOCO_NAME13=qbittorrent"
set "CHOCO_PKG14=vcredist140"                & set "CHOCO_NAME14=VC++ 2015-2022"
set "CHOCO_PKG15=virtualbox"                 & set "CHOCO_NAME15=VirtualBox"
set "CHOCO_PKG16=io-unlocker"                & set "CHOCO_NAME16=IObit Unlocker"
set "CHOCO_PKG17=autohotkey.install"         & set "CHOCO_NAME17=AutoHotkey"
set "CHOCO_PKG18=megasync"                   & set "CHOCO_NAME18=MEGA"
exit /b

:LOAD_PKGMGR_DATA
for /L %%i in (1,1,%MAX_PROGS%) do (
    if "%PKGMGR%"=="CHOCO" (
        set "PKG%%i=!CHOCO_PKG%%i!"
        set "NAME%%i=!CHOCO_NAME%%i!"
    ) else (
        set "PKG%%i=!SCOOP_PKG%%i!"
        set "NAME%%i=!SCOOP_NAME%%i!"
    )
)
exit /b

:TOGGLE_MANAGER
if "%PKGMGR%"=="CHOCO" (set "PKGMGR=SCOOP") else (set "PKGMGR=CHOCO")
call :DESELECT_ALL OPT %MAX_PROGS%
call :LOAD_PKGMGR_DATA
exit /b

:DEFINE_SCOOP_BUCKETS
set "BUCKET_COUNT=9"
set "BUCKET1=extras"
set "BUCKET2=versions"
set "BUCKET3=java"
set "BUCKET4=php"
set "BUCKET5=games"
set "BUCKET6=nerd-fonts"
set "BUCKET7=nonportable"
set "BUCKET8=sysinternals"
set "BUCKET9=nirsoft"
exit /b

:ENSURE_PKGMGR
if "%PKGMGR%"=="CHOCO" (
    where choco >nul 2>&1
    if !errorlevel! equ 0 exit /b 0

    cls & call :CHOICE "Do you want to install Chocolatey package manager"
    if errorlevel 2 exit /b 1

    echo. & echo Installing Chocolatey package manager
    powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Programs\InstallChoco.ps1"
    call :REFRESH_ENV
    where choco >nul 2>&1
    if !errorlevel! neq 0 (
        echo Chocolatey installation failed or not found in PATH
		call "%F%" GO & exit /b 1
    )
) else (
    where scoop >nul 2>&1
    if !errorlevel! equ 0 exit /b 0

    cls & call :CHOICE "Do you want to install Scoop package manager"
    if errorlevel 2 exit /b 1

    echo. & echo Installing Scoop package manager
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')"
    if exist "%USERPROFILE%\scoop\shims" set "PATH=%PATH%;%USERPROFILE%\scoop\shims"
    where scoop >nul 2>&1
    if !errorlevel! neq 0 (
        echo Scoop installation failed or not found in PATH
        call "%F%" GO & exit /b 1
    )
	call scoop config auto_cleanup true >nul 2>&1
	call "%F%" WHERE_7Z
)
exit /b 0

:REFRESH_ENV
if exist "%ALLUSERSPROFILE%\chocolatey\bin\refreshenv.cmd" (
    call "%ALLUSERSPROFILE%\chocolatey\bin\refreshenv.cmd" >nul 2>&1
) else (
    if exist "%ALLUSERSPROFILE%\chocolatey\bin" set "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
)
exit /b

:TRY_ACTION
echo. & echo Installing: %~2
if "%PKGMGR%"=="CHOCO" (
    choco install %~1 -y
    if !errorlevel! neq 0 (
        echo. & echo Failed to install: %~2
        call :CHOICE "Do you want to ignore checksum and retry?"
        if errorlevel 2 (
            echo The program download was ignored
        ) else (
            echo. & echo Retrying with --ignore-checksums
            choco install %~1 --ignore-checksums -y
        )
    )
) else (
    call scoop install -k %~1
    if !errorlevel! neq 0 (
        echo. & echo Failed to install: %~2
    )
)
exit /b

:PROCESS_APP
set "app=%~1"
echo. & echo Searching for: %app%
if "%PKGMGR%"=="CHOCO" (
    choco search "%app%" --exact --limit-output > "%temp%\choco_result.txt" 2>nul

    set "found=0"
    set "official_pkg="
    set "official_version="
    for /f "tokens=1,2 delims=|" %%L in ('type "%temp%\choco_result.txt" 2^>nul') do (
        set "found=1"
        set "official_pkg=%%L"
        set "official_version=%%M"
    )

    if "!found!"=="1" (
        echo.
        echo Official package found: !official_pkg! !official_version!
        call :CHOICE "Do you want to install !official_pkg!?"
        if errorlevel 2 (
            echo Installation skipped
        ) else if errorlevel 1 (
            call :TRY_ACTION "!official_pkg!" "!official_pkg!"
        )
    ) else (
        echo No exact match for "%app%" was found
        echo Similar packages available in Chocolatey:
        echo.
        choco search "%app%" --limit-output
        echo.
        echo No package was installed automatically. Check the list above and pick the correct name if available
    )
    del "%temp%\choco_result.txt" >nul 2>&1
) else (
    scoop search "%app%"
    echo.
    set "installName="
    set /p "installName=Enter the exact package name to install (or leave blank to skip): "
    if not "!installName!"=="" call :TRY_ACTION "!installName!" "!installName!"
)
exit /b

:PKG_BULK_ACTION
set "bulkAction=%~1"

if /i "%choice%"=="ALL" (
    cls
    if /i "%bulkAction%"=="upgrade" (
        echo Updating all programs
        if "%PKGMGR%"=="CHOCO" (call choco upgrade all -y) else (call scoop update -k * && call scoop cleanup *)
    ) else (
        echo Removing all programs
        if "%PKGMGR%"=="CHOCO" (
            for /f "tokens=1 delims=|" %%P in ('call choco list -r 2^>nul') do (
                if not "%%P"=="" call choco uninstall %%P -y
            )
        ) else (
            for /f "skip=1 tokens=1" %%P in ('call scoop list 2^>nul') do (
                if not "%%P"=="" call scoop uninstall %%P
            )
        )
    )
) else (
    cls
    for %%G in (%choice:,= %) do (
        echo. & echo Processing: %%G
        if "%PKGMGR%"=="CHOCO" (
            call choco %bulkAction% %%G -y
        ) else (
            if /i "%bulkAction%"=="upgrade" (call scoop update -k %%G && call scoop cleanup %%G) else (call scoop uninstall %%G)
        )
    )
)
exit /b

:WHERE_7Z
where 7z.exe >nul 2>&1 && (
    call scoop config use_external_7zip true >nul 2>&1
) || (
    call scoop config use_external_7zip false >nul 2>&1
)
exit /b
	
:NET_CONTROL
:: %~1 = Service Name
:: %~2 = Action (stop or start)

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
    if errorlevel 2 exit /b 1

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
    if errorlevel 2 exit /b 1
    
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
:: %~1 = Subfolder name
:: %~2 = Log filename

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
        pause & exit
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
choice /C YN /N /M "%~1 (Y/N): "
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

:: ----------------------------------------------------------------< OFFICE FUNCTIONS >----------------------------------------------------------------

:TOGGLE_VERSION
if "%OPTV%"=="365" (set "OPTV=2021") else if "%OPTV%"=="2021" (set "OPTV=2019") else if "%OPTV%"=="2019" (set "OPTV=2016") else (set "OPTV=365")
exit /b

:TOGGLE_LANGUAGE
if "%OPTL%"=="ar-sa" (set "OPTL=en-us") else (set "OPTL=ar-sa")
exit /b

:CONFIG
echo. & echo Creating Configuration File for Microsoft Office %OPTV%
call :DEL_CONFIG

echo ^<?xml version="1.0" encoding="utf-8"?^> > "%CONFIG_FILE%"
echo ^<Configuration^> >> "%CONFIG_FILE%"

if "%OPTV%"=="365" (
    echo    ^<Add OfficeClientEdition="%CPU%" Channel="Current" MigrateArch="TRUE"^> >> "%CONFIG_FILE%"
) else if "%OPTV%"=="2019" (
    echo    ^<Add OfficeClientEdition="%CPU%" Channel="PerpetualVL2019" MigrateArch="TRUE"^> >> "%CONFIG_FILE%"
) else if "%OPTV%"=="2016" (
    echo    ^<Add OfficeClientEdition="%CPU%" Channel="PerpetualVL2016" MigrateArch="TRUE"^> >> "%CONFIG_FILE%"
) else if "%OPTV%"=="2021" (
    echo    ^<Add OfficeClientEdition="%CPU%" Channel="PerpetualVL2021" MigrateArch="TRUE"^> >> "%CONFIG_FILE%"
)

set "NEEDMAIN=%OFF%"
if "%OPT1%"=="%ON%" set "NEEDMAIN=%ON%"
if "%OPT2%"=="%ON%" set "NEEDMAIN=%ON%"
if "%OPT3%"=="%ON%" set "NEEDMAIN=%ON%"
if "%OPT4%"=="%ON%" set "NEEDMAIN=%ON%"
if "%OPT5%"=="%ON%" set "NEEDMAIN=%ON%"
if "%OPT6%"=="%ON%" set "NEEDMAIN=%ON%"
if "%OPT7%"=="%ON%" set "NEEDMAIN=%ON%"
if "%OPT11%"=="%ON%" set "NEEDMAIN=%ON%"
if "%OPT12%"=="%ON%" set "NEEDMAIN=%ON%"

if "%NEEDMAIN%"=="%ON%" (
    if "%OPTV%"=="365" (
        echo      ^<Product ID="O365ProPlusRetail"^> >> "%CONFIG_FILE%"
    ) else if "%OPTV%"=="2019" (
        echo      ^<Product ID="ProPlus2019Volume"^> >> "%CONFIG_FILE%"
    ) else if "%OPTV%"=="2016" (
        echo      ^<Product ID="ProPlusRetail"^> >> "%CONFIG_FILE%"
    ) else if "%OPTV%"=="2021" (
        echo      ^<Product ID="ProPlus2021Volume"^> >> "%CONFIG_FILE%"
    )

    if "%OPTL%"=="ar-sa" (
        echo        ^<Language ID="ar-sa" /^> >> "%CONFIG_FILE%"
    ) else if "%OPTL%"=="en-us" (
        echo        ^<Language ID="en-us" /^> >> "%CONFIG_FILE%"
    )

    echo        ^<ExcludeApp ID="Lync" /^> >> "%CONFIG_FILE%"
    echo        ^<ExcludeApp ID="Groove" /^> >> "%CONFIG_FILE%"
    echo        ^<ExcludeApp ID="Bing" /^> >> "%CONFIG_FILE%"

    if "%OPT1%"=="%OFF%" echo        ^<ExcludeApp ID="Word" /^> >> "%CONFIG_FILE%"
    if "%OPT2%"=="%OFF%" echo        ^<ExcludeApp ID="Excel" /^> >> "%CONFIG_FILE%"
    if "%OPT3%"=="%OFF%" echo        ^<ExcludeApp ID="PowerPoint" /^> >> "%CONFIG_FILE%"
    if "%OPT4%"=="%OFF%" echo        ^<ExcludeApp ID="Outlook" /^> >> "%CONFIG_FILE%"
    if "%OPT5%"=="%OFF%" echo        ^<ExcludeApp ID="OneNote" /^> >> "%CONFIG_FILE%"
    if "%OPT6%"=="%OFF%" echo        ^<ExcludeApp ID="Publisher" /^> >> "%CONFIG_FILE%"
    if "%OPT7%"=="%OFF%" echo        ^<ExcludeApp ID="Access" /^> >> "%CONFIG_FILE%"
    if "%OPT11%"=="%OFF%" echo        ^<ExcludeApp ID="Teams" /^> >> "%CONFIG_FILE%"
    if "%OPT12%"=="%OFF%" echo        ^<ExcludeApp ID="OneDrive" /^> >> "%CONFIG_FILE%"

    echo      ^</Product^> >> "%CONFIG_FILE%"
)

if "%OPT8%"=="%ON%" (
    if "%OPTV%"=="365" (
        echo      ^<Product ID="VisioProRetail"^> >> "%CONFIG_FILE%"
    ) else if "%OPTV%"=="2019" (
        echo      ^<Product ID="VisioPro2019Volume"^> >> "%CONFIG_FILE%"
    ) else if "%OPTV%"=="2016" (
        echo      ^<Product ID="VisioPro2016Volume"^> >> "%CONFIG_FILE%"
    ) else if "%OPTV%"=="2021" (
        echo      ^<Product ID="VisioPro2021Volume"^> >> "%CONFIG_FILE%"
    )
    if "%OPTL%"=="ar-sa" (
        echo        ^<Language ID="ar-sa" /^> >> "%CONFIG_FILE%"
    ) else if "%OPTL%"=="en-us" (
        echo        ^<Language ID="en-us" /^> >> "%CONFIG_FILE%"
    )
    echo        ^<ExcludeApp ID="Bing" /^> >> "%CONFIG_FILE%"
    echo      ^</Product^> >> "%CONFIG_FILE%"
)

if "%OPT9%"=="%ON%" (
    if "%OPTV%"=="365" (
        echo      ^<Product ID="ProjectProRetail"^> >> "%CONFIG_FILE%"
    ) else if "%OPTV%"=="2019" (
        echo      ^<Product ID="ProjectPro2019Volume"^> >> "%CONFIG_FILE%"
    ) else if "%OPTV%"=="2016" (
        echo      ^<Product ID="ProjectPro2016Volume"^> >> "%CONFIG_FILE%"
    ) else if "%OPTV%"=="2021" (
        echo      ^<Product ID="ProjectPro2021Volume"^> >> "%CONFIG_FILE%"
    )
    if "%OPTL%"=="ar-sa" (
        echo        ^<Language ID="ar-sa" /^> >> "%CONFIG_FILE%"
    ) else if "%OPTL%"=="en-us" (
        echo        ^<Language ID="en-us" /^> >> "%CONFIG_FILE%"
    )
    echo        ^<ExcludeApp ID="Bing" /^> >> "%CONFIG_FILE%"
    echo      ^</Product^> >> "%CONFIG_FILE%"
)

if "%OPT10%"=="%ON%" (
    echo      ^<Product ID="ProofingTools"^> >> "%CONFIG_FILE%"
    if "%OPTL%"=="ar-sa" (
        echo        ^<Language ID="ar-sa" /^> >> "%CONFIG_FILE%"
    ) else if "%OPTL%"=="en-us" (
        echo        ^<Language ID="en-us" /^> >> "%CONFIG_FILE%"
    )
    echo        ^<ExcludeApp ID="Bing" /^> >> "%CONFIG_FILE%"
    echo      ^</Product^> >> "%CONFIG_FILE%"
)

echo    ^</Add^> >> "%CONFIG_FILE%"
echo    ^<Display Level="Full" AcceptEULA="TRUE" /^> >> "%CONFIG_FILE%"
echo    ^<Property Name="ForceAppShutdown" Value="TRUE" /^> >> "%CONFIG_FILE%"
echo    ^<AppSettings^> >> "%CONFIG_FILE%"
echo        ^<User Key="software\microsoft\office\16.0\common" Name="ui theme" Value="5" Type="REG_DWORD" App="office16" Id="L_OfficeTheme" /^> >> "%CONFIG_FILE%"
echo        ^<User Key="software\microsoft\office\16.0\common" Name="default ui theme" Value="5" Type="REG_DWORD" App="office16" Id="L_OfficeDefaultTheme" /^> >> "%CONFIG_FILE%"
echo    ^</AppSettings^> >> "%CONFIG_FILE%"
echo ^</Configuration^> >> "%CONFIG_FILE%"

if not exist "%CONFIG_FILE%" (
    echo Failed to create configuration file!
    exit /b 1
)
exit /b

:DEL_CONFIG
del /f /q "%CONFIG_FILE%" >nul 2>&1
exit /b
