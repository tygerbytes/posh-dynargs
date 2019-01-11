# Need this variable as long as we support PS v2
$ModuleBasePath = Split-Path $MyInvocation.MyCommand.Path -Parent

function Test-Administrator {
    # PowerShell 5.x only runs on Windows so use .NET types to determine isAdminProcess
    # Or if we are on v6 or higher, check the $IsWindows pre-defined variable.
    if (($PSVersionTable.PSVersion.Major -le 5) -or $IsWindows) {
        $currentUser = [Security.Principal.WindowsPrincipal]([Security.Principal.WindowsIdentity]::GetCurrent())
        return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    # Must be Linux or OSX, so use the id util. Root has userid of 0.
    return 0 -eq (id -u)
}

<#
.SYNOPSIS
    Configures your PowerShell profile (startup) script to import the posh-dynargs
    module when PowerShell starts.
.DESCRIPTION
    Checks if your PowerShell profile script is not already importing posh-dynargs
    and if not, adds a command to import the posh-dynargs module. This will cause
    PowerShell to load posh-dynargs whenever PowerShell starts.
.PARAMETER AllHosts
    By default, this command modifies the CurrentUserCurrentHost profile
    script.  By specifying the AllHosts switch, the command updates the
    CurrentUserAllHosts profile (or AllUsersAllHosts, given -AllUsers).
.PARAMETER AllUsers
    By default, this command modifies the CurrentUserCurrentHost profile
    script.  By specifying the AllUsers switch, the command updates the
    AllUsersCurrentHost profile (or AllUsersAllHosts, given -AllHosts).
    Requires elevated permissions.
.PARAMETER Force
    Do not check if the specified profile script is already importing
    posh-dynargs. Just add Import-Module posh-dynargs command.
.EXAMPLE
    PS C:\> Add-PoshDynargsToProfile
    Updates your profile script for the current PowerShell host to import the
    posh-dynargs module when the current PowerShell host starts.
.EXAMPLE
    PS C:\> Add-PoshDynargsToProfile -AllHosts
    Updates your profile script for all PowerShell hosts to import the posh-dynargs
    module whenever any PowerShell host starts.
.INPUTS
    None.
.OUTPUTS
    None.
#>
function Add-PoshDynargsToProfile {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [switch]
        $AllHosts,

        [Parameter()]
        [switch]
        $AllUsers,

        [Parameter()]
        [switch]
        $Force
    )

    if ($AllUsers -and !(Test-Administrator)) {
        throw 'Adding posh-dynargs to an AllUsers profile requires an elevated host.'
    }

    $profileName = $(if ($AllUsers) { 'AllUsers' } else { 'CurrentUser' }) `
                 + $(if ($AllHosts) { 'AllHosts' } else { 'CurrentHost' })
    Write-Verbose "`$profileName = '$profileName'"

    $profilePath = $PROFILE.$profileName
    Write-Verbose "`$profilePath = '$profilePath'"

    if (!$profilePath) { $profilePath = $PROFILE }

    if (!$Force) {
        $importedInProfile = Test-ProfileContains 'posh-dynargs'

        if ($importedInProfile) {
            Write-Warning "Skipping add of posh-dynargs import to file '$profilePath'."
            Write-Warning "posh-dynargs appears to already be imported in one of your profile scripts."
            Write-Warning "If you want to force the add, use the -Force parameter."
            return
        }
    }

    if (!$profilePath) {
        Write-Warning "Skipping add of posh-dynargs import to profile; no profile found."
        Write-Verbose "`$PROFILE              = '$PROFILE'"
        Write-Verbose "CurrentUserCurrentHost = '$($PROFILE.CurrentUserCurrentHost)'"
        Write-Verbose "CurrentUserAllHosts    = '$($PROFILE.CurrentUserAllHosts)'"
        Write-Verbose "AllUsersCurrentHost    = '$($PROFILE.AllUsersCurrentHost)'"
        Write-Verbose "AllUsersAllHosts       = '$($PROFILE.AllUsersAllHosts)'"
        return
    }

    # If the profile script exists and is signed, then we should not modify it
    if (Test-Path -LiteralPath $profilePath) {
        $sig = Get-AuthenticodeSignature $profilePath
        if ($null -ne $sig.SignerCertificate) {
            Write-Warning "Skipping add of posh-dynargs import to profile; '$profilePath' appears to be signed."
            Write-Warning "Add the command 'Import-Module posh-dynargs' to your profile and resign it."
            return
        }
    }

    $profileContent = "`nImport-Module '$ModuleBasePath\posh-dynargs.psd1'"

    # Make sure the PowerShell profile directory exists
    $profileDir = Split-Path $profilePath -Parent
    if (!(Test-Path -LiteralPath $profileDir)) {
        if ($PSCmdlet.ShouldProcess($profileDir, "Create current user PowerShell profile directory")) {
            New-Item $profileDir -ItemType Directory -Force -Verbose:$VerbosePreference > $null
        }
    }

    if (!(Test-ProfileContains 'posh-git')) {
        Write-Warning "If you plan on integrating posh-dynargs with posh-git, make sure it is imported first."
    }

    if ($PSCmdlet.ShouldProcess($profilePath, "Add 'Import-Module posh-dynargs' to profile")) {
        Add-Content -LiteralPath $profilePath -Value $profileContent -Encoding UTF8
    }
}

