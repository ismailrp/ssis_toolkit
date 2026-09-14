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
  { package: "Staging.dtsx", project: "AWL", avg: 3271.27, max: 7206.04 },
  { package: "DAILY_TBS.dtsx", project: "DWH Operation", avg: 2784.4, max: 6241.8 },
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
