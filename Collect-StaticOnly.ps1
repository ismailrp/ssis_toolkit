param(
    [string]$ConfigPath = ".\config.ps1",
    [string]$AssessmentId = ""
)

# Compatibility alias. Use New-SSISAssessment.ps1 as the single entry point.
& (Join-Path $PSScriptRoot "New-SSISAssessment.ps1") -ConfigPath $ConfigPath -AssessmentId $AssessmentId -StaticOnly
