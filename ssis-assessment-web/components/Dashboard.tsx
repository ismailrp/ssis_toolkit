"use client";
import { useEffect, useState } from "react";
import Image, { type StaticImageData } from "next/image";
import {
  assessment,
  findings,
  staticFindingStatistics,
} from "@/data/assessment";
import {
  ActiveJobPriorityChart,
  AverageDurationChart,
  CumulativeRuntimeChart,
  ReliabilityChart,
} from "./Charts";
import sigapImage from "@/images/02_SIGAP_Package4.png";
import awlImage from "@/images/03_AWL_APItoSTG.png";
import gradingImage from "@/images/04_DWH_GRADING_TBS_Staging.png";
import nonSapImage from "@/images/04_Seq_Staging_NON_SAP.png";
import wbImage from "@/images/04_Seq_Staging_WB.png";

const findingImages: Record<string, { source: StaticImageData; caption: string }[]> = {
  "SSIS-TUNE-002": [
    { source: sigapImage, caption: "Seq_Staging_SIGAP.dtsx · jalur internal Package4" },
  ],
  "SSIS-TUNE-003": [
    { source: awlImage, caption: "AWL / Staging.dtsx · API to STG" },
  ],
  "SSIS-REL-001": [
    { source: gradingImage, caption: "DWH_GRADING_TBS / Staging.dtsx" },
    { source: nonSapImage, caption: "Seq_Staging_NON_SAP.dtsx" },
    { source: wbImage, caption: "Seq_Staging_WB.dtsx" },
  ],
};

type Config = {
  client: string;
  title: string;
  accent: string;
  note: string;
  showEvidence: boolean;
  showRoadmap: boolean;
};
const defaults: Config = {
  client: "Bumitama Gunajaya Agro",
  title: "SSIS Performance Assessment",
  accent: "#7150c8",
  note: "Evidence-led review • keputusan tuning harus divalidasi melalui controlled benchmark",
  showEvidence: true,
  showRoadmap: true,
};

const format = (value: number, digits = 0) =>
  new Intl.NumberFormat("id-ID", { maximumFractionDigits: digits }).format(
    value,
  );
const duration = (s: number) =>
  s >= 3600 ? `${format(s / 3600, 1)} jam` : `${format(s / 60, 1)} menit`;

