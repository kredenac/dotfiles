[CmdletBinding()]
param(
    [datetime]$StartDate = (Get-Date).Date,
    [ValidateRange(1, 12)]
    [int]$Months = 2,
    [string]$ProfileDirectory = "Default",
    [switch]$Setup,
    [switch]$Json
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Copy-OpenFile {
    param(
        [Parameter(Mandatory)]
        [string]$Source,
        [Parameter(Mandatory)]
        [string]$Destination
    )

    $sourceStream = [System.IO.File]::Open(
        $Source,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
    )
    try {
        $destinationStream = [System.IO.File]::Open(
            $Destination,
            [System.IO.FileMode]::Create,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None
        )
        try {
            $sourceStream.CopyTo($destinationStream)
        } finally {
            $destinationStream.Dispose()
        }
    } finally {
        $sourceStream.Dispose()
    }
}

$edgePath = @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $edgePath) {
    throw "Microsoft Edge was not found."
}

$nodePath = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $nodePath) {
    throw "Node.js is required but was not found."
}

$sourceUserData = Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data"
$sourceProfile = Join-Path $sourceUserData $ProfileDirectory
if (-not (Test-Path $sourceProfile)) {
    throw "Edge profile '$ProfileDirectory' was not found at $sourceProfile."
}

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
$listener.Stop()

$profileRoot = Join-Path $env:LOCALAPPDATA "reports-oof\EdgeProfile"
$automationProfile = Join-Path $profileRoot $ProfileDirectory
$automationNetwork = Join-Path $automationProfile "Network"
$nodeScript = Join-Path $PSScriptRoot "reports-oof.mjs"

if (-not (Test-Path (Join-Path $profileRoot "Local State"))) {
    New-Item -ItemType Directory -Path $automationNetwork -Force | Out-Null
    try {
        Copy-OpenFile (Join-Path $sourceUserData "Local State") (Join-Path $profileRoot "Local State")
        @("Preferences", "Secure Preferences", "Web Data", "Login Data") | ForEach-Object {
            $source = Join-Path $sourceProfile $_
            if (Test-Path $source) {
                Copy-OpenFile $source (Join-Path $automationProfile $_)
            }
        }

        $sourceNetwork = Join-Path $sourceProfile "Network"
        if (Test-Path $sourceNetwork) {
            Get-ChildItem $sourceNetwork -File | ForEach-Object {
                Copy-OpenFile $_.FullName (Join-Path $automationNetwork $_.Name)
            }
        }
    } catch {
        throw "Could not initialize the reports-oof Edge profile from the active default profile. Close Edge and retry, or run this script with -Setup to sign in directly. $($_.Exception.Message)"
    }
}

if ($Setup) {
    Start-Process -FilePath $edgePath -ArgumentList @(
        "--user-data-dir=$profileRoot"
        "--profile-directory=$ProfileDirectory"
        "--no-first-run"
        "https://msvacation.microsoft.com/default.aspx"
    ) | Out-Null
    Write-Output "Complete sign-in in the dedicated Edge window, close it, and rerun reports-oof.ps1."
    return
}

$edgeArguments = @(
    "--headless=new"
    "--remote-debugging-port=$port"
    "--user-data-dir=$profileRoot"
    "--profile-directory=$ProfileDirectory"
    "--no-first-run"
    "--disable-default-apps"
    "https://msvacation.microsoft.com/default.aspx"
)

try {
    Start-Process -FilePath $edgePath -ArgumentList $edgeArguments | Out-Null

    $deadline = (Get-Date).AddSeconds(30)
    do {
        try {
            Invoke-RestMethod "http://127.0.0.1:$port/json/version" -TimeoutSec 2 | Out-Null
            $browserReady = $true
        } catch {
            $browserReady = $false
            Start-Sleep -Milliseconds 300
        }
    } until ($browserReady -or (Get-Date) -ge $deadline)

    if (-not $browserReady) {
        throw "Edge did not expose its local automation endpoint."
    }

    $arguments = @(
        $nodeScript
        "--port", $port
        "--start-date", $StartDate.ToString("yyyy-MM-dd")
        "--months", $Months
    )
    if ($Json) {
        $arguments += "--json"
    }

    $output = & $nodePath @arguments 2>&1
    $exitCode = $LASTEXITCODE
    $output | Write-Output
    if ($exitCode -ne 0) {
        throw "MS Vacation extraction failed with exit code $exitCode."
    }
} finally {
    Get-CimInstance Win32_Process -Filter "Name = 'msedge.exe'" |
        Where-Object { $_.CommandLine -and $_.CommandLine.Contains($profileRoot) } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

}
