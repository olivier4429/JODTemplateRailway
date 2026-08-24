# Quick smoke test for the JODConverter REST endpoint (PowerShell).
# Usage: .\scripts\test-convert.ps1 -SrcFile .\sample.docx -Format pdf

param(
    [string]$BaseUrl = "http://localhost:8080",
    [Parameter(Mandatory = $true)][string]$SrcFile,
    [string]$Format = "pdf"
)

if (-not (Test-Path $SrcFile)) {
    Write-Error "File not found: $SrcFile"
    exit 1
}

$OutFile = "converted.$Format"
$Uri = "$BaseUrl/lool/convert-to/$Format"

Write-Host "Converting $SrcFile to $Format via $BaseUrl ..."
Invoke-WebRequest -Uri $Uri -Method Post -Form @{ data = Get-Item $SrcFile } -OutFile $OutFile

Write-Host "OK -> $OutFile"
