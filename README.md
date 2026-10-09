# WMS Windows Listener

Aplikasi pendamping Windows untuk menerima hasil scan dari WMS mobile melalui LAN, mencari file lokal, dan menampilkannya di dalam aplikasi.

## Membangun aplikasi dan installer

1. Siapkan Flutter untuk Windows, Visual Studio dengan workload **Desktop development with C++**, dan aktifkan Windows Developer Mode untuk membangun penampil PDF.
2. Unduh [NSIS](https://nsis.sourceforge.io/Download). Pasang agar `makensis.exe` tersedia di PATH, atau ekstrak NSIS 3.12 ke `.tools\nsis-3.12`.
3. Jalankan `powershell -ExecutionPolicy Bypass -File .\build_installer.ps1` dari folder proyek. Script membangun Flutter, menyertakan Visual C++ runtime, dan menghasilkan `dist\WMSWindowsListenerSetup.exe`.

Setelah menambah atau memperbarui plugin PDF, hentikan sesi F5 yang sedang berjalan lalu jalankan lagi. Hot reload tidak menyalin `pdfium.dll` ke folder Debug.

Installer menyalin seluruh hasil build Flutter, membuat shortcut Start Menu dan startup untuk user yang memasangnya. Aplikasi harus tetap berjalan (boleh diminimalkan) agar scan diterima.

## Menyiapkan PC

1. Jalankan installer, lalu buka **WMS Windows Listener**.
2. Buka **Pengaturan**, tambahkan satu atau beberapa folder dokumen, lalu klik **Simpan dan aktifkan**.
3. Buka **Dashboard** untuk melihat IP PC dan QR koneksi cepat. Aktifkan listener pertama kali lewat **Pengaturan** dengan memilih folder lalu menekan **Simpan dan aktifkan**. Setelah berhasil aktif sekali, switch layanan ON/OFF tersedia di Dashboard dan tetap ada setelah aplikasi dijalankan ulang. QR juga tersedia di **Pengaturan** setelah listener aktif; pilih IP yang satu jaringan dengan mobile. QR memuat kunci akses, jadi tampilkan hanya kepada pengguna yang diizinkan. Port (default `8765`) dan kunci akses ada di **Pengaturan**. Kunci baru terdiri dari 8 karakter yang mudah dibaca; untuk instalasi lama, klik **Buat kunci 8 karakter** lalu **Simpan dan aktifkan ulang**. Kunci lama tetap didukung sampai diganti.
4. Pastikan PC dan mobile tersambung ke Wi-Fi yang sama. Izinkan koneksi masuk TCP port `8765` dari jaringan privat pada Windows Firewall. Atur DHCP reservation agar alamat IP PC tidak berubah.
5. Buka **File Scan** dan masukkan nama file. Contoh: file `ABC123.pdf` ditemukan oleh kode `ABC123` atau `ABC123.pdf`.

## API untuk aplikasi mobile

`POST http://<IP-PC>:8765/scan`

Header: `X-Listener-Key: <kunci dari aplikasi PC>` dan `Content-Type: application/json`.

Body:

```json
{"code":"ABC123"}
```

Respons JSON berisi `ok`, `message`, dan `path` bila berhasil. Status HTTP: `200` berhasil, `400` kode tidak valid, `401` kunci salah, `404` file tidak ditemukan, `409` pencarian ganda atau scan sedang diproses, `503` folder tidak tersedia.

Endpoint `GET /health` dapat dipakai untuk pemeriksaan koneksi. Kunci akses disimpan di `%APPDATA%\WmsWindowsListener\config.json`. Jangan menaruh kunci dalam kode aplikasi mobile; simpan sebagai pengaturan per PC. Port listener hanya perlu dibuka pada jaringan lokal, bukan internet publik.

## Aturan pencarian awal

QR harus berisi nama file atau nama file tanpa ekstensi, bukan path. Pencarian meliputi semua folder yang dipilih dan subfoldernya, serta tidak peka huruf besar/kecil. Daftar folder, port, kunci akses, status aktif/mati, dan pilihan tampilan dimuat kembali setelah aplikasi dijalankan ulang.

Switch pilihan scan ada hanya di halaman **File Scan**. **Trim nilai scan** default ON dan menghapus spasi atau karakter QR tak terlihat pada awal dan akhir kode; OFF memakai nilai persis dari scanner. Spasi di tengah nama file tetap dipertahankan. **Buka di aplikasi** ON menampilkan file dalam listener; OFF membuka file melalui aplikasi Windows bawaan. **Full screen** hanya terlihat saat **Buka di aplikasi** ON. Full screen ON membuka popup pratinjau yang dimaksimalkan; OFF menampilkan file di jendela utama listener pada halaman File Scan. Pilihan tersimpan dan berlaku pada scan berikutnya tanpa mengaktifkan ulang listener. Popup punya tombol Windows untuk meminimalkan atau menutupnya; pratinjau di jendela utama punya tombol kembali. Scan berikutnya mengganti pratinjau lama.

Saat aktif, tombol menjadi **Simpan dan aktifkan ulang**; tombol **Matikan** menghentikan listener dan menyimpan status mati agar tidak aktif otomatis saat aplikasi dibuka kembali. Konfigurasi lama dengan satu folder tetap dapat dibaca. Ekstensi yang diterima: PDF, PNG, JPG/JPEG, TXT, DOCX, XLSX. Jika ada lebih dari satu file cocok, aplikasi menutup pratinjau lama, membuka halaman **File Scan**, menampilkan daftar file, dan menunggu pilihan pengguna dalam kedua mode. Satu file cocok langsung ditampilkan atau dibuka sesuai pilihan switch. PDF, gambar, dan TXT tampil di dalam listener; DOCX/XLSX menampilkan tombol untuk membuka aplikasi Office karena belum ada renderer Office terintegrasi. Riwayat 50 scan terakhir tersimpan di PC. Jenis file dan pola penamaan bisa disesuaikan setelah contoh dari klien tersedia.

## Struktur kode

- `lib/core/constants/`: port dan ekstensi file yang diizinkan.
- `lib/core/models/modules/listener/`: pengaturan, hasil scan, dan alamat jaringan.
- `lib/core/services/`: penyimpanan lokal, alamat IP, HTTP listener, dan pembuka file.
- `lib/core/repository/modules/listener_repository.dart`: pencarian file dan koordinasi service.
- `lib/core/cubit/modules/listener/`: state serta aksi halaman listener.
- `lib/presentation/components/` dan `lib/presentation/pages/listener/`: widget dan halaman Windows.

Folder `core/network/` belum diperlukan karena aplikasi PC menerima request LAN dan belum memanggil API luar. HTTP listener berada di `core/services/lan_listener_service.dart`.


## Navigasi dan tampilan

- **Dashboard**: status listener, switch layanan ON/OFF setelah aktivasi pertama, QR koneksi cepat, alamat IP PC, dan hasil scan terakhir.
- **File Scan**: hasil scan terbaru, daftar file yang cocok, dan riwayat 50 scan terakhir.
- Klik hasil sukses di **Riwayat** untuk membuka file yang sama lagi sesuai posisi switch **Buka di aplikasi**. File yang sudah dipindah atau dihapus akan menampilkan pesan bahwa file tidak tersedia.
- **Pengaturan**: folder dokumen, port LAN, dan kunci akses.

Tema Windows mengikuti warna Yazaki WMS dan font Poppins dari aplikasi mobile. Pada jendela lebar navigasi ada di sidebar; pada jendela sempit navigasi berpindah ke bawah.
