• P0–P3 adalah level prioritas tindakan, bukan ranking langsung berdasarkan durasi package.

Definisinya ada di GLOSSARY.md:

Level Arti Kriteria
━━━━━━━ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
P0 Critical Masalah sangat serius, terbukti, dan perlu tindakan segera
─────── ────────────────────────────── ─────────────────────────────────────────────────────────────────────────────
P1 High Priority Masalah performance/reliability dengan dampak operasional besar dan
evidence kuat
─────── ────────────────────────────── ─────────────────────────────────────────────────────────────────────────────
P2 Medium Priority Investigasi atau optimasi dengan dampak sedang atau penyebab belum terbukti
─────── ────────────────────────────── ─────────────────────────────────────────────────────────────────────────────
P3 Optimization / Investigation Dampak rendah, preventive, housekeeping, atau evidence belum cukup

Mengapa report memiliki level tersebut?

- P1 diberikan ke workload seperti Seq_Staging_SIGAP, AWL, SPARTA, DAILY, dan DWH Grading karena durasi atau
  cumulative runtime sudah terbukti tinggi, atau terdapat failure operasional.

- P2 diberikan ke kandidat seperti kompleksitas Data Flow, Sort, Aggregate, atau runtime variability karena
  indikasinya ada, tetapi penyebab bottleneck belum terbukti.

- P3 diberikan ke warning cleanup seperti unused output column dan metadata warning karena dampak performance belum
  terbukti dan risikonya relatif rendah.

- P0 tidak digunakan karena tidak ada bukti masalah yang memenuhi kriteria critical/immediate.

Penting: CROSS JOIN, SELECT \*, Sort, atau Aggregate tidak otomatis menjadi P1. Anti-pattern statik baru layak naik ke
P1 apabila didukung runtime evidence seperti durasi tinggi, frekuensi tinggi, cumulative impact, atau failure.

Dalam report prioritas job aktif yang baru dibuat, urutan Rank berdasarkan duration package. Itu berbeda dari P0–P3:

- Rank = urutan workload berdasarkan waktu execution.
- P0–P3 = urgensi dan kekuatan evidence untuk tindakan.

Jadi package dengan rank tinggi belum otomatis P1; perlu melihat durasi, frekuensi, failure, anti-pattern, confidence,
dan risiko perubahan secara bersamaan.
