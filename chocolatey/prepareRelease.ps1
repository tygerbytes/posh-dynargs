param ($Remote = 'origin', [switch]$TagRelease)
Push-Location $PSScriptRoot

$nuspec = [xml](Get-Content poshdynargs.nuspec)
$version = $nuspec.package.metadata.version
$tag = "v$version"

function Write-Banner($msg) { Write-Host "> $msg" -ForegroundColor Green }
function Write-Step($msg) { Write-Host "|  $msg" -ForegroundColor Magenta }

Write-Banner 'Checking tags'
if ($TagRelease) {
    Write-Step "Tagging release $tag"
    git tag --force --annotate --sign $tag -m "Release $tag"
    git push --force $Remote $tag
}
elseif (!$(git ls-remote $Remote $tag)) {
    Write-Warning "'$Remote/$tag' not found! Use -TagRelease to create tag at HEAD."
    return
}
else {
    Write-Step "Tag exists on remote: origin/$tag"
}

Write-Banner "Downloading source zipball"
$zipBallFileName = "posh-dynargs-src-v$version.zip"
Invoke-WebRequest -Uri "https://github.com/tygerbytes/posh-dynargs/zipball/v$version" -UseBasicParsing -OutFile $zipBallFileName
Write-Step "$zipBallFileName"

Write-Banner 'Creating chocolatey package'
choco pack poshdynargs.nuspec

Write-Banner 'Local choco package install'
if ((Read-Host "Install the package locally? (y/n)") -eq "y") {
    choco install -f -y poshdynargs -pre --version=$version -s "'.;chocolatey'"
}

Pop-Location

Write-Banner 'Done!'
