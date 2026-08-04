:NETWORK_MENU
cls & echo. & echo.
echo                        --------------------------------- Network ---------------------------------
echo.
echo                          [1] Network Tweaks                                    [2] Change DNS
echo.
echo                          [3] Wi-Fi Passwords                                   [4] Reset Network
echo.
echo                          [5] Network Info                                      [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "
if "%choice%"=="1" (
    set ROUTINE=NETWORK_TWEAKS
    set REV_ROUTINE=REV_NETWORK_TWEAKS
    set APPLY=Improve Network settings
    set REVERT=Default Network settings
    set MENU=NETWORK_MENU
    call "%F%" SUB_MENU
    goto !SUBMENU_RESULT!
)
if "%choice%"=="2" goto DNS_MENU
if "%choice%"=="3" goto WIFI_PASSWORDS
if "%choice%"=="4" goto NETWORK_RESET
if "%choice%"=="5" (call "%F%" INFO_SCRIPT "Network" "NetworkInfo"  & goto NETWORK_MENU)
if "%choice%"=="0" exit /b 99

call "%F%" INVALID "(0-5)" & goto NETWORK_MENU

:NETWORK_TWEAKS
call "%F%" PATH_DIR "Network" "NetworkTweaks"

echo. & echo Improve network settings via registry
reg import "Files\Network\NetworkTweaks.reg" >> "%LOG_FILE%" 2>&1

echo Configuring TCP global parameters

:: fastopen=enabled :          Speeds up successive TCP connections
:: fastopenfallback=enabled :  Allows fallback to standard TCP if Fast Open fails
:: rss=enabled :               Distributes network processing across multiple CPU cores
:: autotuninglevel=high :      Optimizes the TCP receive window for high-speed connections
for %%P in ("fastopen=enabled" "fastopenfallback=enabled" "rss=enabled" "autotuninglevel=high") do (
    echo  - %%~P
    netsh int tcp set global %%~P >> "%LOG_FILE%" 2>&1
)

echo Setting Cloudflare DNS on all connected interfaces
set DNS_IPv4_1=1.1.1.1
set DNS_IPv4_2=1.0.0.1
set DNS_IPv6_1=2606:4700:4700::1111
set DNS_IPv6_2=2606:4700:4700::1001
call "%F%" UPDATE_DNS

call "%F%" LOG & goto NETWORK_MENU

:REV_NETWORK_TWEAKS
call "%F%" PATH_DIR "Network" "DefaultNetworkSettings"

echo. & echo Restoring default network registry settings
reg import "Files\Network\DefaultNetworkSettings.reg" >> "%LOG_FILE%" 2>&1

echo Resetting TCP global parameters to default
for %%P in ("fastopen=default" "fastopenfallback=default" "rss=default" "autotuninglevel=normal") do (
    echo  - %%~P
    netsh int tcp set global %%~P >> "%LOG_FILE%" 2>&1
)

echo. & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\SetDHCP.ps1"

call "%F%" LOG & goto NETWORK_MENU

:DNS_MENU
cls & echo. & echo.
echo                        ------------------------------- DNS Server --------------------------------
echo.
echo                           [1] Google Public                                      [2] Cloudflare
echo.
echo                           [3] Cloudflare Family                                  [4] AdGuard
echo.
echo                           [5] Clean Browsing                                     [6] Quad9
echo.
echo                           [7] OpenDNS                                            [8] Default
echo.
echo                           [9] DNS Server Test                                    [10] DNS Status
echo.
echo                                                         [0] Back
echo.
echo                        ---------------------------------------------------------------------------

echo. & set "choice=" & set /p choice="Select an option: "

:: Google DNS: Highly reliable and fast global infrastructure
if "%choice%"=="1" (set "DNS_NAME=Google Public DNS" & set "DNS_IPv4_1=8.8.8.8" & set "DNS_IPv4_2=8.8.4.4" & set "DNS_IPv6_1=2001:4860:4860::8888" & set "DNS_IPv6_2=2001:4860:4860::8844" & goto SET_DNS)

:: Cloudflare DNS: Focused on speed and strict user privacy
if "%choice%"=="2" (set "DNS_NAME=Cloudflare DNS" & set "DNS_IPv4_1=1.1.1.1" & set "DNS_IPv4_2=1.0.0.1" & set "DNS_IPv6_1=2606:4700:4700::1111" & set "DNS_IPv6_2=2606:4700:4700::1001" & goto SET_DNS)

:: Cloudflare Family: Blocks malware and adult content automatically
if "%choice%"=="3" (set "DNS_NAME=Cloudflare Family DNS" & set "DNS_IPv4_1=1.1.1.3" & set "DNS_IPv4_2=1.0.0.3" & set "DNS_IPv6_1=2606:4700:4700::1113" & set "DNS_IPv6_2=2606:4700:4700::1003" & goto SET_DNS)

:: AdGuard DNS: Filters out ads and trackers at the network level
if "%choice%"=="4" (set "DNS_NAME=AdGuard DNS" & set "DNS_IPv4_1=94.140.14.14" & set "DNS_IPv4_2=94.140.15.15" & set "DNS_IPv6_1=2a10:50c0::ad1:ff" & set "DNS_IPv6_2=2a10:50c0::ad2:ff" & goto SET_DNS)

:: Clean Browsing: Optimized for family safety and security filtering
if "%choice%"=="5" (set "DNS_NAME=Clean Browsing DNS" & set "DNS_IPv4_1=185.228.168.168" & set "DNS_IPv4_2=185.228.169.168" & set "DNS_IPv6_1=2a0d:2a00:1::" & set "DNS_IPv6_2=2a0d:2a00:2::" & goto SET_DNS)

:: Quad9 DNS: Strong emphasis on blocking malicious domains and phishing
if "%choice%"=="6" (set "DNS_NAME=Quad9 DNS" & set "DNS_IPv4_1=9.9.9.9" & set "DNS_IPv4_2=149.112.112.112" & set "DNS_IPv6_1=2620:fe::fe" & set "DNS_IPv6_2=2620:fe::9" & goto SET_DNS)

:: OpenDNS: Provides customizable web filtering and high uptime
if "%choice%"=="7" (set "DNS_NAME=OpenDNS" & set "DNS_IPv4_1=208.67.222.222" & set "DNS_IPv4_2=208.67.220.220" & set "DNS_IPv6_1=2620:119:35::35" & set "DNS_IPv6_2=2620:119:53::53" & goto SET_DNS)

if "%choice%"=="8" goto SET_DHCP
if "%choice%"=="9" goto DNS_SERVER_TEST
if "%choice%"=="10" goto DNS_STATUS
if "%choice%"=="0" goto NETWORK_MENU

call "%F%" INVALID "(0-10)" & goto DNS_MENU

:SET_DNS
call "%F%" PATH_DIR "Network" "DNS"

echo. & echo Setting %DNS_NAME% server on all connected interfaces
call "%F%" UPDATE_DNS

call "%F%" LOG & goto DNS_MENU

:SET_DHCP
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\SetDHCP.ps1"
call "%F%" GO & goto DNS_MENU

:DNS_SERVER_TEST
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\DNSTest.ps1"
call "%F%" GO & goto DNS_MENU

:DNS_STATUS
cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\DNSStatus.ps1"
call "%F%" GO & goto DNS_MENU

:WIFI_PASSWORDS
call "%F%" CREATE_FILE "Network" "WifiPassword.log"
if !errorlevel! equ 1 goto NETWORK_MENU

cls & powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\WifiPassword.ps1" "%TARGET_FILE%"
echo. & echo Wifi Password file saved in: %TARGET_FILE%
call "%F%" GO & goto NETWORK_MENU

:NETWORK_RESET
call "%F%" CONFIRM "WARNING: This script will RESET ALL network configurations"
if errorlevel 2 goto NETWORK_MENU

call "%F%" PATH_DIR "Network" "NetworkReset"
echo. & echo Stopping Network Services

:: Dhcp:      Obtains and renews IP configuration from DHCP servers
:: dnscache:  Temporarily stores DNS results to speed up queries
:: dot3svc:   Handles authentication for wired (Ethernet) network connections
:: netman:    Manages objects in the network
:: netprofm:  Identifies the networks the computer has connected to
:: nlasvc:    Collects and stores configuration information
:: WlanSvc:   Connects to Wi-Fi
:: WwanSvc:   Manages mobile broadband
for %%S in ("dot3svc" "netman" "WlanSvc" "WwanSvc") do call "%F%" NET_CONTROL "%%S" "stop" >> "%LOG_FILE%" 2>&1

echo Resetting Network services to default startup
for %%S in ("Dhcp" "dnscache" "nlasvc" "WlanSvc") do call "%F%" SC_CONFIGURE "%%S" "auto" >> "%LOG_FILE%" 2>&1
for %%S in ("dot3svc" "netman" "netprofm" "WwanSvc") do call "%F%" SC_CONFIGURE "%%S" "demand" >> "%LOG_FILE%" 2>&1

echo Starting Network Services
for %%S in ("dot3svc" "netman" "WlanSvc" "WwanSvc") do call "%F%" NET_CONTROL "%%S" "start" >> "%LOG_FILE%" 2>&1

:: Reset the core TCP/IP stack to factory defaults (rewrites registry keys)
echo Reset TCP/IP Stack
netsh int ip reset >> "%LOG_FILE%" 2>&1

:: Repair the Winsock Catalog (useful if internet is blocked by malware or bad drivers)
echo Reset Winsock catalog
netsh winsock reset >> "%LOG_FILE%" 2>&1

:: Clear any system-wide HTTP proxy settings that might redirect traffic
echo Reset WinHTTP proxy
netsh winhttp reset proxy >> "%LOG_FILE%" 2>&1

:: Reset IPv6 specific settings to their default state
echo Reset IPv6 settings
netsh interface ipv6 reset >> "%LOG_FILE%" 2>&1

:: Reset Windows Port Proxy configurations
echo Reset Port Proxies
netsh interface portproxy reset >> "%LOG_FILE%" 2>&1

:: Restore Windows Firewall to its default out-of-the-box rules
echo Reset Firewall Rules
netsh advfirewall reset >> "%LOG_FILE%" 2>&1

:: Clears the local cache used to optimize WAN traffic
echo Resetting BranchCache
netsh branchcache reset >> "%LOG_FILE%" 2>&1

:: Refresh NetBIOS names by purging and reloading the remote cache table
echo Refreshing NetBIOS names
nbtstat -RR >> "%LOG_FILE%" 2>&1

:: Clear the DNS Resolver cache to fix "Page Not Found" errors
echo Flushing DNS
ipconfig /flushdns >> "%LOG_FILE%" 2>&1

:: Clear the ARP (Address Resolution Protocol) cache to refresh local IP-to-MAC mappings
echo Cleaning ARP cache
arp -d * >> "%LOG_FILE%" 2>&1

:: Remove entries from the IPv6 neighbor cache (similar to ARP for IPv6)
echo Cleaning IPv6 Neighbor
netsh interface ipv6 delete neighbors >> "%LOG_FILE%" 2>&1

:: Clear the IPv6 destination cache to resolve routing issues
echo Cleaning IPv6 Destination Cache
netsh interface ipv6 delete destinationcache >> "%LOG_FILE%" 2>&1

:: Clear the Routing Table to remove static routes and corrupt gateway entries
echo Reset Routing Table
route -f >> "%LOG_FILE%" 2>&1

:: Release current DHCP IP addresses for all adapters
echo Releasing IP addresses
ipconfig /release >> "%LOG_FILE%" 2>&1
ipconfig /release6 >> "%LOG_FILE%" 2>&1

:: Restart all physically connected network interfaces
:: This effectively "plugs and unplugs" the cable via software
echo Restart all connected interfaces
powershell -NoProfile -ExecutionPolicy Bypass -File "Files\Network\RestartInterfaces.ps1"
timeout /t 3 /nobreak >nul

:: Request new IP addresses from the router/DHCP server
echo Renewing IP addresses
ipconfig /renew >> "%LOG_FILE%" 2>&1
ipconfig /renew6  >> "%LOG_FILE%" 2>&1

:: Refresh DHCP leases and re-register DNS names with the server
echo Registering DNS name
ipconfig /registerdns >> "%LOG_FILE%" 2>&1

call "%F%" RESTART 
call "%F%" LOG & goto NETWORK_MENU