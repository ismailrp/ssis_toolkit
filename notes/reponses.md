• Karena 938 package catalog dan 781 package static bukan dua daftar dengan hubungan subset sederhana. Saat dibandingkan
menggunakan key:

Folder | Project | Package

terdapat tiga kelompok:

Kelompok Jumlah Penjelasan
━━━━━━━━━━━━━━━━━━━━━━ ━━━━━━━━ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Ada di kedua sumber 581 Key ditemukan di catalog dan static extraction
────────────────────── ──────── ────────────────────────────────────────────────
Hanya ada di catalog 357 Tidak mempunyai exact match pada static
────────────────────── ──────── ────────────────────────────────────────────────
Hanya ada di static 200 Tidak mempunyai exact match pada catalog

Maka:

Catalog = 581 cocok + 357 catalog-only
= 938

Static = 581 cocok + 200 static-only
= 781

Itulah alasan rumus sebelumnya menggunakan pengurangan dan penambahan:

938 catalog
− 357 catalog-only
= 581 package yang cocok

581 package yang cocok

- 200 static-only
  = 781 static package

Jadi bukan berarti 200 package baru ditambahkan untuk menutupi kehilangan. Rumus tersebut hanya menjelaskan komposisi
dua population berbeda.

Contoh sederhananya:

Catalog:
FolderA | ProjectA | Package1
FolderA | ProjectA | Package2

Static:
FolderA | ProjectA_NEW | Package1
FolderA | ProjectA | Package2

Secara fisik Package1 mungkin package yang sama. Namun karena nama project berubah menjadi ProjectA_NEW, exact key
menganggap:

- satu package hanya ada di catalog;
- satu package hanya ada di static.

Pada evidence nyata, pola seperti ini terlihat pada sekitar 80 package:

Catalog : Development | BGADWH_SSIS
Static : Development | Dev_BGADWH_SSIS

Ringkasnya:

938 catalog
├── 581 exact match dengan static
└── 357 belum exact match

781 static
├── 581 exact match dengan catalog
└── 200 belum exact match

Karena itu, kita belum boleh menyatakan ada tepat 157 package hilang. Yang terbukti adalah terdapat 157 net difference
dan 557 key mismatch records pada kedua sisi (357 + 200) yang perlu direkonsiliasi berdasarkan rename, snapshot,
folder/project, serta kegagalan extraction.

---

• Angka 178 bukan jumlah package unik hasil static anti-pattern scan. Itu adalah jumlah baris kombinasi:

SQL Agent job + step + SSIS package

di results/ACTIVE_JOB_DTSX_ANTIPATTERN_PRIORITY_EVSET-45D-COMPLETE-V12.csv.

Rinciannya:

Tahap Jumlah
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ━━━━━━━━
Seluruh package static yang dipindai 781
──────────────────────────────────────── ────────
Baris active-job/package exact mapping 178
──────────────────────────────────────── ────────
Package path unik dalam 178 baris 165
──────────────────────────────────────── ────────
Package tambahan dari mapping mismatch 2
──────────────────────────────────────── ────────
Hasil aggregate per lokasi DTSX unik 167

Mengapa 178 menjadi 165 package unik? Karena package yang sama dapat dipanggil oleh beberapa job/step. Ada 13 baris
duplikat setelah dikelompokkan berdasarkan lokasi DTSX:

- CHECK_QUERY_DATA.dtsx: 10 baris → 1 package, mengurangi 9
- DWH_ZVT_MSEGPF.dtsx: 2 → 1, mengurangi 1
- DWH-COEP.dtsx: 2 → 1, mengurangi 1
- FACT_CIVIL_ENGINEERING.dtsx: 2 → 1, mengurangi 1
- FACT_DD_TBS.dtsx: 2 → 1, mengurangi 1

Jadi:

178 baris active-job

- 13 duplikasi lokasi package
  = 165 package unik

Kemudian aggregate memasukkan dua package unik dari report mapping mismatch:

- Project_Fact/MILL_COST_PROJECT/STG_FOR_DIM_MILL_COST.dtsx
- Project_Fact/Segregation/Staging Segregation.dtsx

Sehingga:

165 package exact unik

- 2 package mismatch unik
  = 167 aggregate package

Ini sesuai logika build_dtsx_aggregate_report.ps1:31, yang menggabungkan exact, mismatch, dan candidate lalu melakukan
Group-Object Location. Jadi 167 adalah jumlah lokasi DTSX unik, sementara 178 adalah jumlah relasi job-step-package,
bukan jumlah package unik. Kandidat command/time tidak menambah package unik baru.
