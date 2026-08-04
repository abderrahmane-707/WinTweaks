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
    echo                            [3] GDB Debugger             [9] VS Code                   [15] fzf
    echo.
    echo                            [4] Make                     [10] Neovim                   [16] bat
    echo.
    echo                            [5] CMake                    [11] Python                   [17] duf
    echo.
    echo                            [6] Ninja                    [12] cURL                     [18] dust
)

echo.
echo                        --------------------------------------------------------------------------------
echo.
echo                             [A] Select All               [D] Deselect All             [M] More
echo.
echo                             [U] Update Programs          [R] Remove Programs          [0] Back

if "%PKGMGR%"=="SCOOP" (
    echo.
	echo                             [B] Manage Buckets
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
for /L %%i in (1,1,%MAX_PROGS%) do (
    if "!OPT%%i!"=="%ON%" (
        call "%F%" TRY_ACTION "!PKG%%i!" "!NAME%%i!"
    )
)
call "%F%" GO & call "%F%" DESELECT_ALL OPT %MAX_PROGS% & goto PROGRAMS_MENU

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

:DOWNLOAD_MO
:: Define basic variables
set "ON=(YES)"
set "OFF=(NO)"
set "MAX_PROGS=12"

:: Set default programs values - ALL OFF by default
call "%F%" DESELECT_ALL OPT %MAX_PROGS%

:: Program names to use the generic SHOW_SELECTED function
set "NAME1=Word" & set "NAME2=Excel" & set "NAME3=PowerPoint" & set "NAME4=Outlook"
set "NAME5=OneNote" & set "NAME6=Publisher" & set "NAME7=Access" & set "NAME8=Visio"
set "NAME9=Project" & set "NAME10=Proofing Tools" & set "NAME11=Teams" & set "NAME12=OneDrive"

:: Determine processor architecture automatically
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set "CPU=64"
    set "ARCH_MSG=64-bit"
) else if "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
    set "CPU=64"
    set "ARCH_MSG=64-bit (ARM64)"
) else (
    set "CPU=32"
    set "ARCH_MSG=32-bit"
)

:: Additional check for 64-bit OS running 32-bit cmd
if "%PROCESSOR_ARCHITEW6432%"=="AMD64" (
    set "CPU=64"
    set "ARCH_MSG=64-bit (Auto-detected from 64-bit OS)"
)

:: Check for offline files
if exist "Files\Programs\Office\Data\stream*.dat" (
    set "OFILES=%ON%"
) else (
    set "OFILES=%OFF%"
)

:: Set default Office version
set "OPTV=2021"

:: Installation Mode: %ON%=Online, %OFF%=Offline
set "OPTM=%ON%"

:: Language: ar-sa, en-us
set "OPTL=en-us"

:: Set configuration file path
set "CONFIG_FILE=Files\Programs\configuration.xml"

:: Main interface
:OFFICE_MENU
cls
echo.
echo                                                 \\!//
echo                                                 (o o)
echo              -------------------------------oOOo-(_)-oOOo-------------------------------
echo                                     Microsoft Office Installation Tool
echo              ---------------------------------------------------------------------------
echo.

:: Set Office version message
if "%OPTV%"=="365" set "VERSION_MSG=Office 365"
if "%OPTV%"=="2021" set "VERSION_MSG=Office 2021"
if "%OPTV%"=="2019" set "VERSION_MSG=Office 2019"
if "%OPTV%"=="2016" set "VERSION_MSG=Office 2016"

:: Set installation mode message
if "%OPTM%,%OFILES%"=="%ON%,%OFF%" set "MOD_MSG=Online Installation"
if "%OPTM%,%OFILES%"=="%OFF%,%OFF%" set "MOD_MSG=Download Offline Files"
if "%OPTM%,%OFILES%"=="%OFF%,%ON%" set "MOD_MSG=Delete Offline Files"
if "%OPTM%,%OFILES%"=="%ON%,%ON%" set "MOD_MSG=Offline Installation"

:: Set language message
if "%OPTL%"=="ar-sa" set "LANG_MSG=ar-sa"
if "%OPTL%"=="en-us" set "LANG_MSG=en-us"

echo                   [1] Word                  [5] OneNote             [9] Project
echo                   [2] Excel                 [6] Publisher           [10] Proofing Tools
echo                   [3] PowerPoint            [7] Access              [11] Teams
echo                   [4] Outlook               [8] Visio               [12] OneDrive
echo.
echo    [V] Version:  %VERSION_MSG%
echo    [L] Language: %LANG_MSG%
echo    [M] Mode:     %MOD_MSG%
echo.
echo                   [A] Select All          [D] Deselect All             [0] Back
echo.
echo              ---------------------------------------------------------------------------

