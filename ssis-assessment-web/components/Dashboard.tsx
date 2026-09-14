"use client";
import { useEffect, useState } from "react";
import { assessment, durationLeaders, findings } from "@/data/assessment";
import {
  AverageDurationChart,
  CumulativeRuntimeChart,
  ReliabilityChart,
} from "./Charts";

type Config = {
  client: string;
  title: string;
  accent: string;
  note: string;
  showEvidence: boolean;
  showRoadmap: boolean;
};
const defaults: Config = {
  client: "Enterprise Data Platform",
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
    if (saved) setConfig({ ...defaults, ...JSON.parse(saved) });
  }, []);
  useEffect(() => {
    const sections = document.querySelectorAll<HTMLElement>(
      ".content > section:not(.detail-bridge):not(.stats-section)",
    );
    const ids = [
      "executive",
      "visuals",
      "findings",
      ...(config.showEvidence ? ["coverage"] : []),
      "baseline",
      ...(config.showRoadmap ? ["roadmap"] : []),
    ];
    ids.forEach((id, index) => sections[index]?.setAttribute("id", id));
  }, [config.showEvidence, config.showRoadmap]);
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
          <span>SI</span>
          <b>
            SSIS
            <br />
            Assessment
          </b>
        </a>
        <nav>
          <a href="#executive">Executive overview</a>
          <a href="#visuals">Visual analysis</a>
          <a href="#statistics">Package statistics</a>
          <a href="#findings">Priority findings</a>
          <a href="#coverage">Cakupan analisis</a>
          <a href="#baseline">Package baseline</a>
          <a href="#roadmap">Finding documents</a>
          <a className="rail-feature-link" href="/findings">
            All finding documents →
          </a>
        </nav>
        <div className="rail-foot">
          <span className="live-dot" /> Evidence loaded
        </div>
      </aside>
      <div className="report-shell" id="top">
        <header className="hero report-section">
          <nav>
            <div className="brand">
              <span className="brand-mark">S</span>
              <span>SSIS / PERFORMANCE OFFICE</span>
            </div>
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
          <section className="intro report-section">
            <div>
              <span className="section-no">01</span>
              <div>
                <span className="kicker">EXECUTIVE OVERVIEW</span>
                <h2>Executive perspective</h2>
              </div>
            </div>
            <div>
              <p className="lead">
                Assessment ini menyediakan baseline runtime dan reliability yang
                defensible, tetapi belum membuktikan component-level atau
                database-side root cause.
              </p>
              <p>
                Prioritas saat ini adalah melengkapi observability, menelusuri
                dua hotspot terarah, dan memperbaiki masalah koneksi
                tervalidasi. Static anti-pattern tetap diperlakukan sebagai
                investigation clue—bukan bukti bottleneck.
              </p>
            </div>
          </section>

          <section id="statistics" className="stats-section report-section">
            <div className="section-title">
              <div>
                <span className="section-no">02</span>
                <div>
                  <span className="kicker">
                    PACKAGE POPULATION & DISPOSITION
                  </span>
                  <h2>Disposisi 167 packages</h2>
                </div>
              </div>
              <p>-</p>
            </div>
            <div className="stats-table-wrap">
              <table className="stats-table">
                <thead>
                  <tr>
                    <th>Tahap assessment</th>
                    <th>Jumlah</th>
                    <th>Population / interpretation</th>
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
                      <strong>Finding canonical</strong>
                    </td>
                    <td>
                      <b>167</b>
                    </td>
                    <td>
                      Dokumen hasil grouping lokasi/module; dua package
                      menghasilkan lebih dari satu finding.
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

          <section className="chart-grid report-section">
            <article className="panel chart-wide">
              <div className="panel-head">
                <div>
                  <span className="kicker">RUNTIME PROFILE · AVERAGE</span>
                  <h3>Top 10 average package duration</h3>
                  <p className="chart-note">
                    Diurutkan berdasarkan avg_duration_sec pada seluruh package
                    summary. Maximum duration dipisahkan agar outlier tidak
                    merusak skala average.
                  </p>
                </div>
                <span className="badge">Top 10</span>
              </div>
              <AverageDurationChart accent={config.accent} />
              <div className="outlier-note">
                <i className="fa-solid fa-wave-square" />
                <div>
                  <b>Observed outlier</b>
                  <p>
                    <code>DWH_SMALLERTABLES.dtsx</code> mencapai maksimum
                    117.315,65 detik (32,59 jam), sedangkan average-nya 3.116,10
                    detik. Nilai maksimum tetap tersedia pada tabel baseline dan
                    harus dianalisis sebagai observed execution, bukan dianggap
                    typical runtime.
                  </p>
                </div>
              </div>
            </article>
            <article className="panel chart-wide">
              <div className="panel-head">
                <div>
                  <span className="kicker">RUNTIME PROFILE · CUMULATIVE</span>
                  <h3>Top 10 cumulative runtime consumers</h3>
                  <p className="chart-note">
                    Derived cumulative hours = avg_duration_sec × executions.
                    Metric ini menunjukkan workload impact, bukan typical
                    latency.
                  </p>
                </div>
                <span className="badge">Top 10</span>
              </div>
              <CumulativeRuntimeChart accent={config.accent} />
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
          </section>

          <section className="report-section">
            <div className="section-title">
              <div>
                <span className="section-no">03</span>
                <div>
                  <span className="kicker">PRIORITIZED REGISTER</span>
                  <h2>Evidence-backed findings</h2>
                </div>
              </div>
              <p>{findings.length} actionable findings</p>
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
                    <div className="finding-grid">
                      <div>
                        <b>Observation & evidence</b>
                        <p>{f.evidence}</p>
                      </div>
                      <div>
                        <b>Hypothesis</b>
                        <p>{f.hypothesis}</p>
                      </div>
                      <div>
                        <b>Validation</b>
                        <p>{f.validation}</p>
                      </div>
                      <div>
                        <b>Success / guardrail</b>
                        <p>{f.guardrail}</p>
                      </div>
                    </div>
                  </div>
                </article>
              ))}
            </div>
          </section>

          {config.showEvidence && (
            <section className="evidence report-section">
              <div>
                <span className="section-no light">04</span>
                <span className="kicker light">CAKUPAN ANALISIS</span>
                <h2>Apa yang sudah dapat dinilai?</h2>
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

          <section className="report-section">
            <div className="section-title">
              <div>
                <span className="section-no">05</span>
                <div>
                  <span className="kicker">PACKAGE BASELINE</span>
                  <h2>Top 10 by average duration</h2>
                </div>
              </div>
            </div>
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Rank by avg</th>
                    <th>Package / project</th>
                    <th>Avg duration</th>
                    <th>Max duration</th>
                    <th>Interpretation</th>
                  </tr>
                </thead>
                <tbody>
                  {durationLeaders.map((x, i) => (
                    <tr key={`${x.project}|${x.package}`}>
                      <td>{String(i + 1).padStart(2, "0")}</td>
                      <td>
                        <strong>{x.package}</strong>
                        <small>{x.project}</small>
                      </td>
                      <td>{duration(x.avg)}</td>
                      <td>{duration(x.max)}</td>
                      <td>
                        <span className="status-dot" />
                        {x.max > 30000 ? "Average rank · max outlier" : "Average-duration rank"}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          {config.showRoadmap && (
            <section id="roadmap" className="detail-bridge report-section">
              <div className="detail-bridge-copy">
                <span className="section-no light">06</span>
                <span className="kicker light">
                  ASSESSMENT TO PACKAGE DETAIL
                </span>
                <h2>Setiap prioritas dapat ditelusuri ke dokumen finding.</h2>
                <p>
                  Report ini menyajikan baseline, impact, dan urutan investigasi
                  pada level assessment. Untuk melihat static evidence, lokasi
                  package/component, hypothesis, validation method, success
                  criteria, dan rollback per package, lanjutkan ke register
                  detail. Dokumen tersebut adalah investigation record—bukan
                  bukti otomatis bahwa static clue merupakan root cause runtime.
                </p>
                <a className="detail-primary no-print" href="/findings">
                  <span>Explore all 167 findings</span>
                  <i className="fa-solid fa-arrow-right" />
                </a>
              </div>
              <div className="detail-links">
                <span className="detail-label">DIRECT INVESTIGATION LINKS</span>
                <a href="/findings?q=002">
                  <b>Finding-002</b>
                  <span>Seq_Staging_SIGAP · confirmed elapsed location</span>
                  <i className="fa-solid fa-arrow-up-right-from-square" />
                </a>
                <a href="/findings?q=053">
                  <b>Finding-053</b>
                  <span>AWL / Staging · API-to-STG tracing target</span>
                  <i className="fa-solid fa-arrow-up-right-from-square" />
                </a>
                <a href="/findings?q=067">
                  <b>Finding-067</b>
                  <span>AI Grading / Staging · reliability evidence</span>
                  <i className="fa-solid fa-arrow-up-right-from-square" />
                </a>
                <a href="/findings?q=046">
                  <b>Finding-046</b>
                  <span>Seq_Staging_NON_SAP · connection validation</span>
                  <i className="fa-solid fa-arrow-up-right-from-square" />
                </a>
                <a href="/findings?q=081">
                  <b>Finding-081</b>
                  <span>Seq_Staging_WB · connection validation</span>
                  <i className="fa-solid fa-arrow-up-right-from-square" />
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
