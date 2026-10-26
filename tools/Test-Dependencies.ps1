# Checks that packages.config, MultiLangApp.csproj, Web.config and the files actually served
# (Scripts/, Content/, fonts/) all point at the same package versions.
# Run after `nuget restore`. Exits with 1 when anything has drifted.
param([string]$Root = (Split-Path $PSScriptRoot -Parent))

$ErrorActionPreference = 'Stop'
$project = Join-Path $Root 'MultiLangApp'
$packagesDir = Join-Path $Root 'packages'
$servedDirs = 'Scripts', 'Content', 'fonts'
# Served files that are part of this app, not of a package.
$ownFiles = @('content/site.css')
$errors = [System.Collections.Generic.List[string]]::new()

function Get-RelativeKey([string]$base, [string]$path) {
    [IO.Path]::GetRelativePath($base, $path).Replace('\', '/').ToLowerInvariant()
}

# Text files are compared without BOM and CR, because git normalizes line endings on checkout.
function Get-ContentHash([string]$path) {
    $bytes = [IO.File]::ReadAllBytes($path)
    if ([Array]::IndexOf($bytes, [byte]0) -lt 0) {
        $text = [Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF).Replace("`r", '')
        $bytes = [Text.Encoding]::UTF8.GetBytes($text)
    }
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
}

$packages = ([xml](Get-Content (Join-Path $project 'packages.config') -Raw)).packages.package
$packageFolders = $packages | ForEach-Object { "$($_.id).$($_.version)" }

# 1. Every ..\packages\<id>.<version>\ path in the csproj is listed in packages.config.
$csprojPath = Join-Path $project 'MultiLangApp.csproj'
$csprojText = Get-Content $csprojPath -Raw
foreach ($folder in [regex]::Matches($csprojText, '\.\.\\packages\\([^\\]+)\\') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique) {
    if ($packageFolders -notcontains $folder) {
        $errors.Add("csproj uses packages\$folder, but packages.config does not list that version")
    }
}

# 2. Each package reference resolves after restore and its Version= matches the restored assembly.
$ns = @{ m = 'http://schemas.microsoft.com/developer/msbuild/2003' }
$assemblyVersions = @{}
foreach ($ref in (Select-Xml -Path $csprojPath -XPath '//m:Reference[m:HintPath]' -Namespace $ns).Node) {
    $dll = Join-Path $project ($ref.HintPath.Replace('\', [IO.Path]::DirectorySeparatorChar))
    if (-not (Test-Path $dll)) {
        $errors.Add("HintPath does not exist after restore: $($ref.HintPath)")
        continue
    }
    $name = [Reflection.AssemblyName]::GetAssemblyName($dll)
    $assemblyVersions[$name.Name] = $name.Version
    if ($ref.Include -match 'Version=([\d.]+)' -and [version]$Matches[1] -ne $name.Version) {
        $errors.Add("csproj says $($name.Name) Version=$($Matches[1]), but $($ref.HintPath) is $($name.Version)")
    }
}

# 3. Web.config binding redirects point at the referenced assembly versions.
$asm = @{ a = 'urn:schemas-microsoft-com:asm.v1' }
foreach ($dep in (Select-Xml -Path (Join-Path $project 'Web.config') -XPath '//a:dependentAssembly' -Namespace $asm).Node) {
    $name = $dep.assemblyIdentity.name
    if (-not $assemblyVersions.ContainsKey($name)) { continue }
    $expected = $assemblyVersions[$name].ToString()
    $redirect = $dep.bindingRedirect
    if ($redirect.newVersion -ne $expected -or -not $redirect.oldVersion.EndsWith("-$expected")) {
        $errors.Add("Web.config redirects $name to $($redirect.oldVersion) -> $($redirect.newVersion), but the referenced assembly is $expected")
    }
}

# 4. Served files are exactly the content of the listed packages (no stale, edited or missing files).
$packageFiles = @{}
foreach ($folder in $packageFolders) {
    $dir = Join-Path $packagesDir $folder
    if (-not (Test-Path $dir)) {
        $errors.Add("packages\$folder is missing. Run nuget restore first")
        continue
    }
    $contentDir = Get-ChildItem $dir -Directory | Where-Object Name -eq 'content' | Select-Object -First 1
    if (-not $contentDir) { continue }
    foreach ($file in Get-ChildItem $contentDir.FullName -File -Recurse) {
        $packageFiles[(Get-RelativeKey $contentDir.FullName $file.FullName)] = @{ Package = $folder; Path = $file.FullName }
    }
}
$servedFiles = @{}
foreach ($dir in $servedDirs) {
    foreach ($file in Get-ChildItem (Join-Path $project $dir) -File -Recurse) {
        $servedFiles[(Get-RelativeKey $project $file.FullName)] = $file.FullName
    }
}
foreach ($key in $servedFiles.Keys | Sort-Object) {
    if ($ownFiles -contains $key) { continue }
    if (-not $packageFiles.ContainsKey($key)) {
        $errors.Add("$key is served, but no package in packages.config contains it")
    }
    elseif ((Get-ContentHash $servedFiles[$key]) -ne (Get-ContentHash $packageFiles[$key].Path)) {
        $errors.Add("$key differs from the copy in packages\$($packageFiles[$key].Package)")
    }
}
foreach ($key in $packageFiles.Keys | Sort-Object) {
    if ($servedDirs -contains $key.Split('/')[0] -and -not $servedFiles.ContainsKey($key)) {
        $errors.Add("$key from packages\$($packageFiles[$key].Package) is not in the project")
    }
}

# 5. The csproj lists exactly the served files that exist on disk.
$items = (Select-Xml -Path $csprojPath -XPath '//m:Content/@Include | //m:None/@Include' -Namespace $ns).Node.Value |
    ForEach-Object { $_.Replace('\', '/').ToLowerInvariant() } |
    Where-Object { $servedDirs -contains $_.Split('/')[0] }
foreach ($item in $items) {
    if (-not $servedFiles.ContainsKey($item)) { $errors.Add("csproj lists $item, but the file does not exist") }
}
foreach ($key in $servedFiles.Keys) {
    if ($items -notcontains $key) { $errors.Add("$key exists, but the csproj does not list it") }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Host "ERROR: $_" }
    exit 1
}
Write-Host "OK: packages.config, csproj, Web.config and served files agree ($($packages.Count) packages)"
