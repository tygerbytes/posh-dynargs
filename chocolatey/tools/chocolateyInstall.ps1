try {
    $poshdynargsPath = join-path (Get-ToolsLocation) 'poshdynargs'

    try {
      if (test-path($poshdynargsPath)) {
        Write-Host "Attempting to remove existing `'$poshdynargsPath`'."
        remove-item $poshdynargsPath -recurse -force
      }
    } catch {
      Write-Host "Could not remove `'$poshdynargsPath`'"
    }

    $version = "v$Env:chocolateyPackageVersion"
    if ($version -eq 'v') { $version = 'master' }
    $poshDynargsInstall = if ($env:poshDynargs ) { $env:poshDynargs } else { "https://github.com/tygerbytes/posh-dynargs/zipball/$version" }
    $zip = Install-ChocolateyZipPackage 'poshdynargs' $poshDynargsInstall $poshdynargsPath
    $currentVersionPath = Get-ChildItem "$poshdynargsPath\*posh-dynargs*\" | Sort-Object -Property LastWriteTime | Select-Object -Last 1

    if ($PROFILE -and (Test-Path $PROFILE)) {
        Write-Verbose "Updating posh-dynargs location in `'$PROFILE`'."
        $oldProfile = @(Get-Content $PROFILE)

        . $currentVersionPath\src\Utils.ps1
        $oldProfileEncoding = Get-FileEncoding $PROFILE

        $newProfile = @()
        foreach($line in $oldProfile) {
            if($line -like 'Import-Module *\src\posh-dynargs.psd1*') {
                $line = "Import-Module '$currentVersionPath\src\posh-dynargs.psd1'"
            }
            $newProfile += $line
        }
        Set-Content -path $profile -value $newProfile -Force -Encoding $oldProfileEncoding
    }

    $installer = Join-Path $currentVersionPath 'install.ps1'
    Write-Verbose "Executing `'$installer`'."
    & $installer
} catch {
    Write-Verbose "posh-dynargs install error details: $($_ | Format-List * -Force | Out-String)"
    try {
        if ($oldProfile) {
            Write-Warning "Something went wrong! Resetting contents of `'$PROFILE`'."
            Set-Content -path $PROFILE -value $oldProfile -Force -Encoding $oldProfileEncoding
        }
    }
    catch {}
    throw
}
