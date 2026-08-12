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
if "%choice%"=="0" exit /b

call "%F%" INVALID "(0-4)" & goto PROGRAMS_MANAGER_MENU

:PROGRAMS_MENU_VAR
set "MAX_PROGS=18"
set "PKGMGR=CHOCO"
set "ON=(YES)"
set "OFF=(NO)"

call "%F%" DEFINE_SCOOP_PROGRAMS
call "%F%" DEFINE_CHOCO_PROGRAMS
call "%F%" DEFINE_SCOOP_BUCKETS
call "%F%" DESELECT_ALL OPT %MAX_PROGS%
call "%F%" DESELECT_ALL BOPT %BUCKET_COUNT%
call "%F%" LOAD_PKGMGR_DATA

:PROGRAMS_MENU
call "%F%" ENSURE_PKGMGR
if %errorlevel% equ 1 goto PROGRAMS_MANAGER_MENU

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
    echo                            [5] 7-Zip                     [11] VS Code                  [17] AutoHotkey
    echo.
    echo                            [6] VLC                       [12] Git                      [18] MEGA
) else (
    echo                            [1] GCC                      [7] Git                       [13] ripgrep
    echo.
    echo                            [2] LLVM                     [8] SourceGit                 [14] fd
    echo.
    echo                            [3] GDB Debugger             [9] VS Code                   [15] fastfetch
    echo.
    echo                            [4] Make                     [10] Neovim                   [16] micro
    echo.
    echo                            [5] CMake                    [11] Python                   [17] yazi
    echo.
    echo                            [6] Ninja                    [12] cURL                     [18] btop
)

echo.
echo                        --------------------------------------------------------------------------------
echo.
echo                            [A] Select All               [D] Deselect All               [M] More
echo.
echo                            [U] Update Programs          [R] Remove Programs            [0] Back

if "%PKGMGR%"=="SCOOP" (
    echo.
	echo                            [B] Manage Buckets
)

echo. & echo Selected programs:
call "%F%" SHOW_SELECTED OPT NAME %MAX_PROGS%

echo. & echo Tip: You can select multiple items, e.g. 1,3,5 or 1-5 or 1-3,7,10-12

echo. & set "choice=" & set /p "choice=--> Select option(s) and press [S] to Start: "

if "%choice%"=="" goto PROGRAMS_MENU
if "%choice%"=="0" goto PROGRAMS_MANAGER_MENU
if /i "%choice%"=="S" goto RUN_PROGRAMS
if /i "%choice%"=="A" (call "%F%" SELECT_ALL OPT %MAX_PROGS% & goto PROGRAMS_MENU)
if /i "%choice%"=="D" (call "%F%" DESELECT_ALL OPT %MAX_PROGS% & goto PROGRAMS_MENU)
if /i "%choice%"=="P" (call "%F%" TOGGLE_MANAGER & call "%F%" DESELECT_ALL OPT %MAX_PROGS% & goto PROGRAMS_MENU)
if /i "%choice%"=="U" goto UPDATE_MENU
if /i "%choice%"=="R" goto REMOVE_MENU
if /i "%choice%"=="M" goto MORE_PROG
if /I "%choice%"=="B" goto BUCKET_MENU_VAR

call "%F%" PROCESS_MULTI_INPUT OPT %MAX_PROGS%
goto PROGRAMS_MENU

:RUN_PROGRAMS
cls
if "%PKGMGR%"=="SCOOP" call "%F%" WHERE_7Z
for /L %%i in (1,1,%MAX_PROGS%) do (
    if "!OPT%%i!"=="%ON%" (
        call "%F%" TRY_ACTION "!PKG%%i!" "!NAME%%i!"
    )
)
call "%F%" GO & call "%F%" DESELECT_ALL OPT %MAX_PROGS% & goto PROGRAMS_MENU

:UPDATE_MENU
cls & echo Checking available updates

echo.
if "%PKGMGR%"=="CHOCO" (
    call choco outdated
) else (
    call "%F%" WHERE_7Z
    call scoop update
    call scoop status
)

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
cls & if "%PKGMGR%"=="CHOCO" (call choco list) else (call scoop list)
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

if "%PKGMGR%"=="SCOOP" call "%F%" WHERE_7Z
for %%A in (%apps%) do call "%F%" PROCESS_APP "%%A"
call "%F%" GO & goto PROGRAMS_MENU

:BUCKET_MENU_VAR
if not "%PKGMGR%"=="SCOOP" (
    echo. & echo Buckets are only available when the package manager is Scoop
    pause & goto PROGRAMS_MENU
)

:BUCKET_MENU
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
call "%F%" SHOW_SELECTED BOPT BUCKET %BUCKET_COUNT%

echo. & echo Tip: You can select multiple items, e.g. 1,3,5 or 1-5 or 1-3,7,10-12

echo. & set "choice=" & set /p "choice=--> Select option(s): "

if "%choice%"=="" goto BUCKET_MENU
if "%choice%"=="0" goto PROGRAMS_MENU
if /i "%choice%"=="A" (call "%F%" SELECT_ALL BOPT %BUCKET_COUNT% & goto BUCKET_MENU)
if /i "%choice%"=="D" (call "%F%" DESELECT_ALL BOPT %BUCKET_COUNT% & goto BUCKET_MENU)
if /i "%choice%"=="I" goto INSTALL_BUCKETS
if /i "%choice%"=="R" goto REMOVE_BUCKETS

call "%F%" PROCESS_MULTI_INPUT BOPT %BUCKET_COUNT%
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
call "%F%" GO & call "%F%" DESELECT_ALL BOPT %BUCKET_COUNT% & goto BUCKET_MENU

:REMOVE_BUCKETS
cls & echo Removing Buckets
echo.
for /L %%i in (1,1,%BUCKET_COUNT%) do (
    if "!BOPT%%i!"=="%ON%" (
        echo Removing: !BUCKET%%i!
        call scoop bucket rm !BUCKET%%i!
    )
)
call "%F%" GO & call "%F%" DESELECT_ALL BOPT %BUCKET_COUNT% & goto BUCKET_MENU

:REMOVE_MS
call "%F%" CONFIRM "WARNING: This will remove ALL Microsoft Store apps"
if errorlevel 2 goto PROGRAMS_MANAGER_MENU

powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Programs\Remove_All_MS.ps1"
call "%F%" GO & goto PROGRAMS_MANAGER_MENU