@echo off
setlocal enabledelayedexpansion
mode con: cols=100 lines=30

:: Define basic variables
set "on=(YES)"
set "off=(NO) "

:: Set default application values - ALL OFF by default
set "opt1=%off%"
set "opt2=%off%"
set "opt3=%off%"
set "opt4=%off%"
set "opt5=%off%"
set "opt6=%off%"
set "opt7=%off%"
set "opt8=%off%"
set "opt9=%off%"
set "optP=%off%"
set "optT=%off%"
set "optD=%off%"

:: Determine processor architecture automatically
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set "CPU=64"
    set "ARCH_MESSAGE=64-bit"
) else if "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
    set "CPU=64"
    set "ARCH_MESSAGE=64-bit (ARM64)"
) else (
    set "CPU=32"
    set "ARCH_MESSAGE=32-bit"
)

:: Additional check for 64-bit OS running 32-bit cmd
if "%PROCESSOR_ARCHITEW6432%"=="AMD64" (
    set "CPU=64"
    set "ARCH_MESSAGE=64-bit (Auto-detected from 64-bit OS)"
)

:: Set default Office version
set "optV=2021"
set "optM=%on%"  :: Installation Mode: %on%=Online, %off%=Offline
set "optL=MatchOS"  :: Language: MatchOS, ar-sa, en-us

:: Set configuration file path
set "CONFIG_FILE=Files\Programs\configuration.xml"

:: Main interface
:MENU
cls
echo.
echo                                                \\!//
echo                                                (o o)
echo             -------------------------------oOOo-(_)-oOOo-------------------------------
echo                                  Microsoft Office Installation Tool
echo             ---------------------------------------------------------------------------
echo.

:: Check for offline files
if exist "Files\Programs\Office\Data\stream*.dat" (
    set "OFiles=%on%"
) else (
    set "OFiles=%off%"
)

:: Set Office version message with switch instruction
if "%optV%"=="365" set "VMessage=Office 365"
if "%optV%"=="2021" set "VMessage=Office 2021"
if "%optV%"=="2019" set "VMessage=Office 2019"
if "%optV%"=="2016" set "VMessage=Office 2016"

:: Set installation mode message with switch instruction
if "%optM%,%OFiles%"=="%on%,%off%" set "MMessage=Online Installation"
if "%optM%,%OFiles%"=="%off%,%off%" set "MMessage=Download Offline Files"
if "%optM%,%OFiles%"=="%off%,%on%" set "MMessage=Delete Offline Files"
if "%optM%,%OFiles%"=="%on%,%on%" set "MMessage=Offline Installation"

:: Set language message with switch instruction
if "%optL%"=="MatchOS" set "LMessage=MatchOS"
if "%optL%"=="ar-sa" set "LMessage=ar-sa"
if "%optL%"=="en-us" set "LMessage=en-us"

:: Display application options
echo                 [1] Word                 [5] OneNote             [9] Project
echo                 [2] Excel                [6] Publisher           [10] Proofing Tools
echo                 [3] PowerPoint           [7] Access              [11] Teams
echo                 [4] Outlook              [8] Visio               [12] OneDrive
echo.
echo    [V] Version:  %VMessage%
echo    [L] Language: %LMessage%
echo    [M] Mode:     %MMessage%
echo.
echo                   [S] Start                                  [X] Exit
echo.
echo     ---------------------------------------------------------------------------
echo     Selected Applications for %ARCH_MESSAGE%:
call :ShowSelected
echo     ---------------------------------------------------------------------------

:: Use SET /P instead of CHOICE for better control
set "user_input="
set /p "user_input=--> Select an option(s) and press [S] to Start: "

if "%user_input%"=="" goto MENU

:: Process user input
if /i "%user_input%"=="1" call :ToggleSingle "opt1" && goto MENU
if /i "%user_input%"=="2" call :ToggleSingle "opt2" && goto MENU
if /i "%user_input%"=="3" call :ToggleSingle "opt3" && goto MENU
if /i "%user_input%"=="4" call :ToggleSingle "opt4" && goto MENU
if /i "%user_input%"=="5" call :ToggleSingle "opt5" && goto MENU
if /i "%user_input%"=="6" call :ToggleSingle "opt6" && goto MENU
if /i "%user_input%"=="7" call :ToggleSingle "opt7" && goto MENU
if /i "%user_input%"=="8" call :ToggleSingle "opt8" && goto MENU
if /i "%user_input%"=="9" call :ToggleSingle "opt9" && goto MENU
if /i "%user_input%"=="10" call :ToggleSingle "optP" && goto MENU
if /i "%user_input%"=="11" call :ToggleSingle "optT" && goto MENU
if /i "%user_input%"=="12" call :ToggleSingle "optD" && goto MENU
if /i "%user_input%"=="V" call :ToggleVersion && goto MENU
if /i "%user_input%"=="L" call :ToggleLanguage && goto MENU
if /i "%user_input%"=="M" call :ToggleSingle "optM" && goto MENU
if /i "%user_input%"=="S" goto CONTINUE
if /i "%user_input%"=="X" exit /b
goto MENU

