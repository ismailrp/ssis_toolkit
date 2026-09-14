export const assessment = {
  id: "EVSET-45D-COMPLETE",
  server: "BGASVR-DWH-DEV",
  window: "27 Jul – 10 Sep 2026",
  generated: "14 September 2026",
  executions: 16480,
  succeeded: 16204,
  failed: 237,
  unexpected: 38,
  canceled: 1,
  avgSeconds: 372.92,
  p95Seconds: 1876.75,
  maxSeconds: 129906.13,
  cumulativeHours: 1707,
  packagesScanned: 781,
  ispacSuccess: 105,
  ispacTotal: 107,
};

export const durationLeaders = [
  { package: "FACT_LKK.dtsx", project: "DWH_LKK_PROJECT_NEW", avg: 4680.51, max: 8676.63 },
  { package: "Seq_Staging_SIGAP.dtsx", project: "Sequence_Table", avg: 4625.37, max: 9161.68 },
  { package: "PS_AS.dtsx", project: "INVESTOR_RELATIONS_PROJECT", avg: 4156.12, max: 5168.33 },
  { package: "Seq_BSEG 1.dtsx", project: "Sequence_Table", avg: 3790.50, max: 8783.25 },
  { package: "STG to DWH.dtsx", project: "ControllableProfit", avg: 3498.64, max: 4440.09 },
  { package: "Fact.dtsx", project: "DWH_GRADING_TBS", avg: 3141.53, max: 5819.23 },
  { package: "DWH_SMALLERTABLES.dtsx", project: "SSISMR", avg: 3116.10, max: 117315.65 },
  { package: "Seq_BSEG.dtsx", project: "Sequence_Table", avg: 3104.66, max: 3477.71 },
  { package: "FACT_PPH_ANNUAL_SPLIT.dtsx", project: "PPH21_DJP", avg: 2638.50, max: 5104.05 },
  { package: "STG to DWH.dtsx", project: "LKK Phase 2", avg: 2292.05, max: 4175.17 },
];

export const cumulativeLeaders = [
  { package: "Fact.dtsx", project: "DWH_GRADING_TBS", executions: 149, totalHours: 130.02 },
  { package: "FACT_SPARTA_LHA_NEW.dtsx", project: "SPARTA_PROJECT", executions: 174, totalHours: 107.73 },
  { package: "DWH_STG to DWH_DM.dtsx", project: "premi dan lembur monitoring", executions: 196, totalHours: 100.52 },
  { package: "Staging.dtsx", project: "AWL", executions: 1076, totalHours: 77.35 },
  { package: "FACT_DD_TBS.dtsx", project: "DAILY_DASHBOARD_PROJECT", executions: 260, totalHours: 61.72 },
  { package: "Seq_Staging_SIGAP.dtsx", project: "Sequence_Table", executions: 47, totalHours: 60.39 },
  { package: "FACT_LKK.dtsx", project: "DWH_LKK_PROJECT_NEW", executions: 44, totalHours: 57.21 },
  { package: "Seq_Staging_SAP.dtsx", project: "Sequence_Table", executions: 89, totalHours: 49.81 },
  { package: "PS_AS.dtsx", project: "INVESTOR_RELATIONS_PROJECT", executions: 43, totalHours: 49.64 },
  { package: "Seq_Staging_SPARTA_4T.dtsx", project: "Sequence_Table", executions: 179, totalHours: 49.06 },
];

// Static design indicators from the V12 scanner. `canonicalPackages` counts the
// 167 unique package locations in the aggregate finding report, while
// `scanPackages` and `occurrences` retain the full 781-package static scope.
export const staticFindingStatistics = [
  { category: "Full reload indicator", canonicalPackages: 145, scanPackages: 624, occurrences: 2465 },
  { category: "On-the-fly function expression", canonicalPackages: 111, scanPackages: 455, occurrences: 21907 },
  { category: "Non-sargable function predicate", canonicalPackages: 79, scanPackages: 309, occurrences: 5007 },
  { category: "SELECT *", canonicalPackages: 68, scanPackages: 249, occurrences: 2961 },
  { category: "Union All", canonicalPackages: 66, scanPackages: 147, occurrences: 1939 },
  { category: "Data conversion", canonicalPackages: 52, scanPackages: 290, occurrences: 1609 },
  { category: "Pivot / window function", canonicalPackages: 43, scanPackages: 136, occurrences: 2498 },
  { category: "Cartesian cross join", canonicalPackages: 36, scanPackages: 70, occurrences: 602 },
  { category: "Sort", canonicalPackages: 33, scanPackages: 175, occurrences: 1222 },
  { category: "Script component", canonicalPackages: 31, scanPackages: 212, occurrences: 2347 },
  { category: "Merge Join component", canonicalPackages: 29, scanPackages: 173, occurrences: 710 },
  { category: "Aggregate", canonicalPackages: 13, scanPackages: 93, occurrences: 319 },
  { category: "NOLOCK advisory", canonicalPackages: 13, scanPackages: 29, occurrences: 702 },
  { category: "Fast Load inactive", canonicalPackages: 12, scanPackages: 46, occurrences: 50 },
  { category: "ADO.NET / ODBC provider", canonicalPackages: 6, scanPackages: 82, occurrences: 485 },
  { category: "No TABLOCK", canonicalPackages: 5, scanPackages: 37, occurrences: 153 },
  { category: "Execute Package Task", canonicalPackages: 3, scanPackages: 43, occurrences: 532 },
  { category: "Nested view reference", canonicalPackages: 2, scanPackages: 32, occurrences: 66 },
  { category: "Lookup partial / no cache", canonicalPackages: 0, scanPackages: 2, occurrences: 4 },
  { category: "OLE DB Command", canonicalPackages: 0, scanPackages: 8, occurrences: 12 },
];

