$ErrorActionPreference = 'Stop'

$moduleName = 'posh-dynargs'
Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
