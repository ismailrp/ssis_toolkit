# DTSX Anti-Pattern Column Glossary

Kolom-kolom berikut menjelaskan isi `DTSX_ANTIPATTERN_PACKAGE_FINDINGS.csv` dan kolom anti-pattern pada `ACTIVE_JOB_DTSX_ANTIPATTERN_PRIORITY.csv`.

Nilai numerik adalah jumlah occurrence yang terdeteksi secara statik pada DTSX, bukan durasi dan bukan bukti bottleneck runtime. Finding perlu dikorelasikan dengan execution duration, executable statistics, rows sent, waits, dan execution plan.

| Kolom | Penjelasan |
|---|---|
| `anti_sort` | Jumlah komponen `Microsoft.Sort`. Sort adalah blocking component yang dapat menahan seluruh pipeline sampai data selesai diurutkan. |
| `anti_aggregate` | Jumlah komponen `Microsoft.Aggregate`. Aggregate dapat menahan data dan memakai memory/tempdb sebelum meneruskan hasil. |
| `anti_fuzzy_lookup` | Jumlah komponen Fuzzy Lookup. Komponen ini mahal secara CPU/memory dan perlu ditinjau pada volume besar. |
| `anti_fast_load_inactive` | Destination OLE DB dengan access mode bukan Fast Load (`AccessMode=0/1`). Berpotensi melakukan insert lebih lambat. |
| `anti_no_tablock` | Destination Fast Load yang tidak mencantumkan `TABLOCK`. Dapat menambah locking overhead; `TABLOCK` tetap harus diuji terhadap concurrency. |
| `anti_lookup_partial_no_cache` | Lookup dengan Partial Cache atau No Cache. Dapat menyebabkan akses database berulang per key/baris. |
| `anti_select_star` | Jumlah query `SELECT *`. Membawa kolom yang tidak diperlukan dan dapat memperbesar row width, memory, I/O, dan network traffic. |
| `anti_oledb_command` | Jumlah OLE DB Command transformation. Umumnya menjalankan statement per baris dan berisiko lambat pada volume besar. |
| `CartesianCrossJoin` | Jumlah `CROSS JOIN` aktif. Bisa disengaja untuk membuat kombinasi kalender/dimensi, tetapi perlu validasi cardinality agar tidak terjadi perkalian baris yang tidak diinginkan. |
| `NonSargableFunctionPredicate` | Indikasi fungsi seperti `LEFT`, `YEAR`, `CAST`, atau `UPPER` pada predicate/query. Heuristic ini perlu divalidasi dengan execution plan karena tidak setiap fungsi pasti menghasilkan scan. |
| `OnTheFlyFunctionExpression` | Indikasi fungsi string/date/konversi di expression `SELECT`. Dapat menambah CPU per baris, terutama pada dataset besar. |
| `NestedViewReference` | Referensi ke view yang namanya terindikasi `vw_`/`view_`. Nested view dapat menyembunyikan join/aggregation kompleks; validasi definisi view dan plan. |
| `PivotWindowFunction` | Indikasi `PIVOT`, `UNPIVOT`, atau `OVER()`. Dapat memicu sort, memory grant besar, atau tempdb usage tinggi. |
| `UnionAll` | Jumlah `UNION ALL`. Tidak otomatis buruk; review bila banyak branch mengulang scan tabel atau seharusnya menggunakan partitioning. |
| `NoLockAdvisory` | Penggunaan `NOLOCK`. Ini advisory, bukan rekomendasi otomatis: dapat menghindari blocking tetapi memungkinkan dirty read, missing row, atau duplicate row. |
| `MergeJoinComponent` | Jumlah Merge Join. Input harus benar-benar sorted sesuai key; validasi `IsSorted`, `SortKeyPosition`, dan ordering source. |
| `ImplicitConversionIndicator` | Indikasi tipe Unicode/non-Unicode atau Data Conversion. Mismatch tipe dapat menambah CPU dan menyebabkan index tidak digunakan. |
| `ScriptComponent` | Jumlah Script Component. Kode per-row perlu direview; koneksi/inisialisasi sebaiknya tidak dibuka ulang di setiap row. |
| `ADO_NET_or_ODBC_Provider` | Indikasi provider ADO.NET/ODBC. Dapat menambah provider/wrapper overhead; evaluasi migrasi ke MSOLEDBSQL secara terkontrol. |
| `ExplicitBufferOrThreadSetting` | Adanya setting buffer atau thread seperti `DefaultBufferSize`, `DefaultBufferMaxRows`, `EngineThreads`, atau `MaxConcurrentExecutables`. Ini bukan masalah otomatis; nilai efektif dan resource server harus diukur. |
| `TempStoragePathSetting` | Adanya `BLOBTempStoragePath` atau `BufferTempStoragePath`. Finding menunjukkan konfigurasi path, bukan bukti spooling atau bottleneck disk. |
| `DestinationCommitSizeSetting` | Commit size destination yang kecil dan berpotensi memicu commit berulang. Nilai `0` dan `2147483647` tidak dianggap finding; untuk Fast Load, validasi nilai aktual dan volume data. |
| `ExecutePackageTask` | Jumlah Execute Package Task. Banyak child package dapat menambah orchestration overhead atau serial execution; review dependency dan parallelism. |
| `CheckpointSetting` | Adanya konfigurasi checkpoint. Checkpoint bukan anti-pattern; kolom ini hanya menunjukkan konfigurasi untuk review recovery/restart behavior. |
| `FullReloadIndicator` | Indikasi pola truncate/delete lalu insert ulang. Heuristic ini perlu dikonfirmasi karena full reload dapat memang disengaja. |

## Interpretasi prioritas

- `P1` tidak boleh diberikan hanya karena satu kolom bernilai lebih dari nol. Gunakan runtime impact atau reliability evidence.
- `P2` biasanya untuk kandidat optimasi/investigasi yang berdampak sedang atau penyebabnya belum terbukti.
- `P3` untuk advisory, housekeeping, atau static-only candidate.
- `P0` hanya untuk masalah kritis yang terbukti dan memerlukan tindakan segera.