:: Continue installation
:CONTINUE
cls
echo. & echo Selected Applications:
if "%opt1%"=="%on%" echo   - Word
if "%opt2%"=="%on%" echo   - Excel
if "%opt3%"=="%on%" echo   - PowerPoint
if "%opt4%"=="%on%" echo   - Outlook
if "%opt5%"=="%on%" echo   - OneNote
if "%opt6%"=="%on%" echo   - Publisher
if "%opt7%"=="%on%" echo   - Access
if "%opt8%"=="%on%" echo   - Visio
if "%opt9%"=="%on%" echo   - Project
if "%optP%"=="%on%" echo   - Proofing Tools
if "%optT%"=="%on%" echo   - Teams
if "%optD%"=="%on%" echo   - OneDrive
echo.
echo    Installation Architecture: %ARCH_MESSAGE%
echo    Installation Version: %optV%
echo    Language: %LMessage%
echo    Installation Mode: %MMessage%

:: Check if at least one application is selected
set "hasSelection=%off%"
for %%O in ("%opt1%" "%opt2%" "%opt3%" "%opt4%" "%opt5%" "%opt6%" "%opt7%" "%opt8%" "%opt9%" "%optP%" "%optT%" "%optD%") do (
    if "%%~O"=="%on%" set "hasSelection=%on%"
)

if "%hasSelection%"=="%off%" (
    echo No applications were selected! Please select at least one application.
    pause
    goto MENU
)

:: Process based on installation mode and offline files status
if "%optM%,%OFiles%"=="%off%,%off%" goto DOWNLOAD_FILES
if "%optM%,%OFiles%"=="%off%,%on%" goto DELETE_FILES
if "%optM%,%OFiles%"=="%on%,%on%" goto OFFLINE_INSTALL
if "%optM%,%OFiles%"=="%on%,%off%" goto ONLINE_INSTALL

:DOWNLOAD_FILES
echo Downloading Office files... 
echo This may take 10-30 minutes depending on your internet speed
call :CONFIG
echo. & echo Downloading Microsoft Office %optV% %CPU%-bit
"Files\Programs\setup.exe" /download "%CONFIG_FILE%"
goto END

:DELETE_FILES
echo. & echo Deleting Microsoft Office Installation Files
rd /s /q ".\Office" >nul 2>&1
goto MENU

:OFFLINE_INSTALL
echo. & echo Installing Microsoft Office %optV% %CPU%-bit from offline files
call :CONFIG
"Files\Programs\setup.exe" /configure "%CONFIG_FILE%"
echo.& echo done
timeout /t 2 >nul
exit

:ONLINE_INSTALL
call :CONFIG
echo. & echo Installing Microsoft Office %optV% %CPU%-bit (Online)
pause
"Files\Programs\setup.exe" /configure "%CONFIG_FILE%"

:POST_INSTALL
echo. & echo Disabling Microsoft Office Telemetry
reg add "HKLM\SOFTWARE\Microsoft\Office\Common\ClientTelemetry" /v "DisableTelemetry" /t REG_DWORD /d "00000001" /f >nul 2>&1
goto END

:ShowSelected
set "any=0"
if "!opt1!"=="%on%"  echo   - Word & set "any=1"
if "!opt2!"=="%on%"  echo   - Excel & set "any=1"
if "!opt3!"=="%on%"  echo   - PowerPoint & set "any=1"
if "!opt4!"=="%on%"  echo   - Outlook & set "any=1"
if "!opt5!"=="%on%"  echo   - OneNote & set "any=1"
if "!opt6!"=="%on%"  echo   - Publisher & set "any=1"
if "!opt7!"=="%on%"  echo   - Access & set "any=1"
if "!opt8!"=="%on%"  echo   - Visio & set "any=1"
if "!opt9!"=="%on%"  echo   - Project & set "any=1"
if "!optP!"=="%on%"  echo   - Proofing Tools & set "any=1"
if "!optT!"=="%on%"  echo   - Microsoft Teams & set "any=1"
if "!optD!"=="%on%"  echo   - Microsoft OneDrive & set "any=1"
if "!any!"=="0" echo   No applications selected
exit /b

:ToggleSingle
set "var=%~1"
call set "value=%%%var%%%"
if "%value%"=="%on%" (
    set "%var%=%off%"
) else (
    set "%var%=%on%"
)
goto :eof

