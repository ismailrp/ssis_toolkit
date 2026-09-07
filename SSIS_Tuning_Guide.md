### **1. Query Sumber & Desain SQL**

**Hindari `SELECT \***`

- **Penjelasan:** Mengambil semua kolom (termasuk kolom teks panjang) memperbesar ukuran baris data (_row width_), yang membuat buffer SSIS cepat penuh dan memicu I/O disk berlebih.
- **Contoh:** `SELECT * FROM dbo.FactSales`
- **Solusi Terbaik:** Pilih hanya kolom yang benar-benar akan diproses.

```sql
SELECT CustomerID, OrderDate, TotalAmount FROM dbo.FactSales

```

**Gunakan Kueri _SARGable_**

- **Penjelasan:** Penggunaan fungsi atau manipulasi pada kolom di klausa `WHERE`/`JOIN` membuat SQL Server tidak bisa menggunakan indeks (_Index Scan_ alih-alih _Index Seek_).
- **Contoh:** `WHERE YEAR(OrderDate) = 2026` atau `WHERE UPPER(Status) = 'ACTIVE'`
- **Solusi Terbaik:** Bandingkan nilai kolom secara langsung tanpa membalutnya dengan fungsi.

```sql
WHERE OrderDate >= '2026-01-01' AND OrderDate < '2027-01-01'

```

**Hindari Cartesian / Accidental Cross Join**

- **Penjelasan:** Menggabungkan tabel tanpa kondisi penggabungan yang spesifik memicu perkalian jumlah baris secara masif ($M \times N$).
- **Contoh:** `SELECT * FROM Orders, Customers` (lupa menambahkan klausa pembanding).
- **Solusi Terbaik:** Gunakan sintaks `INNER JOIN` atau `LEFT JOIN` eksplisit lengkap dengan klausanya.

```sql
SELECT o.OrderID, c.CustomerName
FROM dbo.Orders o
INNER JOIN dbo.Customers c ON o.CustomerID = c.CustomerID

```

**Optimasi View Bertumpuk / Unindexed View**

- **Penjelasan:** Mengambil data dari _view_ biasa yang didalamnya memanggil _view_ lain secara bertumpuk (_nested views_) memaksa mesin SQL mengeksekusi ulang seluruh logika dasar yang sangat kompleks.
- **Contoh:** Kueri memanggil `vw_SalesSummary` yang dibuat dari `vw_OrderDetails`, di mana `vw_OrderDetails` menggabungkan 5 tabel operasional.
- **Solusi Terbaik:** Buat _Indexed View_ jika memungkinkan, atau ganti dengan kueri SQL langsung yang sudah dioptimasi.

**Terapkan Filter Pushdown**

- **Penjelasan:** Mengalirkan seluruh data dari database ke SSIS Data Flow lalu menyaringnya menggunakan komponen `Conditional Split` membuang-buang kapasitas memori dan jaringan.
- **Contoh:** Mengalirkan 50 juta baris data ke SSIS Canvas hanya untuk membuang data yang bukan tanggal hari ini.
- **Solusi Terbaik:** Tapis data langsung di level database (_SQL Source Query_) menggunakan variabel SSIS.

```sql
SELECT * FROM Sales WHERE ModifiedDate >= @[User::LastRunDate]

```

**Jaga Kebugaran Statistik & Indeks**

- **Penjelasan:** _Query Optimizer_ memilih strategi eksekusi (_Execution Plan_) yang buruk jika estimasi jumlah baris tidak akurat akibat statistik data yang sudah kadaluarsa.
- **Contoh:** Kueri menggunakan _Table Scan_ pada tabel puluhan juta baris karena statistik membaca tabel tersebut masih kosong.
- **Solusi Terbaik:** Buat _Maintenance Plan_ rutin untuk `UPDATE STATISTICS` dan penataan ulang indeks (`ALTER INDEX REBUILD/REORGANIZE`).

**Hindari Kalkulasi/Parsing _On-the-Fly_ Per Baris**

