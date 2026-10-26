# Starts the built site on IIS Express (Windows only) and checks that the localized page,
# the files it references and the bundles are served. Run after msbuild.
param([int]$Port = 8080)

$ErrorActionPreference = 'Stop'
$site = Join-Path (Split-Path $PSScriptRoot -Parent) 'MultiLangApp'
$iisExpress = Join-Path $env:ProgramFiles 'IIS Express\iisexpress.exe'
$baseUrl = "http://localhost:$Port"
$log = Join-Path ([IO.Path]::GetTempPath()) 'iisexpress.log'

function Get-Page([string]$path, [string]$language = 'en') {
    Invoke-WebRequest "$baseUrl$path" -Headers @{ 'Accept-Language' = $language } -UseBasicParsing
}

function Assert-PageText([string]$text, [string]$expected, [string]$what) {
    if (-not $text.Contains($expected)) { throw "$what does not contain '$expected'" }
    Write-Host "OK: $what contains '$expected'"
}

$started = Get-Date
$server = Start-Process $iisExpress -ArgumentList "/path:$site", "/port:$Port" -PassThru -RedirectStandardOutput $log
try {
    $deadline = (Get-Date).AddSeconds(60)
    while ($true) {
        try { $en = Get-Page '/'; break }
        catch {
            if ($server.HasExited -or (Get-Date) -gt $deadline) { Get-Content $log; throw }
            Start-Sleep -Seconds 2
        }
    }

    # The localized resources are the point of this sample.
    Assert-PageText $en.Content 'This is MultiLangApp' 'English page'
    Assert-PageText (Get-Page '/' 'ja').Content 'これは MultiLangApp だよ' 'Japanese page'

    # HomeController.Index writes an access log through log4net. Properties/AssemblyInfo.cs picks
    # Log4net.Debug.config or Log4net.Release.config; both name the file yyyy-MM-dd.log.
    $logDirs = (Join-Path $site 'my-log4net-log'), (Join-Path $site '..\..\LogFiles\my-log4net-azure-log')
    $written = Get-ChildItem $logDirs -File -Force -ErrorAction SilentlyContinue |
        Where-Object LastWriteTime -ge $started |
        Select-String -Pattern 'CurrentUICulture:' -SimpleMatch
    if (-not $written) { throw 'log4net did not write the access log' }
    foreach ($entry in $written) {
        if ($entry.Filename -notmatch '^\d{4}-\d{2}-\d{2}\.log$') { throw "Log file is not named yyyy-MM-dd.log: $($entry.Path)" }
        if ($entry.Line -match '\b\d{1,3}(\.\d{1,3}){3}\b|::1') { throw "Access log contains a client IP address: $($entry.Line)" }
    }
    Write-Host "OK: log4net wrote $($written[0].Path) without client IP addresses"

    # Every script and stylesheet the page references is served.
    $assets = [regex]::Matches($en.Content, '(?:src|href)="(/(?:Scripts|Content)/[^"]+)"') | ForEach-Object { $_.Groups[1].Value }
    if (-not $assets) { throw 'The page references no files under /Scripts or /Content' }
    foreach ($asset in $assets) {
        Get-Page $asset | Out-Null
        Write-Host "OK: $asset"
    }

    # Bundles go through the minifier (WebGrease) and report failures inside the response body.
    foreach ($bundle in '/bundles/jquery', '/bundles/jqueryval', '/bundles/bootstrap', '/bundles/modernizr', '/Content/css') {
        $body = (Get-Page $bundle).Content
        if ($body.Length -eq 0 -or $body.Contains('Minification failed')) { throw "$bundle is empty or failed to minify" }
        Write-Host "OK: $bundle ($($body.Length) chars)"
    }
}
finally {
    Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
}
