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
if "%choice%"=="0" exit /b 99

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