- **Penjelasan:** Menjalankan operasi pemrosesan string atau rumus matematika rumit pada setiap baris di kueri sumber membebankan CPU server database secara intensif.
- **Contoh:** `SELECT SUBSTRING(Code, 1, 3) + CAST(ID AS VARCHAR) FROM BigTable`
- **Solusi Terbaik:** Simpan hasil kalkulasi dalam _computed column_ berindeks saat data pertama kali masuk, atau lakukan kalkulasi berbasis set data.

**Tahapkan Pemrosesan `PIVOT`/Window Function**

- **Penjelasan:** Operasi `PIVOT`/`UNPIVOT` atau _Window Function_ ber-frame lebar (`ROW_NUMBER() OVER (...)`) pada volume data besar di dalam CTE memakan ruang `tempdb` yang sangat tinggi dan memicu proses pengurutan (_Sort_) yang mahal.
- **Contoh:** `ROW_NUMBER() OVER (PARTITION BY Region ORDER BY TransactionDate)` pada 100 juta baris di dalam CTE.
- **Solusi Terbaik:** Masukkan data ke _Temp Table_ berindeks kluster (_Clustered Index_) terlebih dahulu sebelum menjalankan fungsi agregasi atau pemutaran data.

**Gunakan _Partitioned Tables_ Alih-alih `UNION ALL**`

- **Penjelasan:** Menggabungkan puluhan tabel atau subquery secara manual menggunakan `UNION ALL` membuat SQL Server kesulitan membuat _execution plan_ yang efisien.
- **Contoh:** `SELECT * FROM Sales2024 UNION ALL SELECT * FROM Sales2025 UNION ALL ...`
- **Solusi Terbaik:** Manfaatkan fitur native _Table Partitioning_ milik SQL Server.

**Gunakan Table Hint `NOLOCK` / _Read Uncommitted_**

- **Penjelasan:** Saat membaca tabel operasional (OLTP) yang sedang aktif, kueri SSIS bisa tertahan oleh transaksi aplikasi lain (_blocking_).
- **Contoh:** Kueri SSIS menggantung (_wait status_) menunggu proses penulisan data oleh aplikasi backend selesai.
- **Solusi Terbaik:** Tambahkan hint `WITH (NOLOCK)` pada kueri sumber jika toleran terhadap _dirty read_, atau atur _Transaction Isolation Level_ ke `Read Uncommitted`.

---

### **2. Konektivitas & Provider Data**

**Gunakan Provider Native OLE DB**

- **Penjelasan:** Mesin SSIS dirancang secara native menggunakan OLE DB. Penggunaan Provider ADO.NET atau ODBC menambah lapisan penerjemah data (_wrapper overhead_) yang memperlambat pemrosesan.
- **Contoh:** Memilih _ADO.NET Connection Manager_ untuk menghubungkan SSIS ke SQL Server.
- **Solusi Terbaik:** Gunakan **MSOLEDBSQL** (_Microsoft OLE DB Driver for SQL Server_) pada seluruh _Connection Manager_.

**Aktifkan `DelayValidation = True**`

- **Penjelasan:** Secara default, SSIS mengecek ketersediaan seluruh koneksi dan struktur tabel sebelum paket dijalankan. Jika koneksi jaringan lambat atau tabel bersifat sementara, validasi ini memakan waktu lama.
- **Contoh:** Paket SSIS berhenti (_hang_) beberapa menit di awal eksekusi hanya untuk memvalidasi tabel _staging_.
- **Solusi Terbaik:** Ubah properti `DelayValidation = True` pada level _Connection Manager_ maupun _Data Flow Task_.

---

### **3. Desain & Komponen Data Flow (Canvas SSIS)**

**Eliminasi Komponen _Blocking_**

