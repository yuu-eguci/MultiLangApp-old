# Applies Web.Release.config the same way publishing does (TransformWebConfig only, nothing is deployed)
# and checks the production Web.config. Windows only, because it needs the Visual Studio web targets.
$ErrorActionPreference = 'Stop'
$project = Join-Path (Split-Path $PSScriptRoot -Parent) 'MultiLangApp'

msbuild (Join-Path $project 'MultiLangApp.csproj') /t:TransformWebConfig /p:Configuration=Release /v:minimal /nologo
if ($LASTEXITCODE) { exit $LASTEXITCODE }

$path = Join-Path $project 'obj\Release\TransformWebConfig\transformed\Web.config'
$compilation = ([xml](Get-Content $path -Raw)).configuration.'system.web'.compilation
if ($compilation.HasAttribute('debug')) {
    throw "Release Web.config still sets compilation debug=`"$($compilation.debug)`""
}
Write-Host "OK: Release Web.config has no compilation debug attribute ($path)"
