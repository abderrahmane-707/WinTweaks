:PROGRAMS_MANAGER_MENU
cls & echo. & echo.
echo                        ------------------------------ Programs Manager ---------------------------
echo.
echo                         [1] Download Programs                                 [2] Remove ALL MS Apps
echo.
echo                         [3] Programs Info                                     [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto PROGRAMS_MENU_VAR
if "%choice%"=="2" goto REMOVE_MS
if "%choice%"=="3" (call "%F%" INFO_SCRIPT "Programs" "ProgramsInfo"  & goto PROGRAMS_MANAGER_MENU)
if "%choice%"=="0" exit /b

call "%F%" INVALID "(0-4)" & goto PROGRAMS_MANAGER_MENU

:PROGRAMS_MENU_VAR
set "MAX_PROGS=18"
set "PKGMGR=CHOCO"
set "ON=(YES)"
set "OFF=(NO)"

call "%F%" DEFINE_CHOCO_PROGRAMS
call "%F%" DESELECT_ALL OPT %MAX_PROGS%

:PROGRAMS_MENU
call "%F%" ENSURE_PKGMGR
if %errorlevel% equ 1 goto PROGRAMS_MANAGER_MENU

cls & echo.
echo                        ----------------------------------- Programs -----------------------------------
echo.
    echo                            [1] Google Chrome             [7] K-Lite Codec              [13] qbittorrent
    echo.
    echo                            [2] Brave                     [8] IrfanView                 [14] VC++ 2015-2022
    echo.
    echo                            [3] Firefox                   [9] Sumatra PDF               [15] VirtualBox
    echo.
    echo                            [4] WinRAR                    [10] Notepad++                [16] IObit Unlocker
    echo.
    echo                            [5] 7-Zip                     [11] VS Code                  [17] AutoHotkey
    echo.
    echo                            [6] VLC                       [12] Git                      [18] MEGA
echo.
echo                        --------------------------------------------------------------------------------
echo.
echo                            [A] Select All               [D] Deselect All               [M] More
echo.
echo                            [U] Update Programs          [R] Remove Programs            [0] Back

echo. & echo Selected programs:
call "%F%" SHOW_SELECTED OPT NAME %MAX_PROGS%

echo. & echo Tip: You can select multiple items, e.g. 1,3,5 or 1-5 or 1-3,7,10-12

echo. & set "choice=" & set /p "choice=--> Select option(s) and press [S] to Start: "

if "%choice%"=="" goto PROGRAMS_MENU
if "%choice%"=="0" goto PROGRAMS_MANAGER_MENU
if /i "%choice%"=="S" goto RUN_PROGRAMS
if /i "%choice%"=="A" (call "%F%" SELECT_ALL OPT %MAX_PROGS% & goto PROGRAMS_MENU)
if /i "%choice%"=="D" (call "%F%" DESELECT_ALL OPT %MAX_PROGS% & goto PROGRAMS_MENU)
if /i "%choice%"=="U" goto UPDATE_MENU
if /i "%choice%"=="R" goto REMOVE_MENU
if /i "%choice%"=="M" goto MORE_PROG
if /I "%choice%"=="B" goto BUCKET_MENU_VAR

call "%F%" PROCESS_MULTI_INPUT OPT %MAX_PROGS%
goto PROGRAMS_MENU

:RUN_PROGRAMS
cls
for /L %%i in (1,1,%MAX_PROGS%) do (
    if "!OPT%%i!"=="%ON%" (
        call "%F%" TRY_ACTION "!PKG%%i!" "!NAME%%i!"
    )
)
call "%F%" GO & call "%F%" DESELECT_ALL OPT %MAX_PROGS% & goto PROGRAMS_MENU

:UPDATE_MENU
cls & echo Checking available updates

echo.
call choco outdated

echo.
echo --------------------------------------------------------------------------------
echo Type ALL to update everything
echo Or type the exact program name(s) as shown above, separated by commas
echo Type 0 to go back
echo --------------------------------------------------------------------------------

set "choice=" & set /p "choice=--> "
if "%choice%"=="0" goto PROGRAMS_MENU
if "%choice%"=="" goto UPDATE_MENU

call "%F%" PKG_BULK_ACTION "upgrade"
call "%F%" GO & goto PROGRAMS_MENU

:REMOVE_MENU
call choco list
echo.
echo --------------------------------------------------------------------------------
echo Type ALL to remove everything.
echo Or type the exact program name(s) as shown above, separated by commas
echo Type 0 to go back.
echo --------------------------------------------------------------------------------

set "choice=" & set /p "choice=--> "
if "%choice%"=="0" goto PROGRAMS_MENU
if "%choice%"=="" goto REMOVE_MENU

call "%F%" PKG_BULK_ACTION "uninstall"
call "%F%" GO & goto PROGRAMS_MENU

:MORE_PROG
cls & set "apps=" & set /p apps="Enter app name(s) separated by spaces: "
if "%apps%"=="" goto MORE_PROG

for %%A in (%apps%) do call "%F%" PROCESS_APP "%%A"
call "%F%" GO & goto PROGRAMS_MENU

:REMOVE_MS
call "%F%" CONFIRM "WARNING: This will remove ALL Microsoft Store apps"
if errorlevel 2 goto PROGRAMS_MANAGER_MENU

powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Programs\Remove_All_MS.ps1"
call "%F%" GO & goto PROGRAMS_MANAGER_MENU