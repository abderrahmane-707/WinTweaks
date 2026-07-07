@echo off
setlocal enabledelayedexpansion
mode con cols=100 lines=30

:: Define basic variables
set "ON=(YES)"
set "OFF=(NO) "

:: Set default programs values - ALL OFF by default
set "OPT1=%OFF%"
set "OPT2=%OFF%"
set "OPT3=%OFF%"
set "OPT4=%OFF%"
set "OPT5=%OFF%"
set "OPT6=%OFF%"
set "OPT7=%OFF%"
set "OPT8=%OFF%"
set "OPT9=%OFF%"
set "OPT10=%OFF%"
set "OPT11=%OFF%"
set "OPT12=%OFF%"

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

:: Language: MatchOS, ar-sa, en-us
set "OPTL=MatchOS"

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
if "%OPTL%"=="MatchOS" set "LANG_MSG=MatchOS"
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
echo                   [A] Select All          [D] Deselect All             [X] Exit
echo.
echo              ---------------------------------------------------------------------------

echo. & echo Selected programs for %ARCH_MSG%:
call :SHOW_SELECTED

echo. & echo Tip: you can select multiple items, e.g. 1,3,5 or 1-5 or 1-3,7,10-12

set "choice=" & set /p "choice=--> Select an option(s) and press [S] to Start: "
if "%choice%"=="" goto OFFICE_MENU

:: Process single-key input
for /l %%i in (1,1,12) do (
    if "%choice%"=="%%i" (
        call :TOGGLE_SINGLE OPT%%i && goto OFFICE_MENU
    )
)

if /i "%choice%"=="V" call :TOGGLE_VERSION && goto OFFICE_MENU
if /i "%choice%"=="L" call :TOGGLE_LANGUAGE && goto OFFICE_MENU
if /i "%choice%"=="M" call :TOGGLE_SINGLE OPTM && goto OFFICE_MENU
if /i "%choice%"=="A" goto SELECT_ALL
if /i "%choice%"=="D" goto DESELECT_ALL
if /i "%choice%"=="S" goto CONTINUE
if /i "%choice%"=="X" exit /b

call :MULTI_INPUT
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
    call :IS_ON OPT%%i && set "HASSELECTION=%ON%"
)

if "!HASSELECTION!"=="%OFF%" (
    echo. & echo No programs was selected
    pause
    goto OFFICE_MENU
)

echo. & echo Selected programs:
call :SHOW_SELECTED

echo.
echo    Installation Architecture: %ARCH_MSG%
echo    Installation Version: %OPTV%
echo    Language: %LANG_MSG%
echo    Installation Mode: %MOD_MSG%

call :CHOICE "Do you want to start?"
if errorlevel 2 goto OFFICE_MENU

:: Process based on installation mode and offline files status
if "%OPTM%,%OFILES%"=="%OFF%,%OFF%" goto DOWNLOAD_FILES
if "%OPTM%,%OFILES%"=="%OFF%,%ON%" goto DELETE_FILES
if "%OPTM%,%OFILES%"=="%ON%,%ON%" goto OFFLINE_INSTALL
if "%OPTM%,%OFILES%"=="%ON%,%OFF%" goto ONLINE_INSTALL

:DOWNLOAD_FILES
echo Downloading Office files
call :CONFIG
echo. & echo Downloading Microsoft Office %OPTV% %CPU%-bit
"Files\Programs\setup.exe" /download "%CONFIG_FILE%"
if errorlevel 1 (
    echo. & echo Download failed with exit code !errorlevel!
)

call :DEL_CONFIG
goto :EXIT

:DELETE_FILES
echo. & echo Deleting Microsoft Office Installation Files
rd /s /q "Files\Programs\Office" >nul 2>&1
if exist "Files\Programs\Office" (
    echo Could not delete offline files
)
pause
goto OFFICE_MENU

:OFFLINE_INSTALL
echo. & echo Installing Microsoft Office from offline files
call :CONFIG
"Files\Programs\setup.exe" /configure "%CONFIG_FILE%"
if errorlevel 1 (
    echo. & echo Installation failed with exit code !errorlevel!
    call :DEL_CONFIG
    goto :EXIT
)
goto END

:ONLINE_INSTALL
call :CONFIG
echo. & echo Installing Microsoft Office (Online)
"Files\Programs\setup.exe" /configure "%CONFIG_FILE%"
if errorlevel 1 (
    echo. & echo Installation failed with exit code !errorlevel!
    call :DEL_CONFIG
    goto :EXIT
)
goto END

:END
call :DEL_CONFIG
echo. & echo Disabling Microsoft Office Telemetry
reg add "HKLM\SOFTWARE\Microsoft\Office\Common\ClientTelemetry" /v "DisableTelemetry" /t REG_DWORD /d "00000001" /f >nul 2>&1

call :CHOICE "Do you want to activate Microsoft Office?"
if !errorlevel! equ 1 (
    echo. & echo Launching Microsoft Activation Script (MAS) to activate Windows and Office
    echo The script will open in a new window. Follow the on-screen instructions
    powershell -NoP -EP Bypass -c "irm https://get.activated.win | iex"
)

echo. & echo The operation is done.
goto :EXIT

:EXIT
pause
exit /b