- **Penjelasan:** Komponen _blocking_ (seperti `Sort`, `Aggregate`, atau `Fuzzy Grouping`) memuat seluruh baris data ke dalam RAM sebelum meneruskan baris pertama ke komponen berikutnya. Ini menghentikan alur kerja pipeline (_pipeline stall_).
- **Contoh:** Menempatkan komponen `Sort` di tengah-tengah canvas SSIS Data Flow.
- **Solusi Terbaik:** Hapus komponen `Sort` dari SSIS. Lakukan pengurutan data (`ORDER BY`) langsung di kueri SQL sumber.

**Gunakan _Full Cache_ pada Lookup**

- **Penjelasan:** Menggunakan mode _Partial Cache_ atau _No Cache_ pada komponen _Lookup_ memaksa SSIS mengirim kueri individual ke database untuk setiap baris data yang lewat.
- **Contoh:** Memproses 1 juta baris dengan _No Cache Lookup_ menghasilkan 1 juta panggilan kueri `SELECT` ke server.
- **Solusi Terbaik:** Atur _Lookup_ ke mode **Full Cache**. Jika tabel acuan terlalu besar, tapis ukurannya menggunakan kueri SQL pada tab _Lookup Transformation_.

**Manfaatkan _Shared Cache Connection Manager_**

- **Penjelasan:** Jika beberapa Data Flow Task memerlukan data acuan (_lookup_) dari tabel yang sama, konfigurasi standar akan mengunduh dan membangun cache tersebut berulang kali di RAM.
- **Contoh:** Tiga _Data Flow Task_ berbeda masing-masing mengunggah tabel dimensi berukuran 2 GB ke RAM.
- **Solusi Terbaik:** Buat **Cache Connection Manager** terpisah. Isi data sekali saja menggunakan _Cache Transform_, lalu gunakan kembali cache tersebut di seluruh komponen _Lookup_.

**Pastikan Data Benar-Benar Terurut pada Merge Join**

- **Penjelasan:** Komponen `Merge Join` membutuhkan input yang sudah terurut. Mengatur properti `IsSorted = True` tanpa adanya pengurutan nyata dari kueri akan menghasilkan data yang rusak atau kegagalan eksekusi.
- **Contoh:** Mengubah properti `IsSorted` menjadi _True_ pada _OLE DB Source Output_ tanpa menuliskan klausa `ORDER BY` di SQL.
- **Solusi Terbaik:** Sertakan klausa `ORDER BY` pada kueri SQL, lalu set properti `IsSorted = True` dan tentukan urutan kolom pada `SortKeyPosition`.

**Pangkas Kolom Tidak Terpakai**

- **Penjelasan:** Kolom yang ikut mengalir dalam pipeline meski tidak digunakan akan memperlebar ukuran baris data (_buffer width_), sehingga kapasitas baris per buffer berkurang.
- **Contoh:** Membawa kolom deskripsi panjang `VARCHAR(8000)` dari tabel asal padahal hanya memerlukan kolom `ID` dan `Total`.
- **Solusi Terbaik:** Hapus centang pada kolom-kolom yang tidak diperlukan di tab _Columns_ pada komponen _Source_.

**Hindari Implicit Data Type Conversion**

- **Penjelasan:** Ketidakcocokan tipe data (seperti `VARCHAR` ke `NVARCHAR` atau `DT_STR` ke `DT_WSTR`) memicu konversi otomatis yang membebani CPU dan memicu kesalahan memori pada LOB/BLOB.
- **Contoh:** Kolom sumber bertipe `VARCHAR`, namun dibaca sebagai `DT_WSTR` (Unicode) oleh SSIS.
- **Solusi Terbaik:** Samakan tipe data langsung pada kueri SQL menggunakan `CAST`/`CONVERT` dan hindari penggunaan tipe data tak berbatas seperti `VARCHAR(MAX)` jika panjang data sebenarnya terbatas.

**Hindari `OLE DB Command Transformation**`

