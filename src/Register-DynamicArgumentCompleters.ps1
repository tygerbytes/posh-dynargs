param(
    [Parameter(Mandatory=$true)]
    [String[]]$commandsToComplete)
<#

.SYNOPSIS
Register tab completion for custom commands that change depending on the current directory.
Author: Ty Walls (https://twitter.com/tygertec)
Website: https://www.tygertec.com

.DESCRIPTION
Many projects have CI/CD commands like build, ci, make, test, etc.
Each of these commands has their own set of possible arguments, often dozens of them,
and their usage and interface can vary from between projects and certainly between organizations.

The idea here is to place a JSON file called ".argument-completer-registry.json" at the root
of each project directory, which is often a Git repo. Here is a sample:

# Sample .argument-completer-registry.json
{
    "completableCommands": [
        {
            "name": "build",
            "argsPath": "./build/ci.cake",
            "type": "cake",
            "funcDefaults": {
                "logOutput": true,
                "talk": true,
                "useTimer": true,
                "useGlobal": false,
            }
        },
        {
            "name": "scrape",
            "argsPath": "./tools/scrape.ps1",
            "type": "custom",
            "regex": "^Task ([A-Z][^ ]+)"
        },
        {
            "name": "test|test.cmd",
            "helpCommand": "--help",
            "type": "custom",
            "regex": "(--[a-z]+=?)"
         }
    ]
}

# Description of object attributes used in the file:

name:         The name of the command to be completed.
              Use alternation to specify multiple command names,
              in case they are aliases for the same command. E.g. "build|ci|make".

argsPath:     The path to the script containing the arguments to be parsed.

helpCommand:  For compiled tools. Parse the arguments from the tool's help output.
              Supply something like "--help" or "-h".
              Note that the command's output will be cached in $env:TEMP.

type:         The type of script being parsed. See the switch statement below for natively-supported types.

regex:        (For custom types) The regular expression used to extract the task names
              from "argsPath" or the output of "helpCommand". The first capturing group
              must contain the task name.

funcDefaults:  Sets defaults for the generated wrapper function.

    logOutput: true or false. If true, log command output to the TEMP directory.
               Note that you will lose color output.

    talk:     true or false. If true, audibly communicate a failed or successfully
              command invocation.

    useTimer:  true or false. If true, display elapsed time when command finishes.

    useGlobal: true or false. If true, use the command found in your PATH rather than the local directory.



In the above file sample we can assume that there is an executable .\build, a .\scrape, and a .\test
in the same directory alongside .argument-completer-registry.json. This simple "registry" tells
the argument completer where the actual script is located and how to parse it.

For example, the "build" command above will execute the Cake script located in ./build/ci.cake.
The "type" is listed as "cake". The argument completer knows how to parse Cake files and
extract the arguments, which are then used for tab completion.

When you are in this directory and you type build, PowerShell will find the registered argument completer
and invoke the associated script block. The script block will load ./.argument-completer-registry.json
and find the "build" command. Then it parses the Cake script using the path provided in the .json file,
and uses that to provide tab completion. This happens every time you run the build command, but it happens
extremely fast. There is typically no lag.

.PARAMETER commandsToComplete
An array of strings representing the commands to register for tab completion.

.EXAMPLE
Register-DynamicArgumentCompleters -commandsToComplete @("build", "ci", "test")

.NOTES
Just to reiterate, there will be no tab completion without a .argument-completer-registry.json
file in the directory containing the commands. See DESCRIPTION for more details.

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
$script:helperFunctionTemplate = @'
function global:__NAME__ {
    Param(
    [switch]$Talk, [switch]$NoTalk,
    [switch]$Log,  [switch]$NoLog,
    [switch]$Timer,[switch]$NoTimer)

    $sw = [Diagnostics.Stopwatch]::StartNew()
    $args = $args -replace ":-", "-"  # <--Lousy "workaround" for args starting with a hyphen
    $outputPath = "$($env:TEMP)\__NAME__-$($(Get-Location) -replace "[:\\/]", """).txt"

    $defaultOptions = ((Get-Content -ErrorAction Ignore ".\.argument-completer-registry.json" | ConvertFrom-Json).completableCommands | Where-Object name -match __NAME__).funcDefaults;
    $options = @{
        log = $(!($NoLog.IsPresent) -and ($defaultOptions.logOutput -or $Log.IsPresent));
        talk = $(!($NoTalk.IsPresent) -and ($defaultOptions.talk -or $Talk.IsPresent));
        timer = $(!($NoTimer.IsPresent) -and ($defaultOptions.useTimer -or $Timer.IsPresent));
        useGlobal = $(!($defaultOptions) -or $defaultOptions.useGlobal);
    }

    $cmdToInvoke = "./__NAME__ $args"
    if ($options.useGlobal) {
        $cmdToInvoke = "$(Get-Command __NAME__ -All | Where-Object CommandType -eq Application | Select-Object -First 1) $args"
    }

    if ($options.log) {
        Invoke-Expression $($cmdToInvoke) | Tee-Object $outputPath
    }
    else {
        Invoke-Expression $($cmdToInvoke)
    }
    $result = $LASTEXITCODE -eq 0
    $message = "`"__NAME__ $args`" finished {0}" -f $(if($result){"successfully"}else{"with errors"})
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
'@

Write-Host "`nEnabled " -NoNewLine
Write-Host "tab completion" -ForegroundColor Green -NoNewLine
Write-Host " and generated " -NoNewline
Write-Host "helper functions" -ForegroundColor Green -NoNewLine
Write-Host " for (" -NoNewLine
foreach($script:command in $commandsToComplete) {
    Write-Host " $script:command" -ForegroundColor Magenta -NoNewLine
    Invoke-Expression $($script:helperFunctionTemplate -replace "__NAME__", $script:command)
}
Write-Host " )"