:ToggleVersion
if "%optV%"=="365" (set "optV=2021") else if "%optV%"=="2021" (set "optV=2019") else if "%optV%"=="2019" (set "optV=2016") else (set "optV=365")
goto :eof

:ToggleLanguage
if "%optL%"=="MatchOS" (set "optL=ar-sa") else if "%optL%"=="ar-sa" (set "optL=en-us") else (set "optL=MatchOS")
goto :eof

:CONFIG
echo. & echo Creating Configuration File for Microsoft Office %optV%
del "%CONFIG_FILE%" >nul 2>&1

:: Start Configuration
echo ^<?xml version="1.0" encoding="utf-8"?^> > "%CONFIG_FILE%"
echo ^<Configuration^> >> "%CONFIG_FILE%"

:: Add Section with proper attributes
if "%optV%"=="365" (
    echo   ^<Add OfficeClientEdition="%CPU%" Channel="Current" MigrateArch="TRUE"^> >> "%CONFIG_FILE%"
) else if "%optV%"=="2019" (
    echo   ^<Add OfficeClientEdition="%CPU%" Channel="PerpetualVL2019" MigrateArch="TRUE"^> >> "%CONFIG_FILE%"
) else if "%optV%"=="2016" (
    echo   ^<Add OfficeClientEdition="%CPU%" Channel="PerpetualVL2016" MigrateArch="TRUE"^> >> "%CONFIG_FILE%"
) else if "%optV%"=="2021" (
    echo   ^<Add OfficeClientEdition="%CPU%" Channel="PerpetualVL2021" MigrateArch="TRUE"^> >> "%CONFIG_FILE%"
)

:: Main Office Product
if "%optV%"=="365" (
    echo     ^<Product ID="O365ProPlusRetail"^> >> "%CONFIG_FILE%"
) else if "%optV%"=="2019" (
    echo     ^<Product ID="ProPlus2019Volume"^> >> "%CONFIG_FILE%"
) else if "%optV%"=="2016" (
    echo     ^<Product ID="ProPlusRetail"^> >> "%CONFIG_FILE%"
) else if "%optV%"=="2021" (
    echo     ^<Product ID="ProPlus2021Volume"^> >> "%CONFIG_FILE%"
)

:: Set language based on selection
if "%optL%"=="MatchOS" (
    echo       ^<Language ID="MatchOS" Fallback="en-us" /^> >> "%CONFIG_FILE%"
) else if "%optL%"=="ar-sa" (
    echo       ^<Language ID="ar-sa" /^> >> "%CONFIG_FILE%"
) else if "%optL%"=="en-us" (
    echo       ^<Language ID="en-us" /^> >> "%CONFIG_FILE%"
)

:: Always exclude these apps
echo       ^<ExcludeApp ID="Lync" /^> >> "%CONFIG_FILE%"
echo       ^<ExcludeApp ID="Groove" /^> >> "%CONFIG_FILE%"
echo       ^<ExcludeApp ID="Bing" /^> >> "%CONFIG_FILE%"

:: Exclude user-selected apps
if "%opt1%"=="%off%" echo       ^<ExcludeApp ID="Word" /^> >> "%CONFIG_FILE%"
if "%opt2%"=="%off%" echo       ^<ExcludeApp ID="Excel" /^> >> "%CONFIG_FILE%"
if "%opt3%"=="%off%" echo       ^<ExcludeApp ID="PowerPoint" /^> >> "%CONFIG_FILE%"
if "%opt4%"=="%off%" echo       ^<ExcludeApp ID="Outlook" /^> >> "%CONFIG_FILE%"
if "%opt5%"=="%off%" echo       ^<ExcludeApp ID="OneNote" /^> >> "%CONFIG_FILE%"
if "%opt6%"=="%off%" echo       ^<ExcludeApp ID="Publisher" /^> >> "%CONFIG_FILE%"
if "%opt7%"=="%off%" echo       ^<ExcludeApp ID="Access" /^> >> "%CONFIG_FILE%"
if "%optT%"=="%off%" echo       ^<ExcludeApp ID="Teams" /^> >> "%CONFIG_FILE%"
if "%optD%"=="%off%" echo       ^<ExcludeApp ID="OneDrive" /^> >> "%CONFIG_FILE%"

echo     ^</Product^> >> "%CONFIG_FILE%"

