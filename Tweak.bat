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
if "%choice%"=="1" goto PERFORMANCE_MENU
if "%choice%"=="2" goto PRIVACY_SECURITY_MENU
if "%choice%"=="3" goto NETWORK_MENU
if "%choice%"=="4" goto PROGRAMS_MANAGER_MENU
if "%choice%"=="5" goto CUSTOMIZATION_MENU
if "%choice%"=="6" goto SYSTEM_MENU
if "%choice%"=="7" goto TOOLS_MENU
if "%choice%"=="8" goto OTHER_MENU
if "%choice%"=="0" exit

call "%F%" INVALID "(0-8)" & goto MAIN_MENU

:PERFORMANCE_MENU
call "Files\Performance\PerformanceMenu.bat"
if %errorlevel%==99 goto MAIN_MENU

:PRIVACY_SECURITY_MENU
call "Files\Security\PrivacySecurityMenu.bat"
if %errorlevel%==99 goto MAIN_MENU

:NETWORK_MENU
call "Files\Network\NetworkMenu.bat"
if %errorlevel%==99 goto MAIN_MENU

:PROGRAMS_MANAGER_MENU
call "Files\Programs\ProgramsMenu.bat"
if %errorlevel%==99 goto MAIN_MENU

:CUSTOMIZATION_MENU
call "Files\Customization\CustomizationMenu.bat"
if %errorlevel%==99 goto MAIN_MENU

:SYSTEM_MENU
call "Files\System\SystemMenu.bat"
if %errorlevel%==99 goto MAIN_MENU

:TOOLS_MENU
call "Files\Tools\ToolsMenu.bat"
if %errorlevel%==99 goto MAIN_MENU

:OTHER_MENU
call "Files\Other\OtherMenu.bat"
if %errorlevel%==99 goto MAIN_MENU
