@{

# Script module or binary module file associated with this manifest.
ModuleToProcess = 'posh-dynargs.psm1'

# Version number of this module.
ModuleVersion = '0.1.0.5'

# ID used to uniquely identify this module
GUID = 'dab0538d-eaf9-4e2a-a924-e1781007ac00'

# Author of this module
Author = 'Ty Walls and contributors'

# Copyright statement for this module
Copyright = '(c) 2019 Ty Walls and contributors'

# Description of the functionality provided by this module
Description = 'posh-dynargs enables tab completion for commands whose arguments change depending on the current directory, e.g. a project-specific `build` command. It also generates helper functions for those commands, adding capabilities such as logging, timing, and audible alerts.'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.0'

# Functions to export from this module
FunctionsToExport = @(
    'Register-LocalArgumentCompleters',
    'Add-PoshDynargsToProfile'
)

# Cmdlets to export from this module
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @(
    'PoshDynargsSettings'
)

# Aliases to export from this module
AliasesToExport = @('??')

# Private data to pass to the module specified in RootModule/ModuleToProcess.
# This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{
        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('prompt', 'tab', 'tab-completion', 'tab-expansion', 'tabexpansion')

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/tygerbytes/posh-dynargs/blob/v0.1.0.5/LICENSE.txt'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/tygerbytes/posh-dynargs'

        # ReleaseNotes of this module
        ReleaseNotes = 'https://github.com/tygerbytes/posh-dynargs/blob/v0.1.0.5/CHANGELOG.md'
    }

}

}
