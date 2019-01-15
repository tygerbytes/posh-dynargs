[CmdletBinding(SupportsShouldProcess=$true)]
param([switch]$Force)

$installDir = Split-Path $MyInvocation.MyCommand.Path -Parent

. $installDir\src\Utils.ps1

Add-PoshDynargsToProfile -Force:$Force