- **Penjelasan:** Komponen ini mengeksekusi perintah SQL (seperti `UPDATE` atau `INSERT`) baris demi baris untuk setiap record yang melintas.
- **Contoh:** Memproses 500.000 baris berarti mengeksekusi 500.000 kueri `UPDATE` terpisah secara berurutan.
- **Solusi Terbaik:** Gunakan pendekatan dua langkah:

1. Muat data ke tabel _Staging_ sementara menggunakan _OLE DB Destination (Fast Load)_.
2. Eksekusi satu kueri _set-based_ `UPDATE` berbasis `JOIN` menggunakan **Execute SQL Task**.

**Optimasi Script Component (.NET)**

- **Penjelasan:** Kode di dalam `Script Component` yang kurang terstruktur (seperti inisialisasi variabel atau koneksi di dalam fungsi pemroses baris) akan dieksekusi berulang jutaan kali.
- **Contoh:** Membuka koneksi database atau membaca konfigurasi file di dalam method `Input0_ProcessInputRow`.
- **Solusi Terbaik:** Pindahkan alokasi memori, pembukaan koneksi, atau pembacaan variabel ke method `PreExecute()`, lalu tutup koneksi di method `PostExecute()`.

**Jalankan Data Flow Independen Secara Paralel**

- **Penjelasan:** Menjalankan beberapa Data Flow Task secara berurutan (_serial_) padahal pemrosesan datanya tidak saling berhubungan memperlama total waktu eksekusi.
- **Contoh:** Menghubungkan _Data Flow Customer_ ke _Data Flow Product_ menggunakan garis hijau (_Precedence Constraint_).
- **Solusi Terbaik:** Biarkan _Data Flow Task_ yang independen berdiri tanpa garis penghubung (_unconnected tasks_) agar SSIS mengeksekusinya secara paralel.

---

### **4. Konfigurasi Buffer, Memori & Eksekusi Pipeline**

**Sesuaikan Ukuran Buffer**

- **Penjelasan:** Pengaturan standar SSIS (`10,000` baris / `10 MB` per buffer) sering kali terlalu kecil untuk spesifikasi server modern.
- **Contoh:** Menggunakan batas buffer default 10 MB saat memproses puluhan juta baris data.
- **Solusi Terbaik:** Aktifkan properti **AutoAdjustBufferSize** pada _Data Flow Task_, atau naikkan `DefaultBufferSize` secara manual ke rentang 100 MB–200 MB.

**Cegah Buffer Spooling ke Disk**

- **Penjelasan:** Jika alokasi RAM server tidak mencukupi, SSIS akan menulis buffer memori sementara ke harddisk (_spooling_), yang menurunkan performa pemrosesan secara drastis.
- **Contoh:** Muncul pesan peringatan pada log: _"The buffer manager failed to allocate memory..."_
- **Solusi Terbaik:** Sediakan RAM yang memadai, hilangkan komponen _blocking_, dan pastikan ukuran buffer muat di dalam memori fisik.

**Arahkan Folder Temporary ke Disk Terpisah**

