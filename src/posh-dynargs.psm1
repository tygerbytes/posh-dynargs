
if (Get-Module posh-dynargs) { return }

. $PSScriptRoot\Utils.ps1

function Register-LocalArgumentCompleters() {
    $argumentCompleterRegistryPath = ".\.argument-completer-registry.json"
    if (!(Test-Path $argumentCompleterRegistryPath)) { return }
    if ($DynamicArgumentCompleterSettings.LastRegisteredDirectory -eq $PWD.Path) { return }

    $completableCommands = ((Get-Content $argumentCompleterRegistryPath | ConvertFrom-Json).completableCommands).name;
    if ($null -eq $completableCommands) { return }

    & $PSScriptRoot\Register-DynamicArgumentCompleters.ps1 -commandsToComplete $completableCommands
    $DynamicArgumentCompleterSettings.LastRegisteredDirectory = $PWD.Path
}

$DynamicArgumentCompleterSettings = @{
    LastRegisteredDirectory = $null;
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

    $promptScriptBlock = [scriptblock]::Create(@'
    $origLastExitCode = $global:LASTEXITCODE

    Register-LocalArgumentCompleters

    $pathInfo = $ExecutionContext.SessionState.Path.CurrentLocation
    $currentPath = if ($pathInfo.Drive) { $pathInfo.Path } else { $pathInfo.ProviderPath }

    $global:LASTEXITCODE = $origLastExitCode

    "$currentPath> "
'@)
    Set-Item Function:\prompt -Value $promptScriptBlock
}

$exportModuleMemberParams = @{
    Function = @(
        'Register-LocalArgumentCompleters',
        'Add-PoshDynargsToProfile'
    );
    Variable = @(
        'DynamicArgumentCompleterSettings'
    );
}

Export-ModuleMember @exportModuleMemberParams
