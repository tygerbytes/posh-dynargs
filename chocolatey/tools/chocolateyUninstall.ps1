try {
    $poshdynargsPath = join-path (Get-ToolsLocation) 'poshdynargs'

    $currentVersionPath = Get-ChildItem "$poshdynargsPath\*posh-dynargs*\" | Sort-Object -Property LastWriteTime | Select-Object -Last 1

    if ($PROFILE -and (Test-Path $PROFILE)) {
        Write-Verbose "Removing posh-dynargs references in `'$PROFILE`'."
        $oldProfile = @(Get-Content $PROFILE)

        . $currentVersionPath\src\Utils.ps1
        $oldProfileEncoding = Get-FileEncoding $PROFILE

        $newProfile = @()
        foreach($line in $oldProfile) {
            if($line -like 'Import-Module *\src\posh-dynargs.psd1*') {
                continue;
            }
            $newProfile += $line
        }
        Set-Content -path $profile -value $newProfile -Force -Encoding $oldProfileEncoding
    }

    try {
      if (test-path($poshdynargsPath)) {
        Write-Host "Attempting to remove existing `'$poshdynargsPath`'."
        remove-item $poshdynargsPath -recurse -force
      }
    } catch {
      Write-Host "Could not remove `'$poshdynargsPath`'"
    }
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
