@echo off

:: Define basic variables
set "ON=(YES)"
set "OFF=(NO) "

:: Set default programs values - ALL OFF by default
for /L %%i in (1,1,12) do set "OPT%%i=%OFF%"

:: Define MAX_PROGS and Program Names to use the generic SHOW_SELECTED function
set "MAX_PROGS=12"
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
call "%F%" SHOW_SELECTED

echo. & echo Tip: you can select multiple items, e.g. 1,3,5 or 1-5 or 1-3,7,10-12

set "choice=" & set /p "choice=--> Select an option(s) and press [S] to Start: "
if "%choice%"=="" goto OFFICE_MENU

:: Process single-key input
for /l %%i in (1,1,12) do (
    if "%choice%"=="%%i" (
        call "%F%" TOGGLE_SINGLE OPT%%i && goto OFFICE_MENU
    )
)

if "%choice%"=="0" exit /b 99
if /i "%choice%"=="V" call "%F%" TOGGLE_VERSION && goto OFFICE_MENU
if /i "%choice%"=="L" call "%F%" TOGGLE_LANGUAGE && goto OFFICE_MENU
if /i "%choice%"=="M" call "%F%" TOGGLE_SINGLE OPTM && goto OFFICE_MENU
if /i "%choice%"=="A" goto SELECT_ALL
if /i "%choice%"=="D" goto DESELECT_ALL
if /i "%choice%"=="S" goto CONTINUE

call "%F%" MULTI_INPUT
goto OFFICE_MENU

:: Set "ON" for all programs
:SELECT_ALL
for /l %%i in (1,1,12) do set "OPT%%i=%ON%"
goto OFFICE_MENU

:: Set "OFF" for all programs
:DESELECT_ALL
for /l %%i in (1,1,12) do set "OPT%%i=%OFF%"
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
call "%F%" SHOW_SELECTED

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