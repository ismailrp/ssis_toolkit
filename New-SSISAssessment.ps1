param(
    [string]$ConfigPath = ".\config.ps1",
    [string]$AssessmentId = ""
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

if (!(Test-Path $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
}

. $ConfigPath

if (!$Config) {
    throw "Config variable `$Config not found in $ConfigPath"
}

if ([string]::IsNullOrWhiteSpace($AssessmentId)) {
    $AssessmentId = "EVSET-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

$root = Join-Path $Config.OutputRoot $AssessmentId
$dirs = @(
    "00_manifest",
    "01_static_packages",
    "01_static_packages\ispac_original",
    "01_static_packages\extracted",
    "02_ssisdb_inventory",
    "03_runtime",
    "04_messages",
    "05_sqlserver_optional"
)

if (!(Test-Path $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
foreach ($d in $dirs) {
    New-Item -ItemType Directory -Path (Join-Path $root $d) -Force | Out-Null
}

$logPath = Join-Path $root "collector.log"

function Write-Log {
    param([string]$Level, [string]$Message)
    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Write-Host $line
    Add-Content -Path $logPath -Value $line
}

Write-Log "INFO" "Assessment started: $AssessmentId"
Write-Log "INFO" "Output: $root"

$collectorPath = Join-Path $PSScriptRoot "Collect-SSISEvidence.ps1"
if (!(Test-Path $collectorPath)) {
    throw "Collector not found: $collectorPath"
}

& $collectorPath -ConfigPath $ConfigPath -OutputPath $root

Write-Log "INFO" "Assessment completed: $AssessmentId"
Write-Host ""
Write-Host "SUCCESS :: Evidence folder: $root"
