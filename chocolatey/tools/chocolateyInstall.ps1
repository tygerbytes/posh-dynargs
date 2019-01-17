$ErrorActionPreference = 'Stop'

$moduleName = 'posh-dynargs'

if ($PSVersionTable.PSVersion.Major -le 4) {
    $PowerShellUpgradeUrl = 'https://docs.microsoft.com/en-us/powershell/scripting/install/installing-windows-powershell'
    Write-Warning "$moduleName requires PowerShell 5 or later. See '$PowerShellUpgradeUrl' to upgrade."
}

$libDir = "$($MyInvocation.MyCommand.Definition | Split-Path -Parent | Split-Path -Parent )"
$sourcePath = Join-Path -Path $libDir -ChildPath "src\*"
$destinationPath = Join-Path -Path $env:ProgramFiles -ChildPath "WindowsPowerShell\Modules\$moduleName"

if ($PSVersionTable.PSVersion.Major -ge 5) {
    $manifestFile = Join-Path -Path $libDir -ChildPath "src\$moduleName.psd1"
    $manifest = Test-ModuleManifest -Path $manifestFile -WarningAction Ignore -ErrorAction Stop
    $destinationPath = Join-Path -Path $destinationPath -ChildPath $manifest.Version.ToString()
}

if (Test-Path $destinationPath) {
    Write-Verbose "Destination exists. Deleting '$destinationPath'."
    Remove-Item -Recurse $destinationPath -Force
}

Write-Verbose "Creating destination directory '$destinationPath' for module."
New-Item -Path $destinationPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

Write-Verbose "Moving '$moduleName' files from '$sourcePath' to '$destinationPath'."
Move-Item -Path $sourcePath -Destination $destinationPath -Force

Write-Host "`nTo add posh-dynargs to your profile use 'Import-Module posh-dynargs; Add-PoshDynargsToProfile'.`n"