- **Penjelasan:** Saat terjadi _spooling_ atau pemrosesan data besar (BLOB), SSIS secara bawaan menyimpan file sementara di drive OS (`C:\`).
- **Contoh:** Kinerja server melambat akibat drive `C:\` kehabisan ruang disk dan mengalami I/O bottleneck.
- **Solusi Terbaik:** Atur properti `BLOBTempStoragePath` dan `BufferTempStoragePath` pada _Data Flow Task_ ke drive penyimpanan lokal berkecepatan tinggi (SSD/NVMe khusus).

**Optimasi Thread & Eksekusi Paralel**

- **Penjelasan:** Batasan thread yang tidak disesuaikan dengan jumlah core CPU membuat resource server tidak dimaksimalkan.
- **Contoh:** Server memiliki 32 Core CPU, tetapi `MaxConcurrentExecutables` dibatasi hanya untuk 2 task.
- **Solusi Terbaik:** Biarkan `MaxConcurrentExecutables` pada nilai `-1` (otomatis mengikuti jumlah core CPU) dan sesuaikan properti `EngineThreads` pada Data Flow Task.

---

### **5. Tujuan / Loading ke Destination**

**Gunakan OLE DB Destination Fast Load**

- **Penjelasan:** Mode insersi standar memasukkan data baris demi baris, sedangkan mode _Fast Load_ menggunakan perintah _bulk insert_.
- **Contoh:** Memasukkan 1 juta baris memerlukan waktu beberapa jam karena dieksekusi sebagai 1 juta pernyataan `INSERT` terpisah.
- **Solusi Terbaik:** Selalu pilih opsi **OLE DB Destination - Fast Load** pada _Data Access Mode_.

**Sertakan Opsi `TABLOCK**`

- **Penjelasan:** Tanpa opsi `TABLOCK`, proses _bulk insert_ akan mengunci data di tingkat baris atau halaman, yang menimbulkan beban overhead penguncian (_locking overhead_) serta mencegah fitur _minimal logging_.
- **Contoh:** Opsi _FastLoadOptions_ hanya berisi `CHECK_CONSTRAINTS`.
- **Solusi Terbaik:** Tambahkan `TABLOCK` pada kolom _FastLoadOptions_ (contoh: `TABLOCK,CHECK_CONSTRAINTS`).

**Perbesar Commit Size**

- **Penjelasan:** Nilai _Maximum insert commit size_ yang terlalu kecil memicu proses transaksi _commit_ berulang kali ke log database.
- **Contoh:** Mengatur commit size sebesar `100` pada total 10 juta baris data memicu 100.000 kali proses transaksi commit.
- **Solusi Terbaik:** Biarkan pada nilai default `2147483647` (commit satu kali di akhir) atau atur ke angka besar seperti `100,000` hingga `500,000`.

**Nonaktifkan Indeks & Constraints Sementara**

- **Penjelasan:** Memasukkan data dalam jumlah besar ke tabel yang memiliki indeks aktif memaksa server merestrukturisasi indeks (_B-Tree rebalance_) pada setiap baris yang masuk.
- **Contoh:** Memuat 20 juta baris data ke tabel yang memiliki 5 _Non-Clustered Index_.
- **Solusi Terbaik:**

1. _Disable_ atau _Drop_ _Non-Clustered Index_ sebelum proses muat data.
2. Jalankan proses pemuatan data (_bulk load_).
3. Lakukan _Rebuild_ indeks setelah pemuatan selesai.

**Matikan Trigger Destination**

- **Penjelasan:** Keberadaan `AFTER INSERT` trigger pada tabel tujuan akan memicu eksekusi logika trigger pada setiap batch data, yang mematikan efisiensi fitur _Fast Load_.
- **Contoh:** Trigger pencatatan log audit berjalan pada setiap baris baru yang di-insert.
- **Solusi Terbaik:** Nonaktifkan trigger sementara sebelum ETL berjalan (`DISABLE TRIGGER ALL ON TargetTable`), lalu aktifkan kembali setelah proses selesai.

---

### **6. Arsitektur, Orkestrasi Job & Lingkungan Server**

**Gunakan Pola Arsitektur Parent-Child**

- **Penjelasan:** Sebuah paket SSIS raksasa (_monolithic_) yang berisi puluhan Data Flow memakan memori metadata yang besar dan sulit dikelola saat terjadi kesalahan.
- **Contoh:** Satu paket SSIS berukuran 50 MB yang menjalankan seluruh alur ETL Data Warehouse.
- **Solusi Terbaik:** Bagi paket menjadi modul-modul kecil terpisah (_child packages_), lalu panggil menggunakan **Execute Package Task** dari sebuah paket utama (_parent package_).

**Terapkan _Checkpoints_**

- **Penjelasan:** Tanpa _checkpoint_, kegagalan eksekusi di akhir proses memaksa seluruh alur ETL diulang kembali dari awal.
- **Contoh:** Paket ETL yang berjalan selama 2 jam gagal pada menit ke-110, sehingga proses jam pertama harus diulang kembali.
- **Solusi Terbaik:** Aktifkan fitur _Checkpoint_ pada Control Flow (`SaveCheckpoints = True`, `CheckpointUsage = IFEXISTS`) agar SSIS dapat melanjutkan (_resume_) eksekusi dari task terakhir yang gagal.

**Atur Urutan Eksekusi Job (Job Chaining)**

- **Penjelasan:** Beberapa job SSIS yang berjalan bersamaan dapat saling memperebutkan resource CPU, disk I/O, atau memicu penguncian tabel (_deadlock_).
- **Contoh:** Job ETL Penjualan dan Job ETL Stok barang dijadwalkan berjalan bersamaan pada pukul 01.00 dan mengakses tabel staging yang sama.
- **Solusi Terbaik:** Atur urutan eksekusi berantai (_Job Chaining_) pada SQL Server Agent atau beri jeda jadwal yang aman.

**Gunakan Incremental Load**

- **Penjelasan:** Menghapus dan memuat ulang seluruh isi tabel (_Full Reload_) setiap hari tidak efisien jika perubahan data harian hanya sebagian kecil.
- **Contoh:** Memuat ulang seluruh data histori transaksi selama 5 tahun terakhir setiap malam.
- **Solusi Terbaik:** Terapkan pola **Incremental Load** menggunakan kolom penanda waktu (`LastModifiedDate`), _Change Data Capture_ (CDC), atau _Change Tracking_.

**Optimasi `tempdb` Database**

- **Penjelasan:** `tempdb` adalah pusat pemrosesan operasi pengurutan dan pencatatan tabel sementara. Jika konfigurasi `tempdb` tidak optimal, seluruh proses ETL akan terhambat.
- **Contoh:** Database `tempdb` hanya memiliki 1 file data dan berada di drive `C:\` bersama sistem operasi.
- **Solusi Terbaik:** Buat jumlah file data `tempdb` sesuai jumlah core CPU (maksimal 8 file awal dengan ukuran seimbang) dan tempatkan di media penyimpanan berkecepatan tinggi.

**Alokasikan RAM/CPU Memadai**

- **Penjelasan:** Spesifikasi hardware yang terbatas tidak mampu menampung pemrosesan paralel skala besar, sehingga memicu persaingan memori antara SQL Server dan SSIS.
- **Contoh:** Memproses ETL skala besar pada server dengan RAM 8 GB.
- **Solusi Terbaik:** Tingkatkan kapasitas hardware dan atur batas _Max Server Memory_ pada SQL Server agar menyisakan ruang RAM minimal 4 GB–8 GB khusus untuk sistem operasi dan mesin SSIS (`DTExec.exe`).

**Pengecualian Antivirus (Exclusions)**

- **Penjelasan:** Fitur pemindaian antimalware secara real-time yang memindai file data dan folder sementara SSIS saat aktivitas _read/write_ intensif dapat menurunkan kecepatan pemrosesan.
- **Contoh:** Windows Defender memindai buffer sementara SSIS setiap kali terjadi penulisan data.
- **Solusi Terbaik:** Tambahkan pengecualian proses (`DTExec.exe`, `sqlservr.exe`) serta pengecualian folder (folder data SQL Server & folder Temp SSIS) pada konfigurasi antivirus server.

**Gunakan Logging Level Ringan di Production**

- **Penjelasan:** Mengatur tingkat pencatatan log SSIS Catalog (`SSISDB`) ke mode `Verbose` atau `Diagnostic` di lingkungan produksi menghasilkan I/O penulisan log yang sangat tinggi.
- **Contoh:** SSIS mencatat informasi detail per buffer ke database `SSISDB`, yang menyebabkan database log membengkak dan eksekusi memanjang.
- **Solusi Terbaik:** Gunakan tingkat logging **Basic** atau **Performance** untuk operasional harian di lingkungan Production, dan gunakan mode `Verbose` hanya saat melakukan pelacakan masalah (_troubleshooting_).
