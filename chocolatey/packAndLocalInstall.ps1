param ($Remote = 'origin', [switch]$Force)
Push-Location $PSScriptRoot

$nuspec = [xml](Get-Content poshdynargs.nuspec)
$version = $nuspec.package.metadata.version
$tag = "v$version"

if ($Force) {
    git tag --force --annotate --sign $tag -m "Release $tag"
    git push --force $Remote $tag
}
elseif (!$(git ls-remote $Remote $tag)) {
    Write-Warning "'$Remote/$tag' not found! Use -Force to create tag at HEAD."
    return
}

Invoke-WebRequest -Uri "https://github.com/tygerbytes/posh-dynargs/zipball/v$version" -UseBasicParsing -OutFile "posh-dynargs-v$version.zip"

choco pack poshdynargs.nuspec

if ((Read-Host "Install the package? (y/n)") -eq "y") {
    choco install -f -y poshdynargs -pre --version=$version -s "'.;chocolatey'"
}

Pop-Location
