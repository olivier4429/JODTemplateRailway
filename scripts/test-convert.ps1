# Quick smoke test for the JODConverter REST endpoint (PowerShell).
# Usage: .\scripts\test-convert.ps1 -SrcFile .\sample.docx -Format pdf
# Usage: .\scripts\test-convert.ps1 -SrcFile .\sample.docx -Format pdf -ApiKey my-secret-key
#
# -ApiKey is only needed if the service was started with API_KEYS set --
# see the README.

param(
    [string]$BaseUrl = "http://localhost:8080",
    [Parameter(Mandatory = $true)][string]$SrcFile,
    [string]$Format = "pdf",
    [string]$ApiKey = ""
)

if (-not (Test-Path $SrcFile)) {
    Write-Error "File not found: $SrcFile"
    exit 1
}

$OutFile = "converted.$Format"
$Uri = "$BaseUrl/lool/convert-to/$Format"

$RequestArgs = @{
    Uri     = $Uri
    Method  = "Post"
    Form    = @{ data = Get-Item $SrcFile }
    OutFile = $OutFile
}
if ($ApiKey) {
    $RequestArgs.Headers = @{ "X-Api-Key" = $ApiKey }
}

Write-Host "Converting $SrcFile to $Format via $BaseUrl ..."
Invoke-WebRequest @RequestArgs

Write-Host "OK -> $OutFile"
