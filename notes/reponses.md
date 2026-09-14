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