:: ----------------------------------------------------------------< FUNCTIONS >----------------------------------------------------------------
:SHOW_SELECTED
set "ANY=0"
if "!OPT1!"=="%ON%"  echo  - Word & set "ANY=1"
if "!OPT2!"=="%ON%"  echo  - Excel & set "ANY=1"
if "!OPT3!"=="%ON%"  echo  - PowerPoint & set "ANY=1"
if "!OPT4!"=="%ON%"  echo  - Outlook & set "ANY=1"
if "!OPT5!"=="%ON%"  echo  - OneNote & set "ANY=1"
if "!OPT6!"=="%ON%"  echo  - Publisher & set "ANY=1"
if "!OPT7!"=="%ON%"  echo  - Access & set "ANY=1"
if "!OPT8!"=="%ON%"  echo  - Visio & set "ANY=1"
if "!OPT9!"=="%ON%"  echo  - Project & set "ANY=1"
if "!OPT10!"=="%ON%" echo  - Proofing Tools & set "ANY=1"
if "!OPT11!"=="%ON%" echo  - Microsoft Teams & set "ANY=1"
if "!OPT12!"=="%ON%" echo  - Microsoft OneDrive & set "ANY=1"
if "!ANY!"=="0" echo  - No program selected
goto :eof

:MULTI_INPUT
set "invalid="
set "tokens=%choice:,= %"
for %%G in (%tokens%) do (
    set "tok=%%G"
    set "matched=0"

    set "noHyphen=!tok:-=!"

    if not "!tok!"=="!noHyphen!" (
        for /f "tokens=1,2 delims=-" %%X in ("!tok!") do (
            set "rangeStart=%%X"
            set "rangeEnd=%%Y"
        )
        set "isNum1=1" & for /f "delims=0123456789" %%C in ("!rangeStart!") do set "isNum1=0"
        set "isNum2=1" & for /f "delims=0123456789" %%C in ("!rangeEnd!") do set "isNum2=0"

        if defined rangeStart if defined rangeEnd if "!isNum1!!isNum2!"=="11" (
            if !rangeStart! geq 1 if !rangeEnd! leq 12 if !rangeStart! leq !rangeEnd! (
                for /L %%N in (!rangeStart!,1,!rangeEnd!) do call :TOGGLE_SINGLE OPT%%N
                set "matched=1"
            )
        )
    ) else (
        set "isNum=1" & for /f "delims=0123456789" %%C in ("!tok!") do set "isNum=0"
        if "!isNum!"=="1" if defined tok (
            if !tok! geq 1 if !tok! leq 12 (
                call :TOGGLE_SINGLE OPT!tok!
                set "matched=1"
            )
        )
    )

    if "!matched!"=="0" set "invalid=!invalid! !tok!"
)

if defined invalid (
    echo. & echo Invalid or out-of-range input ignored:!invalid!
    pause
)
goto :eof

:TOGGLE_SINGLE
if "!%1!"=="%ON%" (
    set "%1=%OFF%"
) else (
    set "%1=%ON%"
)
goto :eof

:IS_ON
if "!%1!"=="%ON%" exit /b 0
exit /b 1

:TOGGLE_VERSION
if "%OPTV%"=="365" (set "OPTV=2021") else if "%OPTV%"=="2021" (set "OPTV=2019") else if "%OPTV%"=="2019" (set "OPTV=2016") else (set "OPTV=365")
goto :eof

:TOGGLE_LANGUAGE
if "%OPTL%"=="MatchOS" (set "OPTL=ar-sa") else if "%OPTL%"=="ar-sa" (set "OPTL=en-us") else (set "OPTL=MatchOS")
goto :eof

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

    if "%OPTL%"=="MatchOS" (
        echo        ^<Language ID="MatchOS" Fallback="en-us" /^> >> "%CONFIG_FILE%"
    ) else if "%OPTL%"=="ar-sa" (
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
    if "%OPTL%"=="MatchOS" (
        echo        ^<Language ID="MatchOS" Fallback="en-us" /^> >> "%CONFIG_FILE%"
    ) else if "%OPTL%"=="ar-sa" (
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
    if "%OPTL%"=="MatchOS" (
        echo        ^<Language ID="MatchOS" Fallback="en-us" /^> >> "%CONFIG_FILE%"
    ) else if "%OPTL%"=="ar-sa" (
        echo        ^<Language ID="ar-sa" /^> >> "%CONFIG_FILE%"
    ) else if "%OPTL%"=="en-us" (
        echo        ^<Language ID="en-us" /^> >> "%CONFIG_FILE%"
    )
    echo        ^<ExcludeApp ID="Bing" /^> >> "%CONFIG_FILE%"
    echo      ^</Product^> >> "%CONFIG_FILE%"
)

if "%OPT10%"=="%ON%" (
    echo      ^<Product ID="ProofingTools"^> >> "%CONFIG_FILE%"
    if "%OPTL%"=="MatchOS" (
        echo        ^<Language ID="MatchOS" Fallback="en-us" /^> >> "%CONFIG_FILE%"
    ) else if "%OPTL%"=="ar-sa" (
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
echo ^</Configuration^> >> "%CONFIG_FILE%"

if not exist "%CONFIG_FILE%" (
    echo Failed to create configuration file!
    goto :EXIT
)
goto :eof

:DEL_CONFIG
del /f /q "%CONFIG_FILE%" >nul 2>&1
goto :eof

:CHOICE
echo. & choice /C YN /N /M "%~1 (Y/N): "
goto :eof