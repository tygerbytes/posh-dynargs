
if (Get-Module posh-dynargs) { return }

. $PSScriptRoot\Utils.ps1

function Register-LocalArgumentCompleters() {
    if ($PoshDynargsSettings.EnableTiming) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
    }
    $argumentCompleterRegistryPath = ".\.argument-completer-registry.json"
    if (!(Test-Path $argumentCompleterRegistryPath)) { return }
    if ($PoshDynargsSettings.LastRegisteredDirectory -eq $PWD.Path) { return }

    $completableCommands = ((Get-Content $argumentCompleterRegistryPath | ConvertFrom-Json).completableCommands).name;
    if ($null -eq $completableCommands) { return }

    & $PSScriptRoot\Register-DynamicArgumentCompleters.ps1 -commandsToComplete $completableCommands
    $PoshDynargsSettings.LastRegisteredDirectory = $PWD.Path

    # If timing enabled, display elapsed milliseconds
    if ($PoshDynargsSettings.EnableTiming) {
        $sw.Stop()
        $elapsed = $sw.ElapsedMilliseconds
        Write-Host "[${elapsed}ms]" -NoNewline -ForegroundColor DarkGray
    }
}

$PoshDynargsSettings = @{
    LastRegisteredDirectory = $null;
    EnableTiming = $false;
}

if ($GitPromptSettings) {
    # Piggyback on the posh-git prompt
    # TODO: Better way to do this?
    $GitPromptSettings.DefaultPromptPrefix += '$(Register-LocalArgumentCompleters)'
}
else {
    # TODO: Don't really want to clobber the existing prompt.
    #       Consider wrapping the existing prompt.
    # TODO: Bypass overriding prompt via environment setting.
    $promptScriptBlock = {
        $origLastExitCode = $global:LASTEXITCODE

        Register-LocalArgumentCompleters

        $pathInfo = $ExecutionContext.SessionState.Path.CurrentLocation
        $currentPath = if ($pathInfo.Drive) { $pathInfo.Path } else { $pathInfo.ProviderPath }

        $global:LASTEXITCODE = $origLastExitCode

        "$currentPath> "
    }

    Set-Item Function:\prompt -Value $promptScriptBlock
}

$exportModuleMemberParams = @{
    Function = @(
        'Register-LocalArgumentCompleters',
        'Add-PoshDynargsToProfile'
    );
    Variable = @(
        'PoshDynargsSettings'
    );
}

Export-ModuleMember @exportModuleMemberParams
