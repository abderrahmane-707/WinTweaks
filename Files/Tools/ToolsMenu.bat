:TOOLS_MENU
cls & echo. & echo.
echo                        ---------------------------------- Tools ----------------------------------
echo.
echo                          [1] SFC Scan                                            [2] DISM Tools
echo.  
echo                          [3] Defragment Drive                                    [4] Check Disk 
echo. 
echo                          [5] Memory Diagnostic                                   [6] Disk Cleanup
echo.
echo                          [7] Delete Script Data                                  [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto SFC_SCAN
if "%choice%"=="2" goto DISM_MENU
if "%choice%"=="3" goto DEFRAG
if "%choice%"=="4" goto CHKDSK
if "%choice%"=="5" goto MEMORY_DIAG
if "%choice%"=="6" goto CLEAN_MGR
if "%choice%"=="7" goto DELETE_SCRIPT_DATA
if "%choice%"=="0" exit /b 99

call "%F%" INVALID "(0-7)" & goto TOOLS_MENU

:: Scan and verify the integrity of all protected system files and repair corrupted
:SFC_SCAN
cls & echo Running sfc scan
sfc /scannow
call "%F%" GO & goto TOOLS_MENU

:DISM_MENU
cls & echo. & echo.
echo                        ------------------------------- DISM Tools --------------------------------
echo.
echo                           [1] Fast Check                                     [2] Deep Check
echo.                    
echo                           [3] Fix Corruption                                 [4] Component Cleanup
echo.
echo                                                         [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: " 
if "%choice%"=="1" goto DISM_CHECK_HEALTH
if "%choice%"=="2" goto DISM_SCAN_HEALTH
if "%choice%"=="3" goto DISM_RESTORE_HEALTH
if "%choice%"=="4" goto DISM_COMPONENT_CLEANUP
if "%choice%"=="0" goto TOOLS_MENU

call "%F%" INVALID "(0-4)" & goto DISM_MENU

:: Perform a quick check to see if the OS has already flagged any corruption
:DISM_CHECK_HEALTH
cls & echo Performing quick health check of Windows image
dism /Online /Cleanup-Image /CheckHealth
call "%F%" GO & goto DISM_MENU

:: This does not fix errors, it only reports them
:DISM_SCAN_HEALTH
cls & echo Performing deep scan of Windows image
dism /Online /Cleanup-Image /ScanHealth
call "%F%" GO & goto DISM_MENU

:: Repair the Windows Image by downloading healthy files from Windows Update
:DISM_RESTORE_HEALTH
cls & echo Fix Windows component
dism /Online /Cleanup-Image /RestoreHealth
call "%F%" GO & goto DISM_MENU

:: Clean up the WinSxS folder by removing superseded (old) versions of components
:DISM_COMPONENT_CLEANUP
call "%F%" CONFIRM "WARNING: This will permanently remove rollback capability for Windows Updates"
if errorlevel 2 goto DISM_MENU

echo Cleaning Windows components
dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase
call "%F%" GO & goto DISM_MENU

:: Launch Windows Defragment
:DEFRAG
start "" dfrgui.exe
goto TOOLS_MENU

:CHKDSK
cls & echo Available drives on your system:

:: List all existing drive letters
for %%d in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist %%d:\ echo %%d:\
)

echo. & echo Enter drive letter to check
echo Enter "0" to go back

set "drive=" & set /p "drive= "
if "%drive%"=="0" goto TOOLS_MENU

:: Handle empty input
if not defined drive goto CHKDSK

:: Remove quotes if present
set "drive=%drive:"=%"

:: Trim to first character only
set "drive=%drive:~0,1%"

:: Validate that the drive exists
if not exist "%drive%:\" (
    echo. & echo Invalid drive letter: %drive%
    pause
    goto CHKDSK
)

:: Convert to uppercase
for %%c in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do if /i "%drive%"=="%%c" set "drive=%%c"

:CHKDSK_MENU
cls & echo. & echo.
echo                        --------------------------------- CHKDSK ----------------------------------
echo.
echo                          [1] Check Status                                    [2] Fix File System
echo.
echo                          [3] Fix Bad Sectors                                 [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option for %drive%\: drive: "
if "%choice%"=="1" goto DISK_STATUS 
if "%choice%"=="2" goto FIX_FILE
if "%choice%"=="3" goto FIX_SECTORS
if "%choice%"=="0" goto CHKDSK

call "%F%" INVALID "(0-3)" & goto CHKDSK_MENU

:: Scans for errors but does not fix anything
:DISK_STATUS
cls & echo Running read-only CHKDSK on drive %drive%:\ to check for errors
timeout /t 2 >nul
chkdsk %drive%:
call "%F%" GO & goto CHKDSK_MENU

:FIX_FILE
cls & echo Running CHKDSK with /f option on drive %drive%:\ to fix file system errors
timeout /t 2 >nul

:: /f: Fixes errors on the disk
chkdsk %drive%: /f
call "%F%" GO & goto CHKDSK_MENU

:FIX_SECTORS
cls & echo Running CHKDSK with /r option on drive %drive%:\ to find bad sectors and recover data
timeout /t 2 >nul

:: /r: Locates bad sectors and recovers readable information
chkdsk %drive%: /r
call "%F%" GO & goto CHKDSK_MENU

:: Launch Memory Diagnostic
:MEMORY_DIAG
start "" mdsched.exe
goto TOOLS_MENU

:: Launch Disk Cleanup
:CLEAN_MGR
cleanmgr.exe /d %SYSTEMDRIVE% /VERYLOWDISK
goto TOOLS_MENU

:: Delete "%PROGRAMDATA%\WinTweaks" folder
:DELETE_SCRIPT_DATA
set "MKDIR_DIR=%PROGRAMDATA%\WinTweaks"
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Tools\DeleteScriptData.ps1" "%MKDIR_DIR%"
call "%F%" GO & goto TOOLS_MENU