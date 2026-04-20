# 🔐 CyberTool — Termux Cybersecurity Toolkit

> ⚠️ Gunakan hanya pada sistem milik sendiri atau yang sudah dapat izin resmi.

---

## 📁 Struktur File

```
cybertool/
├── cybertool.sh          ← JALANKAN INI
├── install.sh            ← Install semua tools (sekali aja)
├── lib/
│   └── colors.sh         ← Helper & warna (jangan diedit)
└── modules/
    ├── network.sh        ← Nmap, Whois, DNS, Traceroute, Netcat
    ├── webapp.sh         ← Nikto, SQLMap, Gobuster, Curl
    ├── password.sh       ← John, Hydra, Hash tools, Wordlist gen
    ├── wifi.sh           ← WiFi scan *
    ├── ctf.sh            ← Binwalk, Stego, XOR, ROT, Hex, dll
    ├── bluetooth.sh      ← BT & BLE scanner *
    ├── osint.sh          ← Username, IP, Email, Subdomain, Dork, Phone
    └── remote.sh         ← SSH remote, file transfer, tunnel
```
> *) Butuh app Termux:API dari F-Droid. Kalau ga install pun toolkit tetap jalan normal.

---

## 🚀 Cara Setup (Sekali Aja)

### Step 1 — Siapkan Termux
Download **Termux** dari Play Store atau F-Droid.

### Step 2 — Clone repo ini
Buka Termux, ketik:
```bash
git clone https://github.com/USERNAME/cybertool.git
cd cybertool
```
> Ganti `USERNAME` dengan username GitHub lo.

### Step 3 — Install semua tools
```bash
bash install.sh
```
Proses ini butuh koneksi internet dan sekitar 5–10 menit.

### Step 4 — Jalankan!
```bash
bash cybertool.sh
```

---

## 🔁 Cara Pakai Setiap Hari

Setiap mau pake toolkit, cukup:
```bash
cd cybertool
bash cybertool.sh
```

---

## 📋 Daftar Fitur Lengkap

### 🌐 [1] Network Scanning & Recon
| # | Tool | Fungsi |
|---|---|---|
| 1 | Nmap | Quick scan top 1000 port |
| 2 | Nmap | Service & version detection |
| 3 | Nmap | Full scan semua 65535 port |
| 4 | Nmap | Vulnerability script scan |
| 5 | Whois | Info pemilik domain/IP |
| 6 | Dig | DNS records (A/MX/NS/TXT/CNAME) |
| 7 | Traceroute | Jalur jaringan ke target |
| 8 | Nmap | Ping sweep / host discovery di subnet |
| 9 | Netcat | Manual port check |

### 🕸️ [2] Web App Testing
| # | Tool | Fungsi |
|---|---|---|
| 1 | Nikto | Web vulnerability scanner |
| 2 | SQLMap | SQL injection basic |
| 3 | SQLMap | SQL injection aggressive + dump DB |
| 4 | Gobuster | Directory bruteforce |
| 5 | Gobuster | Subdomain enumeration |
| 6 | Curl | HTTP header inspector |
| 7 | Curl | Manual GET/POST request |
| 8 | Custom | Tech fingerprint (CMS, framework, library) |

### 🔑 [3] Password & Hash Tools
| # | Tool | Fungsi |
|---|---|---|
| 1 | Built-in | Generate hash MD5/SHA1/SHA256/SHA512 |
| 2 | Built-in | Identify tipe hash dari panjang & prefix |
| 3 | John | Crack hash dari file pakai wordlist |
| 4 | Hydra | Brute force login SSH |
| 5 | Hydra | Brute force login FTP |
| 6 | Hydra | Brute force HTTP login form |
| 7 | Built-in | Generate password random |
| 8 | Built-in | Buat wordlist custom dari info target |

### 📡 [4] WiFi Scanner *(butuh Termux:API)*
| # | Fungsi |
|---|---|
| 1 | Scan semua WiFi sekitar — SSID, signal, security, channel |
| 2 | Info detail koneksi WiFi aktif — IP, MAC, BSSID, frekuensi |

### 🚩 [5] CTF Tools
| # | Tool | Fungsi |
|---|---|---|
| 1 | Strings | Extract teks dari file binary |
| 2 | Binwalk | Analisis & extract file |
| 3 | Exiftool | Baca metadata file |
| 4 | Steghide | Embed / extract data di gambar |
| 5 | Python | ROT/Caesar brute force semua shift |
| 6 | Built-in | Base64 encode/decode |
| 7 | Built-in | Hex encode/decode |
| 8 | Built-in | URL encode/decode |
| 9 | Python | XOR brute force (single byte key) |
| 10 | Python | Binary string → teks |
| 11 | Built-in | Hash file MD5/SHA1/SHA256 |
| 12 | Built-in | File magic / type detector |

