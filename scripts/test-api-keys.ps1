# End-to-end test of the API_KEYS gate (PowerShell): builds the image, then
# spins up two containers in turn -- one with API_KEYS unset, one with two
# keys configured -- and checks every access-control case with curl.exe.
#
# Usage: .\scripts\test-api-keys.ps1 [-ImageName jodconverter-railway] [-HostPort 8080]
#
# Requires Docker Desktop running locally. Uses curl.exe explicitly (not
# the `curl` alias for Invoke-WebRequest) so -w/-o behave like real curl.

param(
    [string]$ImageName = "jodconverter-railway",
    [int]$HostPort = 8080
)

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "docker is required on PATH to run this test."
    exit 1
}

$BaseUrl = "http://localhost:$HostPort"
$ContainerName = "jodconverter-apikey-test"
$SampleFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $SampleFile -Value "API key gate smoke test" -Encoding utf8

$Script:PassCount = 0
$Script:FailCount = 0

function Remove-TestContainer {
    docker rm -f $ContainerName *> $null
}

function Wait-ForUp {
    $tries = 60
    while ($tries -gt 0) {
        $code = & curl.exe -sS -o NUL -w "%{http_code}" "$BaseUrl/swagger-ui/index.html" 2>$null
        if ($code -eq "200") { return }
        $tries--
        Start-Sleep -Seconds 2
    }
    Write-Host "Timed out waiting for $BaseUrl to come up." -ForegroundColor Red
    docker logs $ContainerName 2>&1 | Select-Object -Last 40
    throw "container did not become ready"
}

function Start-TestContainer {
    param([string[]]$ExtraArgs = @())
    Remove-TestContainer
    $dockerArgs = @("run", "-d", "--rm", "--name", $ContainerName, "-p", "${HostPort}:8080", "-e", "PORT=8080") + $ExtraArgs + @($ImageName)
    docker @dockerArgs | Out-Null
    Wait-ForUp
}

function Test-Case {
    param(
        [string]$Description,
        [string]$Method,
        [string]$Url,
        [string]$Expected,
        [string[]]$CurlArgs = @()
    )
    $allArgs = @("-sS", "-o", "NUL", "-w", "%{http_code}", "-X", $Method) + $CurlArgs + @($Url)
    $actual = & curl.exe @allArgs 2>$null
    if ($actual -eq $Expected) {
        Write-Host "PASS  $Description (got $actual)" -ForegroundColor Green
        $Script:PassCount++
    } else {
        Write-Host "FAIL  $Description (expected $Expected, got $actual)" -ForegroundColor Red
        $Script:FailCount++
    }
}

try {
    Write-Host "Building $ImageName ..."
    docker build -t $ImageName . | Out-Null

    Write-Host ""
    Write-Host "=== Case set 1: API_KEYS unset -> access must be UNRESTRICTED ==="
    Start-TestContainer
    Test-Case "conversion without any key"          "POST" "$BaseUrl/lool/convert-to/pdf" "200" @("-F", "data=@$SampleFile;filename=sample.txt")
    Test-Case "conversion with a random key anyway" "POST" "$BaseUrl/lool/convert-to/pdf" "200" @("-F", "data=@$SampleFile;filename=sample.txt", "-H", "X-Api-Key: anything")
    Test-Case "swagger-ui without a key"             "GET"  "$BaseUrl/swagger-ui/index.html" "200" @()
    Test-Case "api-docs without a key"               "GET"  "$BaseUrl/v3/api-docs" "200" @()

    Write-Host ""
    Write-Host "=== Case set 2: API_KEYS=key-a,key-b -> access must be GATED ==="
    Start-TestContainer -ExtraArgs @("-e", "API_KEYS=key-a,key-b")
    Test-Case "conversion with no key at all"              "POST" "$BaseUrl/lool/convert-to/pdf" "401" @("-F", "data=@$SampleFile;filename=sample.txt")
    Test-Case "conversion with a wrong key (header)"       "POST" "$BaseUrl/lool/convert-to/pdf" "401" @("-F", "data=@$SampleFile;filename=sample.txt", "-H", "X-Api-Key: nope")
    Test-Case "conversion with a wrong key (query param)"  "POST" "$BaseUrl/lool/convert-to/pdf?apiKey=nope" "401" @("-F", "data=@$SampleFile;filename=sample.txt")
    Test-Case "conversion with the 1st valid key (header)" "POST" "$BaseUrl/lool/convert-to/pdf" "200" @("-F", "data=@$SampleFile;filename=sample.txt", "-H", "X-Api-Key: key-a")
    Test-Case "conversion with the 2nd valid key (header)" "POST" "$BaseUrl/lool/convert-to/pdf" "200" @("-F", "data=@$SampleFile;filename=sample.txt", "-H", "X-Api-Key: key-b")
    Test-Case "conversion with a valid key (query param)"  "POST" "$BaseUrl/lool/convert-to/pdf?apiKey=key-a" "200" @("-F", "data=@$SampleFile;filename=sample.txt")
    Test-Case "swagger-ui still open without a key"        "GET"  "$BaseUrl/swagger-ui/index.html" "200" @()
    Test-Case "api-docs still open without a key"          "GET"  "$BaseUrl/v3/api-docs" "200" @()
}
finally {
    Remove-TestContainer
    Remove-Item -Path $SampleFile -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=================================="
Write-Host "PASS: $PassCount   FAIL: $FailCount"
if ($FailCount -gt 0) { exit 1 }
