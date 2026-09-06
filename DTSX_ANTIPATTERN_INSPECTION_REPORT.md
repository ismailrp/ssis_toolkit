# SSIS DTSX XML Anti-Pattern Inspection Report

## Scope

Inspected all extracted `.dtsx` files under:

`assessments/EVSET-001/01_static_packages/extracted`

- DTSX files inspected: **781**
- XML parse errors: **0**
- Inspection date: 2026-09-06

## Package Count Reconciliation

The project contains multiple valid package counts because each file represents a different population:

| Population | Count | Source |
|---|---:|---|
| SSISDB catalog package inventory | **938** | `assessments/EVSET-001/02_ssisdb_inventory/packages.csv` |
| Extracted/static package summaries | **781** | `assessments/EVSET-001/01_static_packages/package_static_summary.csv` |
| Extracted `.dtsx` files | **781** | `assessments/EVSET-001/01_static_packages/extracted` |
| ISPAC files | **107** | `assessments/EVSET-001/00_manifest/ispac_inventory.csv` |
| Unique package names in static summary | **546** | Derived from `PackageName` |
| Unique package names in SSISDB inventory | **552** | Derived from `package_name` |
| Unique runtime package keys | **183** | Derived from `executions.csv` |
| Raw execution records | **500** | `assessments/EVSET-001/03_runtime/executions.csv` |

The number **718** was not found in the current inventory or extracted XML count. It may come from a different filtered or deduplicated population, but it is not the total extracted package count in this assessment.

The most appropriate number depends on the question:

- Use **938** for the deployed SSISDB catalog package inventory.
- Use **781** for packages with extracted and parsed static XML available for inspection.
- Use **183** for unique package keys represented in the capped raw runtime sample.

## Inspection Summary

| Parameter | Result | Files / Components | Assessment |
|---|---:|---:|---|
| `Microsoft.Sort` | 1,222 | 175 files | Static blocking-component risk; runtime impact not proven |
| `Microsoft.Aggregate` | 319 | 93 files | Static blocking-component risk; runtime impact not proven |
| `Microsoft.FuzzyLookup` | 0 | 0 files | Not found |
| OLE DB Destination with `AccessMode=0/1` | 50 | 46 files | Fast Load is inactive according to the XML rule |
| Fast Load without `TABLOCK` | 153 | 37 files | `AccessMode=3/4`, but `FastLoadOptions` does not contain `TABLOCK` |
| Lookup with `CacheType=1/2` | 4 | 2 files | Partial/No Cache investigation target |
| `SELECT *` in `SqlCommand` | 1,697 | 253 files | Review candidate; not automatically a bottleneck |
| `Microsoft.OLEDBCommand` | 12 | 8 files | Row-by-row update risk; not automatically fatal |
| `DelayValidation=0/false` | 0 | 0 files | No finding under the requested rule |
| Explicit `DefaultBufferMaxRows` | 0 | 0 files | Not present explicitly; effective/default value unknown |
| Explicit `DefaultBufferSize` | 0 | 0 files | Not present explicitly; effective/default value unknown |
| Explicit `AutoAdjustBufferSize` | 0 | 0 files | Not present explicitly |
| Explicit `EngineThreads` | 0 | 0 files | Not present explicitly |
| Explicit `MaxConcurrentExecutables` | 0 | 0 files | Not present explicitly |
| ADO.NET connection manager | 0 | 0 files | No `CreationName=ADO.NET` finding |

## Complete Package-to-Finding Mapping

The complete package-level mapping is available in [DTSX_ANTIPATTERN_PACKAGE_FINDINGS.csv](DTSX_ANTIPATTERN_PACKAGE_FINDINGS.csv). Use this file to identify the exact `.dtsx` files to open in Visual Studio.

- `PackageFile` is relative to `assessments/EVSET-001/01_static_packages/extracted`.
- Each numeric column is the number of matching XML occurrences in that package; `0` means no finding for that parameter.
- Filter any parameter column greater than `0` to create the review list for that anti-pattern.
- The mapping is static XML evidence. It identifies packages for review; it does not by itself prove runtime impact.

## To-Do List