<#
.SYNOPSIS
    Gets the file encoding of the specified file.
.DESCRIPTION
    Gets the file encoding of the specified file.
.PARAMETER Path
    Path to the file to check.  The file must exist.
.EXAMPLE
    PS C:\> Get-FileEncoding $profile
    Get's the file encoding of the profile file.
.INPUTS
    None.
.OUTPUTS
    [System.String]
.NOTES
    Adapted from http://www.west-wind.com/Weblog/posts/197245.aspx
#>
function Get-FileEncoding($Path) {
    $bytes = [byte[]](Get-Content $Path -Encoding byte -ReadCount 4 -TotalCount 4)

    if (!$bytes) { return 'utf8' }

    switch -regex ('{0:x2}{1:x2}{2:x2}{3:x2}' -f $bytes[0],$bytes[1],$bytes[2],$bytes[3]) {
        '^efbbbf'   { return 'utf8' }
        '^2b2f76'   { return 'utf7' }
        '^fffe'     { return 'unicode' }
        '^feff'     { return 'bigendianunicode' }
        '^0000feff' { return 'utf32' }
        default     { return 'ascii' }
    }
}

function Test-ProfileContains {
    param (
        [Parameter(Position=0)]
        [string]
        $string
    )

    # Search the user's profiles to see if any are using posh-dynargs already.
    $importedInProfile = $false
    if (!$importedInProfile) {
        $importedInProfile = Test-ScriptContains -Path $PROFILE -String $string
    }
    if (!$importedInProfile) {
        $importedInProfile = Test-ScriptContains -Path $PROFILE.CurrentUserCurrentHost -String $string
    }
    if (!$importedInProfile) {
        $importedInProfile = Test-ScriptContains -Path $PROFILE.CurrentUserAllHosts -String $string
    }
    if (!$importedInProfile) {
        $importedInProfile = Test-ScriptContains -Path $PROFILE.AllUsersCurrentHost -String $string
    }
    if (!$importedInProfile) {
        $importedInProfile = Test-ScriptContains -Path $PROFILE.AllUsersAllHosts -String $string
    }
    $importedInProfile
}

function Test-ScriptContains {
    param (
        [Parameter(Position=0)]
        [string]
        $Path,
        [Parameter(Position=1)]
        [string]
        $String
    )

    if (!$Path -or !(Test-Path -LiteralPath $Path)) {
        return $false
    }

    $match = (@(Get-Content $Path -ErrorAction SilentlyContinue) -match $String).Count -gt 0
    if ($match) { Write-Verbose "$String found in '$Path'" }
    $match
}
