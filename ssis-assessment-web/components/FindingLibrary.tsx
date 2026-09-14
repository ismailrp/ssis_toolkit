"use client";
import { useEffect, useMemo, useState } from "react";
import type { FindingDocument } from "@/lib/finding-documents";

export default function FindingLibrary({ documents }: { documents: FindingDocument[] }) {
  const [query, setQuery] = useState("");
  const [duplicatesOnly, setDuplicatesOnly] = useState(false);
  useEffect(() => { setQuery(new URLSearchParams(window.location.search).get("q") ?? ""); }, []);
  const visible = useMemo(() => {
    const needle = query.trim().toLowerCase();
    return documents.filter((item) => (!duplicatesOnly || item.duplicateId) && (!needle || `${item.findingId} ${item.packageName} ${item.subject} ${item.fileName}`.toLowerCase().includes(needle)));
  }, [documents, query, duplicatesOnly]);
  const unique = new Set(documents.map((item) => item.findingId)).size;

  return <main className="library-page">
    <aside className="rail no-print"><a className="rail-brand" href="/"><span>SI</span><b>SSIS<br/>Assessment</b></a><nav><a href="/">← Assessment report</a><a className="rail-feature-link" href="#documents">Finding documents</a></nav><div className="rail-foot"><span className="live-dot"/> {documents.length} files indexed</div></aside>
    <div className="report-shell">
      <header className="library-hero"><p className="kicker">DOCUMENT REGISTER · TRACEABLE OUTPUT</p><h1>Finding<br/>Documents</h1><p>Indeks dokumen detail yang dihasilkan dari assessment EVSET-45D-COMPLETE. Setiap link mengunduh file asli dari folder results tanpa membuat salinan.</p></header>
      <section className="library-summary"><article><span>DOCX FILES</span><strong>{documents.length}</strong><small>physical documents</small></article><article><span>UNIQUE FINDINGS</span><strong>{unique}</strong><small>Finding-001 through Finding-167</small></article><article><span>DUPLICATE ID</span><strong>{documents.filter(x => x.duplicateId).length}</strong><small>two files share Finding-001</small></article></section>
      <section id="documents" className="library-content">
        <div className="section-title"><div><span className="section-no">01</span><div><span className="kicker">FULL REGISTER</span><h2>Browse assessment evidence.</h2></div></div><p>{visible.length} documents shown</p></div>
        <div className="library-tools no-print"><label><i className="fa-solid fa-magnifying-glass"/><input type="search" value={query} onChange={e => setQuery(e.target.value)} placeholder="Cari finding, package, atau subject…"/></label><button className={duplicatesOnly ? "active" : ""} onClick={() => setDuplicatesOnly(value => !value)}>Duplicate ID only</button></div>
        <div className="document-grid">{visible.map((item) => <article className="document-card" key={item.fileName}><div className="document-id"><span>FINDING</span><strong>{item.findingId}</strong></div><div className="document-copy">{item.duplicateId && <span className="duplicate-badge">DUPLICATE ID / REVIEW</span>}<h3>{item.packageName}</h3><p>{item.subject}</p><small>{(item.size / 1024).toFixed(1)} KB · DOCX</small></div><a className="download no-print" href={`/api/findings/${encodeURIComponent(item.fileName)}`} title={`Download ${item.fileName}`}><i className="fa-solid fa-arrow-down"/><span>Download</span></a></article>)}</div>
      </section>
      <footer><span>EVSET-45D-COMPLETE · Finding document register</span><span>Source: results/package_findings_detail</span></footer>
    </div>
  </main>;
}