### 🔵 [6] Bluetooth Scanner *(butuh Termux:API)*
| # | Fungsi |
|---|---|
| 1 | Scan semua BT device sekitar — nama, MAC, RSSI, tipe |
| 2 | Scan BLE devices — smartwatch, earphone, sensor IoT |
| 3 | Info adapter Bluetooth HP sendiri |

### 🕵️ [7] OSINT Tools
| # | Fungsi |
|---|---|
| 1 | Username search di 22 platform sekaligus |
| 2 | IP geolocation — negara, kota, ISP, koordinat, Google Maps |
| 3 | Email breach check + validasi domain + Gravatar lookup |
| 4 | Subdomain finder — gabungin crt.sh, HackerTarget, DNS brute |
| 5 | Google dork generator — 20+ query siap pakai |
| 6 | Phone number lookup — negara, operator Indonesia |

### 🖥️ [8] Remote Access
| # | Fungsi |
|---|---|
| 1 | SSH masuk ke laptop dari HP |
| 2 | Kirim file dari HP ke laptop |
| 3 | Ambil file dari laptop ke HP |
| 4 | Jalankan SSH server di HP — biar laptop bisa remote masuk |
| 5 | Lihat info SSH server HP (IP, port, command konek) |
| 6 | Stop SSH server |
| 7 | Reverse tunnel — akses HP dari laptop beda jaringan |
| 8 | Reverse tunnel — akses laptop dari HP beda jaringan |

---

## 🖥️ Cara Pakai Remote Access

### Skenario 1: HP remote masuk ke Laptop (WiFi sama)
```
1. Buka menu [8] → [1]
2. Masukkan IP laptop, username, port (default 22)
3. Done — lo masuk ke terminal laptop dari HP
```
Cari IP laptop: di laptop jalankan `ip a` (Linux) atau `ipconfig` (Windows).

### Skenario 2: Laptop remote masuk ke HP (WiFi sama)
```
1. Di HP: menu [8] → [4] untuk start SSH server
2. Di HP: menu [8] → [5] untuk lihat IP & port
3. Di laptop: jalankan command yang muncul
   contoh: ssh u0_a123@192.168.1.5 -p 8022
```

### Skenario 3: Remote beda jaringan / internet
Butuh 1 VPS atau server publik sebagai relay.
```
1. HP konek ke relay: menu [8] → [7]
2. Dari laptop: ssh user@IP_relay -p 2222
3. Otomatis masuk ke HP via tunnel
```

---

## ❓ FAQ

**Q: Harus root?**
A: Tidak. Semua fitur no root.

**Q: WiFi/BT scan tidak jalan?**
A: Install app Termux:API dari F-Droid, lalu allow izin Lokasi.

**Q: SSH server di HP port berapa?**
A: Termux default pakai port **8022** (bukan 22).

**Q: Mau tambah fitur sendiri?**
A: Buka file `modules/` yang relevan, ikutin struktur `case` yang sudah ada.

### 📊 [9] Network Monitor
| # | Fungsi |
|---|---|
| 1 | Scan semua device di jaringan — IP, MAC, vendor |
| 2 | Watch mode — alert realtime kalau ada device baru masuk |
| 3 | ARP table — device yang pernah konek |
| 4 | Koneksi aktif di HP lo — remote IP, port, service |
| 5 | Ping monitor — pantau device tetap online/offline |

### 🧠 [10] AI Security Assistant
| # | Fungsi |
|---|---|
| 1 | Chat bebas soal cybersecurity dengan Claude AI |
| 2 | Analisis log / output tools — temukan hal mencurigakan |
| 3 | Explain CVE / exploit — penjelasan teknikal |
| 4 | Review kode — scan vulnerability di kode lo |
| 5 | Setup API key Anthropic |

> AI Assistant butuh API key dari https://console.anthropic.com (ada free tier)

---

## 📁 Struktur File Final

```
cybertool/
├── cybertool.sh
├── install.sh
├── lib/
│   └── colors.sh
└── modules/
    ├── network.sh
    ├── webapp.sh
    ├── password.sh
    ├── wifi.sh
    ├── ctf.sh
    ├── bluetooth.sh
    ├── osint.sh
    ├── remote.sh
    ├── netmonitor.sh
    └── ai.sh
```