echo. & echo Selected programs for %ARCH_MSG%:
call "%F%" SHOW_SELECTED OPT NAME %MAX_PROGS%

echo. & echo Tip: you can select multiple items, e.g. 1,3,5 or 1-5 or 1-3,7,10-12

set "choice=" & set /p "choice=--> Select an option(s) and press [S] to Start: "
if "%choice%"=="" goto OFFICE_MENU

:: Process single-key input
for /l %%i in (1,1,12) do (
    if "%choice%"=="%%i" (
        call "%F%" TOGGLE_SINGLE OPT%%i && goto OFFICE_MENU
    )
)

if "%choice%"=="0" goto PROGRAMS_MANAGER_MENU
if /i "%choice%"=="V" call "%F%" TOGGLE_VERSION && goto OFFICE_MENU
if /i "%choice%"=="L" call "%F%" TOGGLE_LANGUAGE && goto OFFICE_MENU
if /i "%choice%"=="M" call "%F%" TOGGLE_SINGLE OPTM && goto OFFICE_MENU
if /i "%choice%"=="A" (call "%F%" SELECT_ALL OPT %MAX_PROGS% & goto OFFICE_MENU)
if /i "%choice%"=="D" (call "%F%" DESELECT_ALL OPT %MAX_PROGS% & goto OFFICE_MENU)
if /i "%choice%"=="S" goto CONTINUE

call "%F%" PROCESS_MULTI_INPUT OPT %MAX_PROGS%
goto OFFICE_MENU

:: Continue installation
:CONTINUE
cls
set "HASSELECTION=%OFF%"
for /l %%i in (1,1,12) do (
    call "%F%" IS_ON OPT%%i && set "HASSELECTION=%ON%"
)

if "!HASSELECTION!"=="%OFF%" (
    echo. & echo No programs was selected
    pause
    goto OFFICE_MENU
)

echo. & echo Selected programs:
call "%F%" SHOW_SELECTED OPT NAME %MAX_PROGS%

echo.
echo    Installation Architecture: %ARCH_MSG%
echo    Installation Version: %OPTV%
echo    Language: %LANG_MSG%
echo    Installation Mode: %MOD_MSG%

call "%F%" CHOICE "Do you want to start?"
if errorlevel 2 goto OFFICE_MENU

:: Process based on installation mode and offline files status
if "%OPTM%,%OFILES%"=="%OFF%,%OFF%" goto DOWNLOAD_FILES
if "%OPTM%,%OFILES%"=="%OFF%,%ON%" goto DELETE_FILES
if "%OPTM%,%OFILES%"=="%ON%,%ON%" goto OFFLINE_INSTALL
if "%OPTM%,%OFILES%"=="%ON%,%OFF%" goto ONLINE_INSTALL

:DOWNLOAD_FILES
echo Downloading Office files
call "%F%" CONFIG
echo. & echo Downloading Microsoft Office %OPTV% %CPU%-bit
"Files\Programs\setup.exe" /download "%CONFIG_FILE%"
if errorlevel 1 (
    echo. & echo Download failed with exit code !errorlevel!
    call "%F%" DEL_CONFIG
    exit /b 1
)
goto END

:DELETE_FILES
echo. & echo Deleting Microsoft Office Installation Files
rd /s /q "Files\Programs\Office" >nul 2>&1
if exist "Files\Programs\Office" (
    echo Could not delete offline files
)

pause & goto OFFICE_MENU

:OFFLINE_INSTALL
echo. & echo Installing Microsoft Office from offline files
call "%F%" CONFIG
"Files\Programs\setup.exe" /configure "%CONFIG_FILE%"
if errorlevel 1 (
    echo. & echo Installation failed with exit code !errorlevel!
    call "%F%" DEL_CONFIG
    exit /b 1
)
goto END

:ONLINE_INSTALL
call "%F%" CONFIG
echo. & echo Installing Microsoft Office (Online)
"Files\Programs\setup.exe" /configure "%CONFIG_FILE%"
if errorlevel 1 (
    echo. & echo Installation failed with exit code !errorlevel!
    call "%F%" DEL_CONFIG
    exit /b 1
)
goto END

:END
call "%F%" DEL_CONFIG
echo. & echo Disabling Microsoft Office Telemetry
reg add "HKLM\SOFTWARE\Microsoft\Office\Common\ClientTelemetry" /v "DisableTelemetry" /t REG_DWORD /d "00000001" /f >nul 2>&1
exit /b

:REMOVE_MS
call "%F%" CONFIRM "WARNING: This will remove ALL Microsoft Store apps"
if errorlevel 2 goto PROGRAMS_MANAGER_MENU

powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Programs\Remove_All_MS.ps1"
call "%F%" GO & goto PROGRAMS_MANAGER_MENU