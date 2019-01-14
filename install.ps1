param([switch]$WhatIf = $false, [switch]$Force = $false, [switch]$Verbose = $false)

$installDir = Split-Path $MyInvocation.MyCommand.Path -Parent

. $installDir\src\Utils.ps1

Add-PoshDynargsToProfile -WhatIf:$WhatIf -Force:$Force -Verbose:$Verbose
