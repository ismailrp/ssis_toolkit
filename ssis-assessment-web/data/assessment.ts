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

export const findings = [
  { id: "SSIS-TUNE-001", priority: "P0", type: "VALIDATE FIRST", title: "Lengkapi observability runtime", scope: "Assessment-wide", evidence: "Component phase dan data statistics kosong; Query Store tidak aktif.", hypothesis: "Tanpa telemetry ini, mekanisme bottleneck pipeline dan database tidak dapat dibuktikan.", validation: "Capture component phase, row volume, query identity, duration, reads, waits, dan blocking pada execution comparable.", guardrail: "Tidak mengubah package atau konfigurasi produksi saat baseline belum lengkap.", confidence: "CONFIRMED" },
  { id: "SSIS-TUNE-002", priority: "P1", type: "INVESTIGATE", title: "Profile Seq_Staging_SIGAP / Package4", scope: "Sequence_Table / Sequence_Table / Seq_Staging_SIGAP.dtsx", evidence: "Execution 1240550 berdurasi 6.336,348 detik; Package4 menyumbang 6.334,656 detik.", hypothesis: "Elapsed time terkonsentrasi pada branch Package4; mekanisme internal belum diketahui.", validation: "Trace dependency, child execution, source/destination timing, row volume, serta SQL aktif untuk Package4.", guardrail: "Output, row count, downstream behavior, dan success rate tidak memburuk.", confidence: "CONFIRMED LOCATION" },
  { id: "SSIS-TUNE-003", priority: "P1", type: "INVESTIGATE", title: "Trace AWL API to STG", scope: "Project_Fact / AWL / Staging.dtsx / API to STG", evidence: "34 raw execution, total 11.122,319 detik, P95 720,6 detik; execution target 1240317.", hypothesis: "API latency, pagination, serialization, atau destination write dapat menjelaskan variability.", validation: "Pisahkan API call, transform, dan destination elapsed pada minimal tiga execution comparable.", guardrail: "Validasi completeness, duplicate handling, dan API retry semantics.", confidence: "HIGHLY LIKELY TARGET" },
  { id: "SSIS-REL-001", priority: "P1", type: "TUNE NOW", title: "Pulihkan reliability koneksi dan validasi", scope: "DWH_GRADING_TBS/Staging; Seq_Staging_WB; Seq_Staging_NON_SAP", evidence: "Connection acquisition, validation, timeout, missing connection, dan failure messages ditemukan.", hypothesis: "Deployment/environment reference atau availability provider menyebabkan failure dan retry.", validation: "Perbaiki dalam controlled test dan bandingkan success rate; nilai performance secara terpisah.", guardrail: "Rollback bila target koneksi, credential mapping, atau hasil data berubah.", confidence: "CONFIRMED" },
];

export const roadmap = [
  { wave: "Wave 0", label: "Measurement", text: "Rekonsiliasi population, aktifkan telemetry target, capture SQL evidence.", state: "Sekarang" },
  { wave: "Wave 1", label: "High-confidence", text: "Repair reliability dan uji hotspot yang telah terlokalisasi.", state: "Berikutnya" },
  { wave: "Wave 2", label: "Secondary", text: "Validasi variability dan korelasi static-to-runtime.", state: "Terjadwal" },
  { wave: "Wave 3", label: "Strategic", text: "Evaluasi redesign hanya setelah causal proof dan benchmark.", state: "Deferred" },
];
