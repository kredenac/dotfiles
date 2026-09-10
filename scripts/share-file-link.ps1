[CmdletBinding(DefaultParameterSetName = 'Text')]
param(
    [Parameter(Mandatory, ParameterSetName = 'File')]
    [string]$InputPath,

    [Parameter(Mandatory, ParameterSetName = 'Text')]
    [AllowEmptyString()]
    [string]$Text,

    [Parameter(ParameterSetName = 'Text')]
    [string]$FileName,

    [string]$DestinationFolder = 'agent-docs',

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Get-ActiveOneDriveRoot {
    $accountsRoot = 'HKCU:\Software\Microsoft\OneDrive\Accounts'
    if (-not (Test-Path -LiteralPath $accountsRoot)) {
        throw 'No OneDrive account configuration was found for the current user.'
    }

    $accounts = Get-ChildItem -LiteralPath $accountsRoot |
        ForEach-Object {
            $properties = Get-ItemProperty -LiteralPath $_.PSPath
            if ($properties.UserEmail -and
                $properties.UserFolder -and
                (Test-Path -LiteralPath $properties.UserFolder)) {
                [pscustomobject]@{
                    Name       = $_.PSChildName
                    UserFolder = [Environment]::ExpandEnvironmentVariables($properties.UserFolder)
                    IsBusiness = $_.PSChildName -like 'Business*'
                }
            }
        } |
        Sort-Object IsBusiness -Descending

    $account = $accounts | Select-Object -First 1
    if (-not $account) {
        throw 'No active OneDrive sync root was found for the current user.'
    }

    return $account.UserFolder
}

function Get-OneDriveLink {
    param([Parameter(Mandatory)][string]$Path)

    $shell = New-Object -ComObject Shell.Application
    $deadline = (Get-Date).AddSeconds(60)
    $item = $null
    $verb = $null

    do {
        $folder = $shell.Namespace((Split-Path -LiteralPath $Path))
        $item = $folder.ParseName((Split-Path -Leaf $Path))
        if ($item) {
            $provider = $item.ExtendedProperty('System.StorageProviderId')
            $verb = $item.Verbs() |
                Where-Object { $_.Name.Replace('&', '').Trim() -eq 'Copy Link' } |
                Select-Object -First 1
        }

        if (-not $verb) {
            Start-Sleep -Milliseconds 500
        }
    } until (($item -and $provider -eq 'OneDrive' -and $verb) -or (Get-Date) -ge $deadline)

    if (-not $item -or $provider -ne 'OneDrive') {
        throw "The file did not become available through the OneDrive sync provider: $Path"
    }
    if (-not $verb) {
        throw "Windows Explorer did not expose the OneDrive 'Copy Link' action for: $Path"
    }

    $clipboardMarker = "__copilot_share_file_link_$([guid]::NewGuid())"
    Set-Clipboard -Value $clipboardMarker
    $verb.DoIt()

    $deadline = (Get-Date).AddSeconds(30)
    do {
        Start-Sleep -Milliseconds 500
        $link = Get-Clipboard -Raw -ErrorAction SilentlyContinue
    } until (($link -and $link -ne $clipboardMarker -and $link -match '^https?://') -or
        (Get-Date) -ge $deadline)

    if (-not $link -or $link -eq $clipboardMarker -or $link -notmatch '^https?://') {
        throw "OneDrive 'Copy Link' did not place a URL on the clipboard within 30 seconds."
    }

    return $link.Trim()
}

$oneDriveRoot = Get-ActiveOneDriveRoot
$destinationDirectory = Join-Path -Path $oneDriveRoot -ChildPath $DestinationFolder
New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null

if ($PSCmdlet.ParameterSetName -eq 'File') {
    $source = Get-Item -LiteralPath $InputPath
    if ($source.PSIsContainer) {
        throw "InputPath must identify a file, not a directory: $InputPath"
    }

    $destinationPath = Join-Path -Path $destinationDirectory -ChildPath $source.Name
    if ($source.FullName -ne $destinationPath) {
        Copy-Item -LiteralPath $source.FullName -Destination $destinationPath -Force:$Force
    }
} else {
    if (-not $FileName) {
        $FileName = "shared-context-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    }
    if ([IO.Path]::GetFileName($FileName) -ne $FileName) {
        throw 'FileName must be a file name without directory components.'
    }

    $destinationPath = Join-Path -Path $destinationDirectory -ChildPath $FileName
    if ((Test-Path -LiteralPath $destinationPath) -and -not $Force) {
        throw "The destination already exists. Use -Force to replace it: $destinationPath"
    }

    Set-Content -LiteralPath $destinationPath -Value $Text -Encoding utf8
}

$resolvedPath = (Get-Item -LiteralPath $destinationPath).FullName
$link = Get-OneDriveLink -Path $resolvedPath

[pscustomobject]@{
    Path = $resolvedPath
    Link = $link
}
