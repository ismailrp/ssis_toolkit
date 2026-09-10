# SSIS Performance Evidence Toolkit v1.1.2

PowerShell 4.0+ evidence collector for SSIS performance assessment.

## Recommended input

Use exported `.ispac` files plus SSISDB runtime evidence. Visual Studio/SSDT source folders are not required.

The collector recursively discovers ISPAC files. Example:

    D:\ispac\
      SSISDB\
        Areal Statement\
          ArealStatement.ispac
        Finance\
          FinanceETL.ispac

Set only the root:

    IspacRoot = "D:\ispac"

The relative path is preserved so an ISPAC such as:

    SSISDB\Areal Statement\ArealStatement.ispac

is mapped as:

    CatalogName = SSISDB
    FolderName  = Areal Statement
    ProjectName = ArealStatement

## Normal execution

1. Edit `config.ps1`.
2. Keep `CollectStatic = $true` and `CollectRuntime = $true`.
3. Keep Query Store disabled for the first pass.
4. Run:

    powershell -ExecutionPolicy Bypass -File .\New-SSISAssessment.ps1

Optional explicit ID:

    powershell -ExecutionPolicy Bypass -File .\New-SSISAssessment.ps1 -AssessmentId EVSET-001

Untuk window runtime yang lebih luas, gunakan override pada entry point yang sama.
`-MaxExecutions 0` berarti tidak membatasi jumlah execution; tanpa parameter ini,
nilai `MaxExecutions` dari `config.ps1` tetap berlaku.

```powershell
# 90 hari terakhir, tanpa cap execution
powershell -ExecutionPolicy Bypass -File .\New-SSISAssessment.ps1 -LookbackDays 90 -MaxExecutions 0 -AssessmentId EVSET-090D

# Window absolut; EndTime bersifat eksklusif
powershell -ExecutionPolicy Bypass -File .\New-SSISAssessment.ps1 -StartTime "2026-01-01 00:00:00" -EndTime "2026-04-01 00:00:00" -MaxExecutions 0 -AssessmentId EVSET-Q1
```

## Output

    assessments\EVSET-...\
      00_manifest\
        collector_environment.csv
        server_identity.csv
        ispac_inventory.csv
        static_file_inventory.csv
        evidence_manifest.csv
      01_static_packages\
        ispac_original\
        extracted\
        package_static_summary.csv
      02_ssisdb_inventory\
      03_runtime\
      04_messages\
      05_sqlserver_optional\
      collector.log

## Modes

### Full recommended

    CollectStatic  = $true
    CollectRuntime = $true

This gives ISPAC design evidence + actual SSISDB runtime evidence.

### Runtime only

    CollectStatic  = $false
    CollectRuntime = $true

No ISPAC is required.

### Static only

    CollectStatic  = $true
    CollectRuntime = $false

`New-SSISAssessment.ps1` adalah entry point tunggal untuk runtime dan static-only.
`Collect-StaticOnly.ps1` tetap tersedia sebagai compatibility shortcut. Collector
inti `Collect-SSISEvidence.ps1` tetap terpisah dan dapat dipanggil oleh entry point.

Evidence tambahan bersifat opsional dan tidak mengulang output core collector:

```powershell
.New-SSISAssessment.ps1 -LookbackDays 90 -MaxExecutions 0 -AdditionalEvidence
```

Mode ini menghasilkan SQL Agent mapping dan Query Store database state. Jika list
database kosong, database user yang online ditemukan otomatis; Query Store ranking
hanya dijalankan pada database yang Query Store-nya aktif. List manual tetap dapat
dipakai sebagai override. Wrapper references juga memakai discovery yang sama.
Query Store ranking tetap memakai modul Query Store existing; component,
execution, message, dan inventory evidence juga tidak diduplikasi.

## PowerShell 4.0 compatibility

ISPAC extraction uses Windows `Shell.Application`; no `Install-Module`, `Expand-Archive`, or modern PowerShell module is required.

## Important notes

- Extraction copies the original ISPAC into the assessment and extracts a working evidence copy; it does not alter the source ISPAC.
- `execution_component_phases` and `execution_data_statistics` may be empty depending on SSIS logging level and execution history.
- Query Store is intentionally optional because source/destination databases may be numerous and first-pass SSISDB evidence is usually the safer starting point.


## v1.1.2 compatibility fixes
- Fixed Windows PowerShell 4.0 here-string terminators: closing `"@` now starts in column 1.
- Removed remaining `Get-ChildItem -File` usage and replaced it with `PSIsContainer` filtering.
- No change to evidence layout or configuration keys.