// Active-job report rows are job-step-package relationships before package
// deduplication, sourced from ACTIVE_JOB_DTSX_ANTIPATTERN_PRIORITY V12.
export const activeJobPriorityDistribution = [
  { priority: "P0", count: 0 },
  { priority: "P1", count: 90 },
  { priority: "P2", count: 1 },
  { priority: "P3", count: 87 },
];

export const findings = [
  { id: "SSIS-TUNE-001", priority: "P0", type: "VALIDASI DAHULU", title: "Lengkapi pengukuran runtime", scope: "Seluruh assessment", evidence: "Component phase dan data statistics kosong; Query Store tidak aktif.", hypothesis: "Tanpa data pengukuran tersebut, penyebab bottleneck pipeline dan database belum dapat dibuktikan.", validation: "Ambil component phase, volume baris, identitas query, durasi, reads, waits, dan blocking pada execution yang dapat dibandingkan.", guardrail: "Jangan mengubah package atau konfigurasi produksi sebelum baseline memadai.", rollback: "Hentikan pengumpulan atau kembalikan konfigurasi logging jika menambah overhead yang material pada proses.", confidence: "TERKONFIRMASI" },
  { id: "SSIS-TUNE-002", priority: "P1", type: "INVESTIGASI", title: "Periksa Seq_Staging_SIGAP / Package4", scope: "Sequence_Table / Sequence_Table / Seq_Staging_SIGAP.dtsx", evidence: "Execution 1240550 berdurasi 6.336,348 detik; Package4 menyumbang 6.334,656 detik.", hypothesis: "Waktu proses terkonsentrasi pada Package4, tetapi mekanisme internalnya belum diketahui.", validation: "Telusuri dependency, child execution, waktu source/destination, volume baris, dan SQL aktif untuk Package4.", guardrail: "Output, jumlah baris, proses downstream, dan success rate tidak memburuk.", rollback: "Tolak atau batalkan perubahan jika hasil data berubah atau durasi tidak membaik pada execution pembanding.", confidence: "LOKASI WAKTU TERKONFIRMASI; PENYEBAB BELUM DIKETAHUI" },
  { id: "SSIS-TUNE-003", priority: "P1", type: "INVESTIGASI", title: "Telusuri AWL API to STG", scope: "Project_Fact / AWL / Staging.dtsx / API to STG", evidence: "34 raw execution, total 11.122,319 detik, P95 720,6 detik; execution target 1240317.", hypothesis: "Waktu respons API, pagination, serialization, atau penulisan destination mungkin menjelaskan variasi durasi.", validation: "Pisahkan waktu API call, transformasi, dan destination pada minimal tiga execution yang dapat dibandingkan.", guardrail: "Pastikan kelengkapan data, penanganan duplikasi, dan mekanisme retry API tidak berubah.", rollback: "Batalkan perubahan jika data tidak lengkap, terjadi duplikasi, atau reliability API memburuk.", confidence: "TARGET SANGAT MUNGKIN; PENYEBAB BELUM TERBUKTI" },
  { id: "SSIS-REL-001", priority: "P1", type: "PERBAIKI DALAM CONTROLLED TEST", title: "Pulihkan reliability koneksi dan validasi", scope: "DWH_GRADING_TBS/Staging; Seq_Staging_WB; Seq_Staging_NON_SAP", evidence: "Connection acquisition, validation, timeout, missing connection, dan failure messages ditemukan.", hypothesis: "Deployment/environment reference atau ketersediaan provider mungkin menyebabkan failure dan retry.", validation: "Perbaiki dalam controlled test dan bandingkan success rate; ukur dampak performance secara terpisah.", guardrail: "Target koneksi, credential mapping, output data, dan downstream behavior harus tetap benar.", rollback: "Kembalikan konfigurasi sebelumnya jika koneksi mengarah ke target yang salah atau hasil data berubah.", confidence: "KONDISI TERKONFIRMASI; MEKANISME PERLU DIVALIDASI" },
];

export const roadmap = [
  { wave: "Wave 0", label: "Measurement", text: "Rekonsiliasi population, aktifkan telemetry target, capture SQL evidence.", state: "Sekarang" },
  { wave: "Wave 1", label: "High-confidence", text: "Repair reliability dan uji hotspot yang telah terlokalisasi.", state: "Berikutnya" },
  { wave: "Wave 2", label: "Secondary", text: "Validasi variability dan korelasi static-to-runtime.", state: "Terjadwal" },
  { wave: "Wave 3", label: "Strategic", text: "Evaluasi redesign hanya setelah causal proof dan benchmark.", state: "Deferred" },
];
