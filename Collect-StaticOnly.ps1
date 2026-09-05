param(
    [string]$ConfigPath = ".\config.ps1",
    [string]$AssessmentId = ""
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

if (!(Test-Path $ConfigPath)) { throw "Config file not found: $ConfigPath" }
. $ConfigPath
$Config.CollectStatic = $true
$Config.CollectRuntime = $false
$Config.CollectMessages = $false
$Config.CollectQueryStore = $false

if ([string]::IsNullOrWhiteSpace($AssessmentId)) {
    $AssessmentId = "EVSET-STATIC-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

$root = Join-Path $Config.OutputRoot $AssessmentId
$dirs = @("00_manifest","01_static_packages","01_static_packages\ispac_original","01_static_packages\extracted","02_ssisdb_inventory","03_runtime","04_messages","05_sqlserver_optional")
foreach ($d in $dirs) { New-Item -ItemType Directory -Path (Join-Path $root $d) -Force | Out-Null }

$collectorPath = Join-Path $PSScriptRoot "Collect-SSISEvidence.ps1"
& $collectorPath -ConfigPath $ConfigPath -OutputPath $root
Write-Host "SUCCESS :: Static evidence folder: $root"
