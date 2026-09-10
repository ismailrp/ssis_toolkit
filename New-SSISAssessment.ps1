param(
    [string]$ConfigPath = ".\config.ps1",
    [string]$AssessmentId = "",
    [int]$LookbackDays = -1,
    [int]$MaxExecutions = -1,
    [string]$StartTime = "",
    [string]$EndTime = "",
    [switch]$AdditionalEvidence,
    [switch]$StaticOnly
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

if (!(Test-Path -LiteralPath $ConfigPath)) { throw "Config file not found: $ConfigPath" }
. (Resolve-Path -LiteralPath $ConfigPath).Path
if (!$Config) { throw "Config variable `$Config not found in $ConfigPath" }

if ($LookbackDays -eq 0 -or $LookbackDays -lt -1 -or $MaxExecutions -lt -1) {
    throw "LookbackDays must be -1 or positive; MaxExecutions must be -1, 0, or positive."
}
if ($LookbackDays -gt 0) { $Config.LookbackDays = $LookbackDays }
if ($MaxExecutions -ge 0) { $Config.MaxExecutions = $MaxExecutions }
if ($StaticOnly) {
    $Config.CollectStatic = $true
    $Config.CollectRuntime = $false
    $Config.CollectMessages = $false
    $Config.CollectQueryStore = $false
}
if ($AdditionalEvidence) { $Config.CollectAdditionalEvidence = $true }

if ([string]::IsNullOrWhiteSpace($AssessmentId)) {
    $prefix = if ($StaticOnly) { "EVSET-STATIC-" } else { "EVSET-" }
    $AssessmentId = $prefix + (Get-Date -Format "yyyyMMdd-HHmmss")
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
    "05_sqlserver_optional",
    "06_additional_evidence"
)

if (!(Test-Path -LiteralPath $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
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
if ($StartTime -or $EndTime) { Write-Log "INFO" "Explicit runtime window: $StartTime through $EndTime" }
Write-Log "INFO" ("Runtime cap: " + $(if ([int]$Config.MaxExecutions -eq 0) { "unlimited" } else { [int]$Config.MaxExecutions }))

$collectorPath = Join-Path $PSScriptRoot "Collect-SSISEvidence.ps1"
if (!(Test-Path -LiteralPath $collectorPath)) {
    throw "Collector not found: $collectorPath"
}

$collectorArgs = @{ ConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path; OutputPath = (Resolve-Path -LiteralPath $root).Path }
if ($StaticOnly) { $collectorArgs.StaticOnly = $true }
if ($StartTime) { $collectorArgs.StartTime = $StartTime }
if ($EndTime) { $collectorArgs.EndTime = $EndTime }
if ($LookbackDays -gt 0) { $collectorArgs.LookbackDays = $LookbackDays }
if ($MaxExecutions -ge 0) { $collectorArgs.MaxExecutions = $MaxExecutions }
if ($AdditionalEvidence) { $collectorArgs.AdditionalEvidence = $true }
& $collectorPath @collectorArgs

Write-Log "INFO" "Assessment completed: $AssessmentId"
Write-Host ""
Write-Host "SUCCESS :: Evidence folder: $root"