| Category | Component/Task | Parameter | Technical Action in SSDT |
|---|---|---|---|
| Data Flow | Sort / Aggregate | 1,541 blocking-component occurrences | Review only in runtime-hot packages. Preserve required ordering and aggregation semantics. |
| Data Flow | OLE DB Destination | 50 destinations with `AccessMode=0/1` | Test Fast Load (`AccessMode=3`) in a controlled environment. Validate constraints, triggers, indexes, locking, and output correctness. |
| Data Flow | OLE DB Destination | 153 Fast Load destinations without `TABLOCK` | Review `FastLoadOptions`; add `TABLOCK` only after testing concurrency and locking impact. |
| Data Flow | Lookup | 4 components with `CacheType=1` | Review lookup volume, reference query, duplicate keys, and runtime before considering another cache mode. |
| Data Flow | OLE DB Source / Lookup | 1,697 `SELECT *` statements | Replace with explicit columns after validating mappings and downstream dependencies. |
| Data Flow | OLE DB Command | 12 components in 8 files | Investigate set-based alternatives only if runtime/volume evidence shows row-by-row cost. |
| Control Flow | Validation | No `DelayValidation=0/false` findings | No XML-based change required. `DelayValidation=true` should not be applied globally. |
| Control Flow | Buffer/concurrency properties | Properties not explicitly present | Collect effective runtime settings and resource evidence before tuning. |
| Connection | Connection Managers | No ADO.NET manager found | No provider migration action based on this XML inspection. |

## Representative Findings

### Fast Load inactive

- `SSISDB/BGADWH_SSIS/BGADWH_SSIS/DWH_DimBlock.dtsx`
  - `Package\Data Flow Task\DST_BGA_DWH_DimBlock`
  - `AccessMode=0`
- `SSISDB/Project_Fact/DWH_GRADING_TBS/Staging.dtsx`
  - `Package\STG_AI_GRADING_PENERIMAAN_TBS\AI_GRADING_PENERIMAAN_TBS\STG_AI_GRADING_PENERIMAAN_TBS`
  - `AccessMode=0`
- `SSISDB/Project_Fact/AWL/Staging.dtsx`
  - `Package\MAPPING_AWL_WATER_LEVEL_DEVICE\MAPPING_AWL_WATER_LEVEL_DEVICE\MAPPING_AWL_WATER_LEVEL_DEVICE`
  - `AccessMode=0`

### Fast Load without `TABLOCK`

- `SSISDB/BGADWH_SSIS/BGADWH_SSIS/Group_LapRH.dtsx`
  - Destination `Package\Sequence Container Yield\Fact Data Yield Crop Area\Destination Fact Yield Crop Area`
  - `AccessMode=3`, `FastLoadOptions=CHECK_CONSTRAINTS`
- `SSISDB/MR/SSISMR/DWH-COEPByMonth.dtsx`
  - Multiple destinations with `AccessMode=3`
  - `FastLoadOptions=ROWS_PER_BATCH = 5000` or empty
- `SSISDB/Sequence_Table/Sequence_Table/Seq_Staging_NON_SAP.dtsx`
  - `Package\BTEC_DBJNL\BTEC_DBJNL\STG_BTEC_DBJNL`
  - `AccessMode=3`, `FastLoadOptions=CHECK_CONSTRAINTS`

### Lookup Partial Cache

The four findings are in two duplicated/parallel package locations:

- `SSISDB/Project_Fact/MILL_COST_PROJECT/FACT_MILL_COST_DASHBOARD.dtsx`
- `SSISDB/tesss/MILL_COST_PROJECT/FACT_MILL_COST_DASHBOARD.dtsx`

Affected components include `Lookup` and `Lookup 1`, both with `CacheType=1`.

### OLE DB Command

Representative affected packages include:

- `DWH_DimBlock.dtsx`
- `DWH_DimStandardMill.dtsx`
- `DWH_DimUnit.dtsx`
- `Package1.dtsx`

The presence of `Microsoft.OLEDBCommand` indicates row-oriented command processing risk. It does not prove that the component is the runtime bottleneck without execution/component timing evidence.

### `SELECT *`

Examples include Lookup/source queries such as:

```sql
select * from [dm].[dim_company]
select * from [dm].[dim_inplas]
select * from [stg].[AS_MUMNT]
```

Some SQL blocks also contain CTEs or nested queries. Each occurrence should be reviewed in context before changing it.

## Important Technical Qualifications

- Sort and Aggregate are potentially blocking components, but their presence alone does not prove a bottleneck.
- `TABLOCK` can improve bulk-load behavior but can also increase locking impact and affect concurrent readers/writers.
- `OLEDBCommand` is a high-risk row-by-row pattern, not automatically a fatal issue.
- Absence of `DefaultBufferMaxRows` or `DefaultBufferSize` means the values are not explicitly set in the XML; it does not prove the effective runtime defaults or prove that buffers are too small.
- Absence of `DelayValidation=0/false` means no actionable finding under the requested XML rule; it does not mean package validation is optimal.
- XML findings must be correlated with runtime evidence from executable statistics, component phases, data statistics, and database/resource measurements before production changes.
