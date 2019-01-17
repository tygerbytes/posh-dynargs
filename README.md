# posh-dynargs

`posh-dynargs` is a PowerShell module that enables tab completion for commands whose arguments change depending on the current directory, e.g. a project-specific `build` command. It also generates helper functions for those commands, adding capabilities such as logging, timing, and audible alerts.

## Background and Overview

Many projects rely on commands like `build`, `ci`, `make`, `test`, etc. Each of these commands has its own set of possible arguments, often dozens of them, and their usage and interface can vary between projects and certainly between organizations.

`posh-dynargs` makes **tab completion** possible for these disparate commands. Possible arguments are determined on the fly, so even when arguments change or new ones are added, they are instantly tab completable. See [TAB COMPLETION](#tab-completion).

Additionally, a **helper function** of the same name is generated for each command. Apart from making it possible to invoke the command without the leading `.\` or `./`, it enables additional features such as logging the output. See [HELPER FUNCTIONS](#helper-functions).

A project that wants to use `posh-dynargs` only has to include a file called `.argument-completer-registry.json` at the root of the project. This file is a registry that describes the completable commands, how to find their arguments, and how to customize the helper functions. See [ARGUMENT COMPLETER REGISTRY](#argument-completer-registry).

`posh-dynargs` was inspired by [posh-git](https://github.com/dahlbyk/posh-git). A special thanks to [Keith Dahlby](https://github.com/dahlbyk) and friends.

## Installing posh-dynargs

The easiest way to install posh-dynargs is via Chocolatey. If you don't have Chocolatey yet, install it from the [Chocolately Install page](https://chocolatey.org/install).

With Chocolatey installed, execute the following command to install posh-dynargs:

```powershell
choco install poshdynargs
```

## TAB COMPLETION

To enable tab completion for a project-specific command, add it to the argument completer registry, including a few hints regarding where to find and parse the arguments to be completed.

### KNOWN SCRIPT TYPES

posh-dynargs knows how to extract arguments from Cake scripts, PSake scripts, and Make files. In those cases, you only have to register the location and type of the script. posh-dynargs figures out the rest.

For a **Cake** script, for example, the registry entry might look like this:

```json
{
    "name": "build",
    "argsPath": "./build/ci.cake",
    "type": "cake",
    "funcDefaults": {
        "logOutput": true,
        "talk": true,
    }
}
```

This entry tells posh-dynargs that the command to invoke is `build`, and it is dealing with a Cake script that lives at `./build/ci.cake`. It will parse the script for possible arguments the second you enter `build{TAB}`. On a reasonably performant computer, this is nearly instantaneous.

### CUSTOM SCRIPTS

You likely have other scripts that posh-dynargs doesn't know how to parse. In such a case, register it as a custom command and provide a regex to guide posh-dynargs to the correct arguments.

Here's a sample registry entry for a custom command called "scrape":

```json
{
    "name": "scrape",
    "argsPath": "./tools/scrape.ps1",
    "type": "custom",
    "regex": "^Task ([A-Z][^ ]+)"
}
```

### BINARY COMMANDS ☠

What about binary commands that aren't parsable? Those commands typically ship with a switch like --help from which we can extract the arguments to complete. posh-dynargs can execute this help command and cache the help text to make future tab completion faster (and safer).

Sample registry entry for an unparsable binary command:

```json
{
    "name": "test",
    "helpCommand": "--help",
    "type": "custom",
    "regex": "(--[a-z]+=?)"
}
```

### DANGER, WILL ROBINSON 🤖

Executing the "help command" adds a security risk to posh-dynargs, because we leave the relative safety of simply parsing text and begin executing code. The following precautions have been taken to help mitigate this risk:

* Only allow executing the registered command
* Only allow executing a whitelisted set of help arguments:
  * help
  * --help
  * -h
  * --list
  * -l
  * /?
  * -?
* Additionally, before executing the command, the user is prompted with a frightening message, to which they must respond "yes", or the expression will not be executed:

```text
    >>> DANGER! OK to run `./test --help`? (yes/no) :
```

So where do we add these argument completer registry entries? You will create a file at the root of your project called `.argument-completer-registry.json`. See [ARGUMENT COMPLETER REGISTRY](#argument-completer-registry).

### LEADING DASH POWERSHELL BUG

As of January, 2019, there is a PowerShell bug that prevents arguments with a leading dash from being completed. E.g. `build -stuff` would fail. The workaround used by posh-dynargs is to preface those arguments with a leading colon `:`. Rather than running `build -stuff`, you would run `build :-stuff`. The helper function then strips off the leading colon. This is undesirable. Hopefully the bug will be fixed soon.

**ISSUE**: PowerShell/PowerShell-Docs#1979

## HELPER FUNCTIONS

A helper function of the same name is generated for for each command. Apart from making it possible to invoke the command without the leading `.\` or `./`, it enables the following additional features:

* Logging of command output.
* An audible prompt when the command finishes, which is great for long-running commands.
* Timing the command.

Each of these features is optional and configurable in the argument completer registry, using options supplied to funcDefaults. See [ARGUMENT COMPLETER REGISTRY](#argument-completer-registry) for the full syntax.

## ARGUMENT COMPLETER REGISTRY

The argument completer file is called `.argument-completer-registry.json` and should be placed at the root of the project.

This JSON file is a registry of the project's completable commands. It controls how each command's arguments are discovered. It also configures options for the generated helper functions.

**SAMPLE `.argument-completer-registry.json`**

```json
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
            "name": "test",
            "helpCommand": "--help",
            "type": "custom",
            "regex": "(--[a-z]+=?)"
        }
    ]
}
```

### DESCRIPTION OF ATTRIBUTES

| attribute | description |
| --------- | ----------- |
| name | The name of the command to be completed.
| argsPath | The path to the script containing the arguments to be parsed. |
| helpCommand | For compiled tools. Parse the arguments from the tool's help output. Supply something like "--help" or "-h". The help text output will be cached in `$env:TEMP`. |
| type | The type of script being parsed. Natively-supported types are "cake", "make", and "psake". |
| regex | (For custom types) The regular expression used to extract the task names from "argsPath" or the output of "helpCommand". The first capturing group must contain the task name. |
| funcDefaults | Sets defaults for the generated helper function. |

Options for `funcDefaults`

| attribute | description |
| --------- | ----------- |
| logOutput | true or false. If true, log command output to the TEMP directory. Note that you will lose color output. |
| talk | true or false. If true, audibly communicate a failed or successful command invocation. |
| useTimer | true or false. If true, display elapsed time when the command finishes. |
| useGlobal | true or false. If true, invoke the command found in your PATH rather than the local directory. |

### DISCUSSION

In the above file sample we can assume that there is an executable `.\build`, a `.\scrape`, and a `.\test` in the same directory alongside `.argument-completer-registry.json`. This simple registry tells the argument completer where the actual script is located and how to parse it.

For example, the "build" command above will execute the Cake script located in `./build/ci.cake`. The "type" is listed as "cake". The argument completer knows how to parse Cake files and extract the arguments, which are then used for tab completion.

When you are in this directory and you type build, PowerShell will find the registered argument completer and invoke the associated script block. The script block will load `./.argument-completer-registry.json` and find the "build" command. Then it parses the Cake script using the path provided in the `.json` file, and uses that to provide tab completion. This happens every time you run the build command, but it happens extremely fast. There is typically no lag.

## USAGE

You need to import the posh-dynargs module into your PowerShell session to use it. This is done with the command `Import-Module posh-dynargs`. Once imported, run `Add-PoshDynargsToProfile` so that posh-dynargs is imported every time PowerShell starts. If you install posh-dynargs with Chocolately, this should already be done for you.

## PERFORMANCE

posh-dynargs piggybacks on top of the PowerShell prompt. Every time prompt is invoked, `Register-LocalArgumentCompleters` is also invoked.

`Register-LocalArgumentCompleters` will process `.argument-completer-registry.json` if it exists. This involves registering each argument completer and creating a helper function. If you experience a slowdown, it will be here. Once registered, the process will not repeat until the directory changes.

To enable timing of the `Register-LocalArgumentCompleters` function, set `$PoshDynargsSettings.EnableTiming = $true`

## UNDER THE HOOD

As noted in [PERFORMANCE](#performance), posh-dynargs works by attaching itself to PowerShell's prompt function. Every time the prompt function is invoked, a so is the main posh-dynargs function.

How does this work? (I'm not happy with the current implementation, and it's likely to change.) If you're using posh-git, the function is attached to and executed with `$GitPromptSettings.DefaultPromptPrefix`. If you aren't using posh-git, the prompt is replaced with a custom one which just so happens to run `Register-LocalArgumentCompleters`.

## Based on work by

* Ty Walls, https://www.tygertec.com/
* Keith Dahlby, http://solutionizing.net/
* Mark Embling, http://www.markembling.info/
* Jeremy Skinner, http://www.jeremyskinner.co.uk/
