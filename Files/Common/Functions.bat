@echo off

if "%~1" neq "" (
    call :%*
    exit /b
)
exit /b 1

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

:INIT_PACKAGES
:: Browsers
set "ITEM1=googlechrome|Google Chrome"
set "ITEM2=brave|Brave"
set "ITEM3=firefox|Firefox"

:: Archivers
set "ITEM4=winrar|WinRAR"
set "ITEM5=7zip.install|7-Zip"

:: Media
set "ITEM6=vlc.install|VLC"
set "ITEM7=k-litecodecpack-standard|K-Lite Codec"
set "ITEM8=irfanview irfanviewplugins|IrfanView"

:: Documents
set "ITEM9=sumatrapdf.install|Sumatra PDF"

:: Text Editors / Dev Tools
set "ITEM10=notepadplusplus.install|Notepad++"
set "ITEM11=vscode.install|VS Code"
set "ITEM12=git.install|Git"

:: Utilities
set "ITEM13=qbittorrent|qbittorrent"
set "ITEM14=vcredist140|VC++ 2015-2022"
set "ITEM15=virtualbox|VirtualBox"
set "ITEM16=io-unlocker|IObit Unlocker"
set "ITEM17=autohotkey.install|AutoHotkey"
set "ITEM18=megasync|MEGA"

call :DESELECT_ALL_PKG
exit /b

:RENDER_COLUMNS
set /a "ROWS=(MAX_PKG+2)/3"
for /L %%r in (1,1,%ROWS%) do (
    set "line="
    for %%x in (1 2 3) do (
        set /a "idx=%%r+ROWS*(%%x-1)"
        set "cell=                         "
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
    echo                  !line!
)
exit /b

:MULTI_INPUT
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
            if !rangeStart! geq 1 if !rangeEnd! leq !MAX_PKG! if !rangeStart! leq !rangeEnd! (
                for /L %%N in (!rangeStart!,1,!rangeEnd!) do (
                    for %%V in (OPT%%N) do (
                        if "!%%V!"=="%ON%" (set "%%V=%OFF%") else (set "%%V=%ON%")
                    )
                )
                set "matched=1"
            )
        )
    ) else (
        set "isNum=1" & for /f "delims=0123456789" %%C in ("!tok!") do set "isNum=0"
        if "!isNum!"=="1" if defined tok (
            if !tok! geq 1 if !tok! leq !MAX_PKG! (
                for %%V in (OPT!tok!) do (
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

:UNINSTALL_ACTION
if /i "!choice!"=="ALL" (
    echo Removing all packages...
    for /f "tokens=1 delims=|" %%P in ('call choco list -r 2^>nul') do (
        if not "%%P"=="" (
            echo %%P | findstr /i /x "chocolatey" >nul || call choco uninstall %%P -y
        )
    )
) else (
    set "targets=!choice:,= !"
    echo. & echo Removing: !targets!
    call choco uninstall !targets! -y
)
exit /b

:SELECT_ALL_PKG
for /L %%i in (1,1,%MAX_PKG%) do set "OPT%%i=%ON%"
exit /b

:DESELECT_ALL_PKG
for /L %%i in (1,1,%MAX_PKG%) do set "OPT%%i=%OFF%"
exit /b

:PRINT_ACTION_PROMPT
echo.
echo --------------------------------------------------------------------------------
echo Type ALL to %~1 everything
echo Or type the exact name(s) as shown above, separated by spaces
echo Type 0 to go back
echo --------------------------------------------------------------------------------
exit /b

:WHERE_CHOCO
where choco >nul 2>&1 && exit /b 0

call :CHOICE "Do you want to install Chocolatey package manager"
if errorlevel 2 exit /b 1

echo. & echo Installing Chocolatey package manager
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Packages\InstallChoco.ps1"
call "%ALLUSERSPROFILE%\chocolatey\bin\RefreshEnv.cmd" >nul

where choco >nul 2>&1
if !errorlevel! neq 0 (
    echo Chocolatey installation failed or not found in PATH
    call :GO & exit /b 1
)
exit /b 0

:TRY_ACTION
echo. & echo Installing: %~2
call choco install %~1 -y
if !errorlevel! neq 0 (
    echo. & echo Failed to install: %~2
	call :CHOICE "Do you want to ignore checksum and retry"
    if errorlevel 2 (
        echo The packages installation was skipped
    ) else (
        echo. & echo Retrying with --ignore-checksums
        call choco install %~1 --ignore-checksums -y
    )
)
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
    choice /C YN /M "Do you want to install !official_pkg!?"
    if errorlevel 2 (
        echo Installation skipped
    ) else (
        call :TRY_ACTION "!official_pkg!" "!official_pkg!"
    )
) else (
    echo No exact match for "!query!" was found
    echo Similar packages available in Chocolatey:
    echo. & call choco search "!query!" --limit-output
    echo. & echo No package was installed automatically. Check the list above and pick the correct name if available
)

del "%temp%\choco_result.txt" >nul 2>&1
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
