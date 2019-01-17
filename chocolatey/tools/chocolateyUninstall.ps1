$ErrorActionPreference = 'Stop'

$moduleName = 'posh-dynargs'
$sourcePath = Join-Path -Path $env:ProgramFiles -ChildPath "WindowsPowerShell\Modules\$moduleName"

Write-Verbose "Removing all version of '$moduleName' from '$sourcePath'."
Remove-Item -Path $sourcePath -Recurse -Force -ErrorAction SilentlyContinue
