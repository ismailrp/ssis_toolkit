# ============================================================
# SSIS Performance Evidence Collector - Configuration v1.1.0
# Compatible with Windows PowerShell 4.0+
# ============================================================

$Config = @{
    # SQL Server instance that hosts SSISDB.
    ServerInstance = "BGASVR-DWH-DEV"

    # Authentication
    UseWindowsAuthentication = $true
    SqlUsername = ""
    SqlPassword = ""

    # Root containing exported ISPAC files. Discovery is recursive.
    # Example layout:
    # D:\ispac\SSISDB\Areal Statement\MyProject.ispac
    IspacRoot = "C:\Users\ntt.ismail\Downloads\ssis_toolkit\ispac"

    # Static collection from ISPAC. No Visual Studio source tree is required.
    CollectStatic = $true

    # Runtime collection from SSISDB.
    CollectRuntime = $true

    # Runtime collection scope
    LookbackDays  = 14
    MaxExecutions = 500

    # Optional filters. Empty array = all.
    FolderNames  = @()
    ProjectNames = @()
    PackageNames = @()

    # Runtime message collection can become large.
    CollectMessages = $true
    MessageSeverityThreshold = 70

    # Optional Query Store evidence. Keep disabled for first-pass assessment.
    CollectQueryStore = $false
    QueryStoreDatabases = @()

    # Output root
    OutputRoot = ".\assessments"

    # SQL command timeout in seconds
    SqlCommandTimeoutSeconds = 120
}
