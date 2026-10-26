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

# Version headers only help fingerprinting. nosniff makes browsers trust Content-Type,
# so scripts and stylesheets must also be served with their real type.
$script:headerChecks = 0
function Assert-SafeResponse($response, [string]$what, [string]$expectedType) {
    foreach ($name in 'X-AspNet-Version', 'X-AspNetMvc-Version', 'X-Powered-By') {
        if ($response.Headers.ContainsKey($name)) { throw "$what sends ${name}: $($response.Headers[$name])" }
    }
    $nosniff = "$($response.Headers['X-Content-Type-Options'])"
    if ($nosniff -ne 'nosniff') { throw "$what sends X-Content-Type-Options '$nosniff', expected 'nosniff'" }
    $type = "$($response.Headers['Content-Type'])"
    if (-not $type.Contains($expectedType)) { throw "$what is served as '$type', expected '$expectedType'" }
    $script:headerChecks++
}

function Get-Resource([string]$file, [string]$name) {
    $resx = [xml](Get-Content (Join-Path $site "Resources\Lang\$file") -Raw -Encoding utf8)
    ($resx.root.data | Where-Object name -eq $name).value
}

# Runs the inline script of the page in Node with a stub jQuery and returns the text showText() sets.
function Get-ShownText([string]$html) {
    $script = [regex]::Matches($html, '<script>([\s\S]*?)</script>') |
        ForEach-Object { $_.Groups[1].Value } | Where-Object { $_.Contains('showText') } | Select-Object -First 1
    if (-not $script) { throw 'The page has no inline script with showText' }
    $scriptFile = New-TemporaryFile
    $runnerFile = Join-Path ([IO.Path]::GetTempPath()) 'show-text.js'
    Set-Content $scriptFile $script -Encoding utf8 -NoNewline
    Set-Content $runnerFile -Encoding utf8 -Value @'
const vm = require('vm');
let shown;
vm.runInNewContext(require('fs').readFileSync(process.argv[2], 'utf8') + '\n;showText();',
    { $: () => ({ text: (value) => { shown = value; } }) });
process.stdout.write(Buffer.from(String(shown), 'utf8').toString('base64'));
'@
    $base64 = node $runnerFile $scriptFile
    if ($LASTEXITCODE) { throw "The inline script failed in Node:`n$script" }
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($base64))
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
    Assert-SafeResponse $en '/' 'text/html'
    Assert-PageText (Get-Page '/' 'ja').Content 'これは MultiLangApp だよ' 'Japanese page'

    # The button text set from JavaScript must be the resource value itself, not HTML-encoded.
    foreach ($case in @{ Language = 'en'; Resx = 'Localize.en.resx' }, @{ Language = 'ja'; Resx = 'Localize.resx' }) {
        $expected = Get-Resource $case.Resx 'String5'
        $shown = Get-ShownText (Get-Page '/' $case.Language).Content
        if ($shown -cne $expected) { throw "showText() ($($case.Language)) shows '$shown', expected '$expected'" }
        Write-Host "OK: showText() ($($case.Language)) shows '$shown'"
    }

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
        Assert-SafeResponse (Get-Page $asset) $asset ($asset.EndsWith('.css') ? 'text/css' : 'javascript')
        Write-Host "OK: $asset"
    }

    # Bundles go through the minifier (WebGrease) and report failures inside the response body.
    foreach ($bundle in '/bundles/jquery', '/bundles/jqueryval', '/bundles/bootstrap', '/bundles/modernizr', '/Content/css') {
        $response = Get-Page $bundle
        $body = $response.Content
        if ($body.Length -eq 0 -or $body.Contains('Minification failed')) { throw "$bundle is empty or failed to minify" }
        Assert-SafeResponse $response $bundle ($bundle -eq '/Content/css' ? 'text/css' : 'javascript')
        Write-Host "OK: $bundle ($($body.Length) chars)"
    }
    Write-Host "OK: $script:headerChecks responses send no version headers, send nosniff and have matching content types"
}
finally {
    Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
}
