:SYSTEM_MENU
cls & echo. & echo.
echo                        --------------------------------- System ----------------------------------
echo.
echo                          [1] Restore Point                                   [2] Registry Backup
echo.
echo                          [3] Activation                                      [4] System Info
echo.
echo                                                         [0] Back
echo.  
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto RESTORE_POINT
if "%choice%"=="2" goto REG_BACK
if "%choice%"=="3" goto ACTIVATION_MENU
if "%choice%"=="4" (call "%F%" INFO_SCRIPT "System" "SystemInfo"  & goto SYSTEM_MENU)
if "%choice%"=="0" exit /b

call "%F%" INVALID "(0-4)" & goto SYSTEM_MENU

:RESTORE_POINT
:: RestorePointType: MODIFY_SETTINGS indicates settings were changed
cls & echo Creating a System Restore Point
powershell -Command "Checkpoint-Computer -Description 'WinTweaks Restore Point' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop"
if %errorlevel% equ 0 (call "%F%" GO & goto SYSTEM_MENU)

call "%F%" PATH_DIR "System" "RestorePoint"

:: If Creating failed (errorlevel>0)
echo Creating a restore point failed. Attempting to fix system dependencies

echo Enable System Restore on the C: drive
powershell -Command "Enable-ComputerRestore -Drive 'C:\'" >> "%LOG_FILE%" 2>&1

:: Enable System Restore via registry if they were disabled by policy
echo. & echo Enabling System Restore via registry
reg import "Files\System\EnableRestorePoint.reg" >> "%LOG_FILE%" 2>&1

echo Stopping restore point services

:: VSS:      Volume Shadow Copy Service (Manages data backup/snapshots)
:: swprv:    Microsoft Software Shadow Copy Provider (Coordinates snapshot creation)
for %%S in ("VSS" "swprv") do call "%F%" NET_CONTROL "%%S" "stop" >> "%LOG_FILE%" 2>&1

echo Re-registering VSS-related system libraries
for %%D in (ole32.dll oleaut32.dll vss_ps.dll stdprov.dll vssui.dll) do (
    regsvr32 /s "%windir%\System32\%%D" >> "%LOG_FILE%" 2>&1
)

for %%D in (swprv.dll eventcls.dll) do (
    regsvr32 /s /i "%windir%\System32\%%D" >> "%LOG_FILE%" 2>&1
)

echo Registering VSS Service
vssvc /register  >> "%LOG_FILE%" 2>&1

echo Starting restore point services
for %%S in ("VSS" "swprv") do (
    call "%F%" SC_CONFIGURE "%%S" "demand" >> "%LOG_FILE%" 2>&1
    call "%F%" NET_CONTROL "%%S" "start" >> "%LOG_FILE%" 2>&1
)

:: RpcSs:         Remote Procedure Call (RPC) Service (Manages inter-process communication)
:: EventLog:      Windows Event Log Service (Records system, security, and application events)
:: EventSystem:   COM+ Event System (Distributes system events to subscribed components)
:: Schedule:      Task Scheduler Service (Manages scheduled tasks, including automatic restore point creation)
for %%S in ("RpcSs" "CryptSvc" "EventLog" "EventSystem" "Schedule") do (
    call "%F%" SC_CONFIGURE "%%S" "auto" >> "%LOG_FILE%" 2>&1
    call "%F%" NET_CONTROL "%%S" "start" >> "%LOG_FILE%" 2>&1
)

echo Checking VSS Writers status
vssadmin list writers >> "%LOG_FILE%" 2>&1

echo Attempting to create System Restore Point again
powershell -Command "Checkpoint-Computer -Description 'WinTweaks Restore Point' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop" >> "%LOG_FILE%" 2>&1
if %errorlevel% equ 0 (
    echo System Restore Point created successfully
) else (
    echo Creating system restore point has failed after troubleshooting 
)
call "%F%" LOG & goto SYSTEM_MENU

:REG_BACK
cls
call "%F%" CREATE_FOLDER "System" "FullRegistryBackup"
if !errorlevel! equ 1 goto SYSTEM_MENU

call "%F%" PATH_DIR "System" "FullRegistryBackup"

set "SUCCESS_COUNT=0"

:: Define the main system Hives for binary export
echo Creating Full Registry Backup
for %%A in (
    "HKLM\SYSTEM,SYSTEM"
    "HKLM\SOFTWARE,SOFTWARE"
    "HKLM\SAM,SAM"
    "HKLM\SECURITY,SECURITY"
    "HKU\.DEFAULT,DEFAULT"
    "HKCU,NTUSER"
    "HKCU\Software\Classes,UsrClass"
) do (
    for /f "tokens=1,2 delims=," %%B in ("%%~A") do (
        echo  Exporting: %%B
        reg save "%%B" "%TARGET_FOLDER%\%%C.hive" /y >>"%LOG_FILE%" 2>&1      
        if !errorlevel! equ 0 set /a SUCCESS_COUNT+=1
    )
)

if exist "%TARGET_FOLDER%\*.hive" (
    echo. & echo Backup Process Finished. Total Success: !SUCCESS_COUNT!/7 
    call "%F%" CHOICE "Compress folder?"
    if errorlevel 2 (
        echo. & echo Backup saved in: %TARGET_FOLDER%
    ) else (
	    powershell -NoProfile -ExecutionPolicy Bypass -File "Files\System\CompressHiveFiles.ps1" "%TARGET_FOLDER%" "%LOG_FILE%"
    )
) else (
    echo No hive files were created. Backup failed
)
call "%F%" LOG & goto SYSTEM_MENU

:ACTIVATION_MENU
cls & echo. & echo.
echo                        -------------------------------- Activation -------------------------------
echo.
echo                          [1] Windows And Office                             [2] Activation Status
echo. 
echo                                                          [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" goto RUN_ACTIVATION
if "%choice%"=="2" goto CHECK_ACTIVATION
if "%choice%"=="0" goto SYSTEM_MENU

call "%F%" INVALID "(0-2)" & goto ACTIVATION_MENU

:: Activating Windows and Microsoft Office using MAS script
:RUN_ACTIVATION
cls & echo Launching Microsoft Activation Script (MAS) to activate Windows and Office
echo The script will open in a new window. Follow the on-screen instructions
powershell -NoP -EP Bypass -c "irm https://get.activated.win | iex"
call "%F%" GO & goto ACTIVATION_MENU

:: Check if the Machine is Activated or not
:CHECK_ACTIVATION
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\System\ActivationStatus.ps1"
call "%F%" GO & goto ACTIVATION_MENU