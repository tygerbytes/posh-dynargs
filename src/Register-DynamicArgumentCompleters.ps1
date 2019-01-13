param(
    [Parameter(Mandatory=$true)]
    [String[]]$commandsToComplete)
<#

.SYNOPSIS
Register tab completion for custom commands that change depending on the current directory.

.PARAMETER commandsToComplete
An array of strings representing the commands to register for tab completion.

.EXAMPLE
Register-DynamicArgumentCompleters -commandsToComplete @("build", "ci", "test")

.NOTES
Just to reiterate, there will be no tab completion without a .argument-completer-registry.json
file in the directory containing the commands.

#>

Register-ArgumentCompleter -Native -CommandName $commandsToComplete -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    # Grab the base command from the abstract syntax tree
    $baseCommand = $commandAst.CommandElements[0].Value
    $leadingDotSlash = $false
    if ($baseCommand -match "^\.[/\\]") {
        # Strip the leading ./ or .\ from the command
        $leadingDotSlash = $true
        $baseCommand = $baseCommand.Substring(2)
    }

    $argumentCompleterRegistryPath = ".\.argument-completer-registry.json"

    # Get the matching command object from the local "argument completer registry"
    $cmd = ((Get-Content $argumentCompleterRegistryPath | ConvertFrom-Json).completableCommands | Where-Object name -match $baseCommand);
    if ($cmd -eq $null) { return }

    $argsRegex = ""
    $switchesRegex = ""
    $argsPath = $cmd.argsPath
    switch ( $cmd.type ) {
        cake {
            $argsRegex = "^Task\(`"([A-Z][^`"]+)`""
            $switchesRegex = "Argument<\w+>\(`"(\w+)`""
        }
        make {
            $argsRegex = "^([a-z_]+):"
        }
        psake {
            $argsRegex = "^Task ([A-Z][^ ]+)"
        }
        default {
            $argsRegex = $cmd.regex
            if ($cmd.helpCommand) {
                $uniquePath = "global";
                if (!($cmd.funcDefaults.useGlobal)) {
                    $uniquePath = $(Get-Location) -replace "[:\\/]", ""
                }
                $argsPath = "$env:temp/$baseCommand-$uniquePath.txt"
                if (!(Test-Path $argsPath)) {
                    if (!($cmd.helpCommand -match "^(-h|/\?|--help|help|-\?|--list|-l)$")) {
                        # To avoid command injection, only allow whitelisted "help" arguments
                        return
                    }
                    $expression = "$baseCommand $($cmd.helpCommand)"
                    if (Test-Path "./$baseCommand.*" -Include *.bat,*.cmd,*.ps1) {
                        $expression = "./$expression"
                    }
                    Write-Host " >>> " -ForegroundColor Cyan -NoNewline
                    Write-Host "DANGER! " -ForegroundColor Red -NoNewline
                    Write-Host "OK to run " -NoNewline -ForegroundColor Cyan
                    Write-Host "``$expression``" -ForegroundColor Red -NoNewline
                    Write-Host "? (yes/no)" -NoNewline -ForegroundColor Cyan
                    if ($(Read-Host " ") -ne "yes") { return }
                    # Temporarily disable ansicon, if enabled
                    $ansiconSetting = $env:ANSICON
                    $env:ANSICON = $null
                    Invoke-Expression $expression *>&1 > $argsPath
                    $env:ANSICON = $ansiconSetting
                }
            }
        }
    }

    # Parse the args file registered for the command using the regex registered for the command
    $argumentCandidates = (Select-String $argsPath -Pattern $argsRegex |
        ForEach-Object {
            # The task name must be in the first capturing group
            $_.matches.groups[1].value }) |
            # Attempt to complete the supplied word using the parsed task names
            Where-Object { $_ -like "$wordToComplete*" } |
            Select-Object -Unique

    $switchCandidates = $null
    # Workaround [bug](https://github.com/PowerShell/PowerShell-Docs/issues/1979)
    #  Args starting with a hyphen aren't autocompleted. Start with a colon instead.
    $switchFormatString = ":-{0}"
    if ($leadingDotSlash) {
        # But only do the workaround when the wrapper function is invoked
        $switchFormatString = "-{0}"
    }
    if ($switchesRegex) {
        $switchCandidates = (Select-String $argsPath -Pattern $switchesRegex |
            ForEach-Object {
                $_.matches.groups[1].value }) |
                ForEach-Object { $switchFormatString -f $_ } |
                Where-Object { $_ -like "$wordToComplete*" }
    }

    ($argumentCandidates + $switchCandidates) |
        Sort-Object |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}

# Create helper functions for each command so that you don't have to use the leading ./ or .\
$script:helperFunctionTemplateBlock = {
    Param(
    [switch]$Talk, [switch]$NoTalk,
    [switch]$Log,  [switch]$NoLog,
    [switch]$Timer,[switch]$NoTimer)

    $commandName = $MyInvocation.MyCommand;

    $sw = [Diagnostics.Stopwatch]::StartNew()
    $args = $args -replace ":-", "-"  # <--Lousy "workaround" for args starting with a hyphen
    $outputPath = "$($env:TEMP)\$commandName-$($(Get-Location) -replace "[:\\/]", """).txt"

    $defaultOptions = ((Get-Content -ErrorAction Ignore ".\.argument-completer-registry.json" | ConvertFrom-Json).completableCommands | Where-Object name -match $commandName).funcDefaults;
    $options = @{
        log = $(!($NoLog.IsPresent) -and ($defaultOptions.logOutput -or $Log.IsPresent));
        talk = $(!($NoTalk.IsPresent) -and ($defaultOptions.talk -or $Talk.IsPresent));
        timer = $(!($NoTimer.IsPresent) -and ($defaultOptions.useTimer -or $Timer.IsPresent));
        useGlobal = $(!($defaultOptions) -or $defaultOptions.useGlobal);
    }

    $cmdToInvoke = "./$commandName $args"
    if ($options.useGlobal) {
        $cmdToInvoke = "$(Get-Command $commandName -All | Where-Object CommandType -eq Application | Select-Object -First 1) $args"
    }

    if ($options.log) {
        Invoke-Expression $($cmdToInvoke) | Tee-Object $outputPath
    }
    else {
        Invoke-Expression $($cmdToInvoke)
    }
    $result = $LASTEXITCODE -eq 0
    $message = "`"$commandName $args`" finished {0}" -f $(if($result){"successfully"}else{"with errors"})
    Write-Host "`n$message" -ForegroundColor Cyan
    $sw.Stop()
    if ($options.timer) {
        Write-Host "Total time:" -ForegroundColor Magenta -NoNewline
        $sw.Elapsed
    }
    if ($options.log) {
        Write-Host "View logs at:" -ForegroundColor Green
        Write-Host "`t$outputPath"
    }
    if ($options.talk) {
        Add-Type -AssemblyName System.Speech
        $synth = New-Object -TypeName System.Speech.Synthesis.SpeechSynthesizer
        try {
            $synth.SpeakAsync($message) | Out-Null
        }
        catch {
            Write-Host "[No audio device]: $message" -ForegroundColor Yellow
        }
    }
    Write-Host "`nReturning: " -NoNewline
    $result
}

Write-Host "`nEnabled " -NoNewLine
Write-Host "tab completion" -ForegroundColor Green -NoNewLine
Write-Host " and generated " -NoNewline
Write-Host "helper functions" -ForegroundColor Green -NoNewLine
Write-Host " for (" -NoNewLine
foreach($script:command in $commandsToComplete) {
    Write-Host " $script:command" -ForegroundColor Magenta -NoNewLine
    Set-Item -Path Function:$script:command -Value $script:helperFunctionTemplateBlock
}
Write-Host " )"
