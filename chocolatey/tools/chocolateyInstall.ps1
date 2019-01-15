try {
    $poshdynargsPath = Join-Path (Get-ToolsLocation) 'poshdynargs'

    try {
      if (Test-Path($poshdynargsPath)) {
        Write-Host "Attempting to remove existing `'$poshdynargsPath`'."
        Remove-Item $poshdynargsPath -Recurse -Force
      }
    } catch {
      Write-Host "Could not remove `'$poshdynargsPath`'"
    }

    $version = "v$Env:chocolateyPackageVersion"
    $zipPath = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)\\posh-dynargs-$version.zip"
    Get-ChocolateyUnzip -FileFullPath $zipPath -PackageName 'poshdynargs' -Destination $poshdynargsPath
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
