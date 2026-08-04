@echo off
setlocal enabledelayedexpansion
title WinTweaks

:: Check for administrator privileges
fltmc >nul 2>&1
if errorlevel 1 (
    echo This script must be run with Administrator privileges
    pause & exit /b 1
)

:: Go to script's directory
cd /d "%~dp0"

:: Defined of a functions file
set "F=Files\Common\Functions.bat"

:: WinTweaks Script main menu
:MAIN_MENU
cls
echo.
echo                                                           \\!//
echo                                                           (o o)
echo                        -------------------------------oOOo-(_)-oOOo-------------------------------
echo.
echo                            [1] Performance                                        [2] Security
echo.
echo                            [3] Network                                            [4] Programs
echo.
echo                            [5] Customization                                      [6] System
echo.
echo                            [7] Tools                                              [8] Other
echo.
echo                                                          [0] Exit
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "!choice!"=="1" call "Files\Performance\PerformanceMenu.bat" & goto MAIN_MENU
if "!choice!"=="2" call "Files\Security\PrivacySecurityMenu.bat" & goto MAIN_MENU
if "!choice!"=="3" call "Files\Network\NetworkMenu.bat" & goto MAIN_MENU
if "!choice!"=="4" call "Files\Programs\ProgramsMenu.bat" & goto MAIN_MENU
if "!choice!"=="5" call "Files\Customization\CustomizationMenu.bat" & goto MAIN_MENU
if "!choice!"=="6" call "Files\System\SystemMenu.bat" & goto MAIN_MENU
if "!choice!"=="7" call "Files\Tools\ToolsMenu.bat" & goto MAIN_MENU
if "!choice!"=="8" call "Files\Other\OtherMenu.bat" & goto MAIN_MENU
if "%choice%"=="0" exit

call "%F%" INVALID "(0-8)" & goto MAIN_MENU
