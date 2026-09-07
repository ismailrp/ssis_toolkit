# DTSX Anti-Pattern Inspection Report â€” SSIS Tuning Guide Upgrade

Scope: 781 extracted DTSX files under ssessments/EVSET-001/01_static_packages/extracted. Existing rules were preserved and guide-based static indicators were added.

| Rule | Occurrences | Files | Interpretation |
|---|---:|---:|---|
| `Sort` | 1222 | 175 | Static review candidate; runtime impact not proven. |
| `Aggregate` | 319 | 93 | Static review candidate; runtime impact not proven. |
| `FuzzyLookup` | 0 | 0 | Static review candidate; runtime impact not proven. |
| `FastLoadInactive` | 50 | 46 | Static review candidate; runtime impact not proven. |
| `NoTABLOCK` | 153 | 37 | Static review candidate; runtime impact not proven. |
| `LookupPartialNoCache` | 4 | 2 | Static review candidate; runtime impact not proven. |
| `SELECT*` | 1697 | 253 | Static review candidate; runtime impact not proven. |
| `OLEDBCommand` | 12 | 8 | Static review candidate; runtime impact not proven. |
| `CartesianCrossJoin` | 585 | 70 | Review intent/cardinality; not automatically accidental. |
| `NonSargableFunctionPredicate` | 2098 | 315 | Heuristic SQL candidate; validate execution plan. |
| `OnTheFlyFunctionExpression` | 1065 | 228 | Static review candidate; runtime impact not proven. |
| `NestedViewReference` | 222 | 68 | Static review candidate; runtime impact not proven. |
| `PivotWindowFunction` | 13987 | 171 | Static review candidate; runtime impact not proven. |
| `UnionAll` | 151292 | 283 | Static review candidate; runtime impact not proven. |
| `NoLockAdvisory` | 720 | 29 | Advisory only; dirty-read correctness risk. |
| `MergeJoinComponent` | 710 | 173 | Validate sorted inputs and SortKeyPosition. |
| `ImplicitConversionIndicator` | 13847 | 462 | Static review candidate; runtime impact not proven. |
| `ScriptComponent` | 0 | 0 | Static review candidate; runtime impact not proven. |
| `ADO.NET_or_ODBC_Provider` | 4711 | 91 | Static review candidate; runtime impact not proven. |
| `ExplicitBufferOrThreadSetting` | 448 | 63 | Static review candidate; runtime impact not proven. |
| `TempStoragePathSetting` | 0 | 0 | Static review candidate; runtime impact not proven. |
| `DestinationCommitSizeSetting` | 4161 | 723 | Static review candidate; runtime impact not proven. |
| `ExecutePackageTask` | 532 | 43 | Static review candidate; runtime impact not proven. |
| `CheckpointSetting` | 0 | 0 | Static review candidate; runtime impact not proven. |
| `FullReloadIndicator` | 94 | 26 | Heuristic full-reload candidate; validate ETL design. |

## Guide items requiring runtime/server evidence

- Index/statistics health, execution plans, filter pushdown effectiveness, tempdb, waits, I/O, CPU/RAM, antivirus exclusions, SSIS logging level, destination indexes/constraints/triggers, and actual buffer spooling cannot be proven from DTSX alone.
- Query Store remains unavailable because it is OFF in the captured database state. Use targeted active-request/wait snapshots for selected active jobs.
- Static findings are candidates and must be correlated with package/job duration before assigning P0/P1.