export default function Dashboard() {
  const [config, setConfig] = useState(defaults);
  const [open, setOpen] = useState(false);
  useEffect(() => {
    const saved = localStorage.getItem("ssis-report-config");
    if (saved) {
      const stored = JSON.parse(saved);
      if (stored.client === "Enterprise Data Platform") {
        stored.client = defaults.client;
      }
      setConfig({ ...defaults, ...stored });
    }
  }, []);
  const update = (patch: Partial<Config>) =>
    setConfig((current) => {
      const next = { ...current, ...patch };
      localStorage.setItem("ssis-report-config", JSON.stringify(next));
      return next;
    });
  return (
    <main style={{ "--accent": config.accent } as React.CSSProperties}>
      <aside className="rail no-print">
        <a className="rail-brand" href="#top">
          <span className="rail-brand-mark" aria-hidden="true">
            <i className="fa-solid fa-database" />
            <i className="fa-solid fa-chart-line" />
          </span>
          <span className="rail-brand-copy">
            <b>SSIS Assessment</b>
            <small>Performance Report</small>
          </span>
        </a>
        <nav>
          <a href="#executive">Ringkasan assessment</a>
          {config.showEvidence && <a href="#coverage">Evidence yang tersedia</a>}
          <a href="#statistics">Cakupan package</a>
          <a href="#static-findings">Indikator desain package</a>
          <a href="#visuals">Profil durasi proses</a>
          <a href="#findings">Prioritas tindakan</a>
          {config.showRoadmap && <a href="#roadmap">Dokumen detail temuan</a>}
          <a className="rail-feature-link" href="/findings">
            Semua dokumen temuan →
          </a>
        </nav>
        <div className="rail-foot">
          <span className="live-dot" /> Evidence loaded
        </div>
      </aside>
      <div className="report-shell" id="top">
        <header className="hero report-section">
          <nav>
            <div className="report-id">ASSESSMENT {assessment.id}</div>
          </nav>
          <div className="hero-grid">
            <div>
              <div className="eyebrow">
                Technical Assessment · {config.client}
              </div>
              <h1>{config.title}</h1>
              <p>{config.note}</p>
            </div>
            <div className="hero-meta">
              <div>
                <span>SERVER</span>
                <strong>{assessment.server}</strong>
              </div>
              <div>
                <span>OBSERVATION WINDOW</span>
                <strong>{assessment.window}</strong>
              </div>
              <div>
                <span>REPORT DATE</span>
                <strong>{assessment.generated}</strong>
              </div>
            </div>
          </div>
        </header>

        <section className="summary-strip report-section">
          <div>
            <span>EXECUTIONS</span>
            <strong>{format(assessment.executions)}</strong>
            <small>uncapped population</small>
          </div>
          <div>
            <span>SUCCESS RATE</span>
            <strong>
              {format((assessment.succeeded / assessment.executions) * 100, 2)}%
            </strong>
            <small>{format(assessment.succeeded)} succeeded</small>
          </div>
          <div>
            <span>P95 DURATION</span>
            <strong>{duration(assessment.p95Seconds)}</strong>
            <small>{format(assessment.p95Seconds, 2)} seconds</small>
          </div>
          <div>
            <span>CUMULATIVE</span>
            <strong>{format(assessment.cumulativeHours)} jam</strong>
            <small>observed runtime</small>
          </div>
        </section>

        <div className="content">
          <section id="executive" className="intro report-section">
            <div>
              <span className="section-no">01</span>
              <div>
                <span className="kicker">RINGKASAN ASSESSMENT</span>
                <h2>Kesimpulan utama</h2>
              </div>
            </div>
            <div>
              <p className="lead">
                Assessment ini sudah menunjukkan durasi proses dan masalah
                kegagalan berdasarkan data yang tersedia. Proses yang menjadi
                prioritas pemeriksaan adalah Seq_Staging_SIGAP / Package4 dan
                AWL / Staging / API to STG. Masalah koneksi juga ditemukan pada
                beberapa package dan perlu diperbaiki melalui pengujian terkontrol.
              </p>
              <p>
                Data saat ini belum cukup untuk memastikan komponen SSIS atau
                proses database yang menjadi penyebab utama. Oleh karena itu,
                langkah selanjutnya adalah melengkapi data pengukuran pada proses
                prioritas, kemudian menguji satu perubahan pada satu waktu dan
                membandingkan hasilnya.
              </p>
              <p>
                Indikator dari pemeriksaan desain package hanya menunjukkan bagian
                yang perlu diperiksa lebih lanjut. Indikator tersebut belum
                membuktikan penyebab lambatnya proses.
              </p>
            </div>
          </section>

          {config.showEvidence && (
            <section id="coverage" className="evidence report-section">
              <div>
                <span className="section-no light">02</span>
                <span className="kicker light">EVIDENCE YANG TERSEDIA</span>
                <h2>Apa yang sudah dan belum dapat disimpulkan?</h2>
                <p>
                  Data saat ini cukup untuk menentukan prioritas, tetapi belum cukup
                  untuk memastikan penyebab teknis dan solusi akhir.
                </p>
              </div>
              <div className="evidence-grid">
                <div>
                  <i className="fa-solid fa-circle-check" />
                  <b>Riwayat proses tersedia</b>
                  <span>16.480 proses selama periode penilaian tanpa pembatasan jumlah</span>
                </div>
                <div>
                  <i className="fa-solid fa-circle-check" />
                  <b>Desain package berhasil diperiksa</b>
                  <span>
                    {assessment.packagesScanned} package terbaca tanpa kegagalan pemeriksaan
                  </span>
                </div>
                <div className="gap">
                  <i className="fa-solid fa-circle-exclamation" />
                  <b>Detail proses internal belum tersedia</b>
                  <span>Bagian yang paling lambat di dalam aliran data masih perlu diukur</span>
                </div>
                <div className="gap">
                  <i className="fa-solid fa-circle-exclamation" />
                  <b>Detail pemrosesan database belum tersedia</b>
                  <span>Penyebab dari sisi query atau database belum dapat dipastikan</span>
                </div>
              </div>
            </section>
          )}

          <section id="statistics" className="stats-section report-section">
            <div className="section-title">
              <div>
                <span className="section-no">03</span>
                <div>
                  <span className="kicker">
                    CAKUPAN PACKAGE
                  </span>
                  <h2>Asal 167 package pada laporan utama</h2>
                </div>
              </div>
              <p>Source: static scan dan active-job mapping</p>
            </div>
            <div className="stats-table-wrap">
              <table className="stats-table">
                <thead>
                  <tr>
                    <th>Tahap assessment</th>
                    <th>Jumlah</th>
                    <th>Cakupan dan arti</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td>
                      <strong>Static scan</strong>
                    </td>
                    <td>
                      <b>781</b>
                    </td>
                    <td>Seluruh package DTSX yang berhasil dipindai.</td>
                  </tr>
                  <tr>
                    <td>
                      <strong>Static clue tersedia</strong>
                    </td>
                    <td>
                      <b>740</b>
                    </td>
                    <td>
                      Memiliki minimal satu indikator pada selected static
                      rules; bukan causal proof.
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <strong>Tanpa selected static rule</strong>
                    </td>
                    <td>
                      <b>41</b>
                    </td>
                    <td>
                      Tetap berada dalam assessment, tetapi tidak memicu rule
                      yang dihitung.
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <strong>Active-job mapping</strong>
                    </td>
                    <td>
                      <b>178</b>
                    </td>
                    <td>Baris mapping job step/package sebelum deduplikasi.</td>
                  </tr>
                  <tr>
                    <td>
                      <strong>Active package unik</strong>
                    </td>
                    <td>
                      <b>165</b>
                    </td>
                    <td>Package unik yang masuk cohort active-job/runtime.</td>
                  </tr>
                  <tr>
                    <td>
                      <strong>Package pada laporan utama</strong>
                    </td>
                    <td>
                      <b>167</b>
                    </td>
                    <td>
                      Dokumen hasil grouping lokasi/module; dua package
                      tambahan berasal dari command/package mapping mismatch.
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div className="population-note">
              <i className="fa-solid fa-circle-info" />
              <p>
                <b>616 package berada di luar cohort active-job unik.</b> Status
                ini bukan pernyataan bahwa package sehat atau bebas finding.
                Package dapat bersifat dormant/manual/child, berada di luar
                observation window, atau belum memiliki mapping runtime/job yang
                cukup kuat.
              </p>
            </div>
          </section>

          <section id="static-findings" className="stats-section report-section">
            <div className="section-title">
              <div>
                <span className="section-no">04</span>
                <div>
                  <span className="kicker">INDIKATOR DESAIN PACKAGE</span>
                  <h2>Statistik hasil pemeriksaan static</h2>
                </div>
              </div>
              <p>V12 scanner · 781 DTSX</p>
            </div>
            <div className="stats-table-wrap static-stats-wrap">
              <table className="stats-table static-stats-table">
                <thead>
                  <tr>
                    <th>Kategori</th>
                    <th>Package laporan utama</th>
                    <th>Package dari seluruh scan</th>
                    <th>Jumlah kemunculan</th>
                    <th>Status evidence</th>
                  </tr>
                </thead>
                <tbody>
                  {staticFindingStatistics.map((item) => (
                    <tr key={item.category}>
                      <td><strong>{item.category}</strong></td>
                      <td><b>{format(item.canonicalPackages)}</b></td>
                      <td>{format(item.scanPackages)}</td>
                      <td>{format(item.occurrences)}</td>
                      <td><span className="static-status">Indikator static</span></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="population-note">
              <i className="fa-solid fa-circle-info" />
              <p>
                <b>Package laporan utama</b> adalah jumlah lokasi package unik pada
                167 hasil aggregate. <b>Package dari seluruh scan</b> adalah package
                terdampak dari 781 DTSX, sedangkan <b>jumlah kemunculan</b>
                menghitung rule/component yang ditemukan. Angka ini merupakan
                inventory static dan bukan bukti bottleneck atau root cause runtime.
              </p>
            </div>
          </section>

          <section id="visuals" className="report-section">
            <div className="section-title">
              <div>
                <span className="section-no">05</span>
                <div>
                  <span className="kicker">PROFIL DURASI PROSES</span>
                  <h2>Package dengan dampak runtime terbesar</h2>
                </div>
              </div>
              <p>Source: package runtime summary</p>
            </div>
            <div className="chart-grid">
              <article className="panel chart-wide">
              <div className="panel-head">
                <div>
                  <span className="kicker">PROFIL RUNTIME · RATA-RATA</span>
                  <h3>10 package dengan rata-rata durasi tertinggi</h3>
                  <p className="chart-note">
                    Diurutkan berdasarkan average duration pada package summary.
                    Average dapat dipengaruhi outlier; nilai maximum ditampilkan
                    terpisah. Median dan P95 belum ditampilkan jika population
                    pembanding yang memadai belum tersedia.
                  </p>
                </div>
                <span className="badge">Top 10</span>
              </div>
              <AverageDurationChart accent={config.accent} />
              <div className="outlier-note">
                <i className="fa-solid fa-wave-square" />
                <div>
                  <b>Outlier yang teramati</b>
                  <p>
                    <code>DWH_SMALLERTABLES.dtsx</code> mencapai maksimum
                    117.315,65 detik (32,59 jam), sedangkan average-nya 3.116,10
                    detik. Nilai maksimum tetap tersedia pada source data dan
                    harus dianalisis sebagai execution yang teramati, bukan
                    dianggap sebagai durasi yang selalu terjadi.
                  </p>
                </div>
              </div>
              </article>
              <article className="panel chart-wide">
              <div className="panel-head">
                <div>
                  <span className="kicker">PROFIL RUNTIME · AKUMULASI</span>
                  <h3>10 package dengan akumulasi durasi terbesar</h3>
                  <p className="chart-note">
                    Akumulasi durasi dihitung dari average duration dikalikan
                    jumlah execution. Metrik ini menunjukkan dampak terhadap
                    workload, bukan durasi yang selalu terjadi.
                  </p>
                </div>
                <span className="badge">Top 10</span>
              </div>
              <CumulativeRuntimeChart accent={config.accent} />
              </article>
              <article className="panel chart-wide priority-distribution-panel">
                <div className="panel-head">
                  <div>
                    <span className="kicker">PRIORITAS ACTIVE JOB</span>
                    <h3>Distribusi prioritas relasi job-step-package</h3>
                    <p className="chart-note">
                      Source: active-job report V12, 178 baris sebelum deduplikasi
                      package. Angka ini bukan jumlah package unik.
                    </p>
                  </div>
                  <span className="badge">178 baris</span>
                </div>
                <ActiveJobPriorityChart />
                <div className="priority-definitions">
                  <div><b>P0 · Kritis</b><span>Masalah kritis yang dampaknya sudah terbukti dan memerlukan perhatian segera. Tidak ada baris active job berstatus P0 pada report ini.</span></div>
                  <div><b>P1 · Tinggi</b><span>Runtime atau reliability berdampak tinggi berdasarkan evidence yang tersedia; tetap memerlukan controlled test sebelum perubahan produksi.</span></div>
                  <div><b>P2 · Menengah</b><span>Kandidat optimasi atau investigasi dengan dampak sedang, confidence terbatas, atau dependency yang perlu diselesaikan.</span></div>
                  <div><b>P3 · Rendah</b><span>Investigation clue, preventive review, atau kandidat dengan dampak runtime yang lebih rendah dan dapat dijadwalkan setelah prioritas di atasnya.</span></div>
                </div>
              </article>
            {/* <article className="panel chart-reliability">
              <div className="panel-head">
                <div>
                  <span className="kicker">RELIABILITY</span>
                  <h3>Execution outcomes</h3>
                </div>
                <span className="badge warning">1,68% non-success</span>
              </div>
              <ReliabilityChart accent={config.accent} />
            </article> */}
            </div>
          </section>

          <section id="findings" className="report-section">
            <div className="section-title">
              <div>
                <span className="section-no">06</span>
                <div>
                  <span className="kicker">PRIORITAS BERDASARKAN EVIDENCE</span>
                  <h2>Prioritas tindakan berdasarkan evidence</h2>
                </div>
              </div>
              <p>{findings.length} prioritas assessment · static inventory dipisahkan</p>
            </div>
            <div className="finding-list">
              {findings.map((f, i) => (
                <article className="finding" key={f.id}>
                  <div className="finding-index">
                    {String(i + 1).padStart(2, "0")}
                  </div>
                  <div className="finding-body">
                    <div className="finding-top">
                      <div>
                        <span
                          className={`priority ${f.priority.toLowerCase()}`}
                        >
                          {f.priority}
                        </span>
                        <span className="action">{f.type}</span>
                      </div>
                      <span className="confidence">{f.confidence}</span>
                    </div>
                    <h3>{f.title}</h3>
                    <p className="scope">{f.scope}</p>
                    {findingImages[f.id] && (
                      <div className={`finding-images ${findingImages[f.id].length > 1 ? "finding-images-multiple" : ""}`}>
                        {findingImages[f.id].map((item) => (
                          <figure key={item.caption}>
                            <div className="finding-image-frame">
                              <Image src={item.source} alt={item.caption} fill sizes="(max-width: 800px) 100vw, 720px" />
                            </div>
                            <figcaption>{item.caption}</figcaption>
                          </figure>
                        ))}
                      </div>
                    )}
                    <div className="finding-grid">
                      <div>
                        <b>Temuan dan bukti</b>
                        <p>{f.evidence}</p>
                      </div>
                      <div>
                        <b>Dugaan penyebab</b>
                        <p>{f.hypothesis}</p>
                      </div>
                      <div>
                        <b>Cara memastikan</b>
                        <p>{f.validation}</p>
                      </div>
                      <div>
                        <b>Hasil yang diharapkan dan batas keamanan</b>
                        <p>{f.guardrail}</p>
                      </div>
                      <div>
                        <b>Kondisi rollback</b>
                        <p>{f.rollback}</p>
                      </div>
                    </div>
                  </div>
                </article>
              ))}
            </div>
          </section>

          {config.showRoadmap && (
            <section id="roadmap" className="evidence finding-documents-evidence report-section">
              <div>
                <span className="section-no light">07</span>
                <span className="kicker light">DOKUMEN DETAIL TEMUAN</span>
                <h2>Dokumen pemeriksaan per package</h2>
                <p>167 dokumen temuan tersedia untuk pemeriksaan lebih lanjut.</p>
              </div>
              <div className="finding-documents-content">
                <h3>Lihat bukti dan rencana pemeriksaan untuk setiap package.</h3>
                <p>
                  Halaman utama ini merangkum baseline, dampak, dan prioritas.
                  Dokumen detail menyediakan lokasi package atau component,
                  static evidence, hipotesis, metode validasi, kriteria keberhasilan,
                  dan rollback untuk masing-masing package. Dokumen tersebut adalah
                  catatan pemeriksaan, bukan bukti otomatis bahwa static clue
                  merupakan penyebab masalah runtime.
                </p>
                <a className="detail-primary no-print" href="/findings">
                  <span>Lihat seluruh dokumen temuan</span>
                  <i className="fa-solid fa-arrow-right" />
                </a>
              </div>
            </section>
          )}

          <footer>
            <span>{assessment.id} · Confidential assessment documentation</span>
            <span>Evidence source: assessments/{assessment.id}</span>
          </footer>
        </div>
      </div>

      <div className="floating-actions no-print">
        <button aria-label="Customize report" onClick={() => setOpen(true)}>
          <i className="fa-solid fa-sliders" />
          <span>Customize</span>
        </button>
        <button className="export" onClick={() => window.print()}>
          <i className="fa-solid fa-file-pdf" />
          <span>Export PDF · A4</span>
        </button>
      </div>
      {open && (
        <div
          className="drawer-backdrop no-print"
          onClick={() => setOpen(false)}
        >
          <aside className="drawer" onClick={(e) => e.stopPropagation()}>
            <div className="drawer-head">
              <div>
                <span className="kicker">REPORT SETTINGS</span>
                <h2>Customize</h2>
              </div>
              <button onClick={() => setOpen(false)}>
                <i className="fa-solid fa-xmark" />
              </button>
            </div>
            <label>
              Report title
              <input
                value={config.title}
                onChange={(e) => update({ title: e.target.value })}
              />
            </label>
            <label>
              Client / organization
              <input
                value={config.client}
                onChange={(e) => update({ client: e.target.value })}
              />
            </label>
            <label>
              Executive note
              <textarea
                rows={4}
                value={config.note}
                onChange={(e) => update({ note: e.target.value })}
              />
            </label>
            <label>
              Accent color
              <div className="color-row">
                <input
                  type="color"
                  value={config.accent}
                  onChange={(e) => update({ accent: e.target.value })}
                />
                <code>{config.accent}</code>
              </div>
            </label>
            <label className="toggle">
              <input
                type="checkbox"
                checked={config.showEvidence}
                onChange={(e) => update({ showEvidence: e.target.checked })}
              />
              <span>Tampilkan cakupan analisis</span>
            </label>
            <label className="toggle">
              <input
                type="checkbox"
                checked={config.showRoadmap}
                onChange={(e) => update({ showRoadmap: e.target.checked })}
              />
              <span>Show finding document links</span>
            </label>
            <button className="reset" onClick={() => update(defaults)}>
              Reset defaults
            </button>
            <p className="drawer-note">
              Settings disimpan hanya di browser ini. Gunakan Export PDF setelah
              preview sesuai.
            </p>
          </aside>
        </div>
      )}
    </main>
  );
}
