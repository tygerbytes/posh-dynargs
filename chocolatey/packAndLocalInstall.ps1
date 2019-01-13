param ($Remote = 'origin', [switch]$Force)
Push-Location $PSScriptRoot

$nuspec = [xml](Get-Content poshdynargs.nuspec)
$version = $nuspec.package.metadata.version
$tag = "v$version"

if ($Force) {
    git tag -f $tag
    git push -f $Remote $tag
}
elseif (!$(git ls-remote $Remote $tag)) {
    Write-Warning "'$Remote/$tag' not found! Use -Force to create tag at HEAD."
    return
}

choco pack poshdynargs.nuspec
choco install -f -y poshdynargs -pre --version=$version -s "'.;chocolatey'"

Pop-Location
