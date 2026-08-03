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
if "%choice%"=="0" exit /b 99
if /i "%choice%"=="S" goto RUN_PROGRAMS
if /i "%choice%"=="A" (call "%F%" SELECT_ALL & goto PROGRAMS_MENU)
if /i "%choice%"=="D" (call "%F%" DESELECT_ALL & goto PROGRAMS_MENU)
if /i "%choice%"=="P" goto TOGGLE_AND_RETURN
if /i "%choice%"=="U" goto UPDATE_MENU
if /i "%choice%"=="X" goto REMOVE_MENU
if /i "%choice%"=="M" goto MORE_PROG
if /I "%choice%"=="B" goto BUCKET_MENU_VAR

call "%F%" MULTI_INPUT
goto PROGRAMS_MENU

:TOGGLE_AND_RETURN
call "%F%" TOGGLE_MANAGER
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

:BUCKET_MENU_VAR
set "BUCKET_COUNT=9"

if not "%PKGMGR%"=="SCOOP" (
    echo. & echo Buckets are only available when the package manager is Scoop
    pause
    goto PROGRAMS_MENU
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
