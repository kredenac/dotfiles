[CmdletBinding()]
param(
    [switch]$DiagnoseOnly
)

$ErrorActionPreference = "Stop"

$loginHost = "login.microsoftonline.com"
$gsaHost = "72f988bf-86f1-41af-91ab-2d7cd011db47.auth.client.globalsecureaccess.microsoft.com"
$azureVpnInterface = "MSFT-AzVPN-Manual"

function Test-TcpEndpoint {
    param(
        [string]$HostName,
        [int]$Port = 443,
        [int]$TimeoutMilliseconds = 5000
    )

    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $task = $client.ConnectAsync($HostName, $Port)
        if (-not $task.Wait($TimeoutMilliseconds)) {
            return $false
        }
        return $client.Connected
    } catch {
        return $false
    } finally {
        $client.Dispose()
    }
}

function Get-EndpointRoute {
    param([string]$HostName)

    $address = Resolve-DnsName $HostName -Type A -ErrorAction Stop |
        Where-Object IPAddress |
        Select-Object -First 1 -ExpandProperty IPAddress

    $route = Find-NetRoute -RemoteIPAddress $address |
        Where-Object InterfaceAlias |
        Select-Object -First 1

    [pscustomobject]@{
        Host = $HostName
        Address = $address
        InterfaceAlias = $route.InterfaceAlias
    }
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$loginRoute = Get-EndpointRoute $loginHost
$gsaRoute = Get-EndpointRoute $gsaHost
$loginReachable = Test-TcpEndpoint $loginHost
$gsaReachable = Test-TcpEndpoint $gsaHost

Write-Host "Microsoft sign-in: $loginReachable via $($loginRoute.InterfaceAlias)"
Write-Host "GSA authentication: $gsaReachable via $($gsaRoute.InterfaceAlias)"

$azureVpnInterfaceState = Get-NetIPInterface -InterfaceAlias $azureVpnInterface -ErrorAction SilentlyContinue |
    Where-Object AddressFamily -eq IPv4 |
    Select-Object -First 1

$staleAzureVpnRoute = (
    (-not $loginReachable -or -not $gsaReachable) -and
    $azureVpnInterfaceState.ConnectionState -eq "Connected" -and
    ($loginRoute.InterfaceAlias -eq $azureVpnInterface -or $gsaRoute.InterfaceAlias -eq $azureVpnInterface)
)

if ($DiagnoseOnly) {
    Write-Host "Stale Azure VPN route detected: $staleAzureVpnRoute"
    return
}

if (-not (Test-IsAdministrator)) {
    $arguments = @(
        "-NoProfile"
        "-ExecutionPolicy"
        "Bypass"
        "-File"
        "`"$PSCommandPath`""
    )
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments
    return
}

if ($staleAzureVpnRoute) {
    $rasConnections = (& rasdial 2>&1 | Out-String)
    if ($rasConnections -notmatch "No connections") {
        throw "An active VPN connection exists. Disconnect it before resetting the stale Azure VPN route."
    }

    Write-Host "Resetting the orphaned $azureVpnInterface tunnel..."
    Restart-Service RasMan -Force
    Start-Sleep -Seconds 5

    $loginReachable = Test-TcpEndpoint $loginHost
    $gsaReachable = Test-TcpEndpoint $gsaHost
    if (-not $loginReachable -or -not $gsaReachable) {
        throw "Microsoft authentication is still unreachable after resetting the stale Azure VPN tunnel."
    }
} elseif (-not $loginReachable -or -not $gsaReachable) {
    throw "Microsoft authentication is unreachable, but traffic is not using the stale $azureVpnInterface route."
}

$services = @(
    "GlobalSecureAccessEngineService"
    "GlobalSecureAccessTunnelingService"
    "GlobalSecureAccessForwardingProfileService"
    "GlobalSecureAccessClientManagerService"
)

$serviceStartOrder = @(
    "GlobalSecureAccessClientManagerService"
    "GlobalSecureAccessForwardingProfileService"
    "GlobalSecureAccessTunnelingService"
    "GlobalSecureAccessEngineService"
)

foreach ($service in $services) {
    Stop-Service -Name $service -ErrorAction Stop
}

foreach ($service in $serviceStartOrder) {
    Start-Service -Name $service -ErrorAction Stop
}

Get-Process -Name GlobalSecureAccessClient -ErrorAction SilentlyContinue |
    ForEach-Object { Stop-Process -Id $_.Id }

Start-Process "C:\Program Files\Global Secure Access Client\TrayApp\GlobalSecureAccessClient.exe"
Start-Sleep -Seconds 10

Write-Host "GSA services and tray client restarted."
Write-Host "Open Global Secure Access from the system tray. If it shows Signed out, sign in with nidimitr@microsoft.com."
