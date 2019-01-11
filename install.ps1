param([switch]$WhatIf = $false, [switch]$Force = $false, [switch]$Verbose = $false)

$installDir = Split-Path $MyInvocation.MyCommand.Path -Parent

Import-Module $installDir\src\posh-dynargs.psd1

Add-PoshDynargsToProfile -WhatIf:$WhatIf -Force:$Force -Verbose:$Verbose