:: Add Visio if selected
if "%opt8%"=="%on%" (
    if "%optV%"=="365" (
        echo     ^<Product ID="VisioProRetail"^> >> "%CONFIG_FILE%"
    ) else if "%optV%"=="2019" (
        echo     ^<Product ID="VisioPro2019Volume"^> >> "%CONFIG_FILE%"
    ) else if "%optV%"=="2016" (
        echo     ^<Product ID="VisioPro2016Volume"^> >> "%CONFIG_FILE%"
    ) else if "%optV%"=="2021" (
        echo     ^<Product ID="VisioPro2021Volume"^> >> "%CONFIG_FILE%"
    )
    :: Set language for Visio
    if "%optL%"=="MatchOS" (
        echo       ^<Language ID="MatchOS" Fallback="en-us" /^> >> "%CONFIG_FILE%"
    ) else if "%optL%"=="ar-sa" (
        echo       ^<Language ID="ar-sa" /^> >> "%CONFIG_FILE%"
    ) else if "%optL%"=="en-us" (
        echo       ^<Language ID="en-us" /^> >> "%CONFIG_FILE%"
    )
    echo       ^<ExcludeApp ID="Bing" /^> >> "%CONFIG_FILE%"
    echo     ^</Product^> >> "%CONFIG_FILE%"
)

:: Add Project if selected
if "%opt9%"=="%on%" (
    if "%optV%"=="365" (
        echo     ^<Product ID="ProjectProRetail"^> >> "%CONFIG_FILE%"
    ) else if "%optV%"=="2019" (
        echo     ^<Product ID="ProjectPro2019Volume"^> >> "%CONFIG_FILE%"
    ) else if "%optV%"=="2016" (
        echo     ^<Product ID="ProjectPro2016Volume"^> >> "%CONFIG_FILE%"
    ) else if "%optV%"=="2021" (
        echo     ^<Product ID="ProjectPro2021Volume"^> >> "%CONFIG_FILE%"
    )
    :: Set language for Project
    if "%optL%"=="MatchOS" (
        echo       ^<Language ID="MatchOS" Fallback="en-us" /^> >> "%CONFIG_FILE%"
    ) else if "%optL%"=="ar-sa" (
        echo       ^<Language ID="ar-sa" /^> >> "%CONFIG_FILE%"
    ) else if "%optL%"=="en-us" (
        echo       ^<Language ID="en-us" /^> >> "%CONFIG_FILE%"
    )
    echo       ^<ExcludeApp ID="Bing" /^> >> "%CONFIG_FILE%"
    echo     ^</Product^> >> "%CONFIG_FILE%"
)

:: Add Proofing Tools if selected
if "%optP%"=="%on%" (
    echo     ^<Product ID="ProofingTools"^> >> "%CONFIG_FILE%"
    :: Set language for Proofing Tools
    if "%optL%"=="MatchOS" (
        echo       ^<Language ID="MatchOS" Fallback="en-us" /^> >> "%CONFIG_FILE%"
    ) else if "%optL%"=="ar-sa" (
        echo       ^<Language ID="ar-sa" /^> >> "%CONFIG_FILE%"
    ) else if "%optL%"=="en-us" (
        echo       ^<Language ID="en-us" /^> >> "%CONFIG_FILE%"
    )
    echo       ^<ExcludeApp ID="Bing" /^> >> "%CONFIG_FILE%"
    echo     ^</Product^> >> "%CONFIG_FILE%"
)

:: Close Add section
echo   ^</Add^> >> "%CONFIG_FILE%"

:: Updates section
echo   ^<Updates Enabled="FALSE" /^> >> "%CONFIG_FILE%"

:: Display section
echo   ^<Display Level="Full" AcceptEULA="TRUE" /^> >> "%CONFIG_FILE%"

:: Properties section
echo   ^<Property Name="ForceAppShutdown" Value="TRUE" /^> >> "%CONFIG_FILE%"

:: AppSettings section
echo   ^<AppSettings^> >> "%CONFIG_FILE%"
echo     ^<User Key="software\microsoft\office\16.0\word\options" Name="defaultformat" Value="" Type="REG_SZ" App="word16" Id="L_SaveWordfilesas" /^> >> "%CONFIG_FILE%"
echo     ^<User Key="software\microsoft\office\16.0\excel\options" Name="defaultformat" Value="51" Type="REG_DWORD" App="excel16" Id="L_SaveExcelfilesas" /^> >> "%CONFIG_FILE%"
echo     ^<User Key="software\microsoft\office\16.0\powerpoint\options" Name="defaultformat" Value="27" Type="REG_DWORD" App="ppt16" Id="L_SavePowerPointfilesas" /^> >> "%CONFIG_FILE%"
echo   ^</AppSettings^> >> "%CONFIG_FILE%"

:: Close Configuration
echo ^</Configuration^> >> "%CONFIG_FILE%"

:: Verify the file was created
if not exist "%CONFIG_FILE%" (
    echo ERROR: Failed to create configuration file!
    pause
    goto MENU
)
goto :eof

:END
del /f /q "%CONFIG_FILE%" >nul
choice /C YN /N /M "Do you want to activate Microsoft Office? (Y/N): "
if errorlevel 2 exit /b
powershell -NoP -EP Bypass -c "irm https://get.activated.win | iex"
exit /b