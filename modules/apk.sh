#!/bin/bash
# modules/apk.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

apk_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  📱 APK Analyzer${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Analisis APK — full scan"
    echo -e "  ${GREEN}[2]${NC} Lihat permissions APK"
    echo -e "  ${GREEN}[3]${NC} Cari hardcoded secret / API key"
    echo -e "  ${GREEN}[4]${NC} Lihat URLs tersembunyi di APK"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  APK = file ZIP. Analisis tanpa install, no root.${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) apk_full     ;;
      2) apk_perms    ;;
      3) apk_secrets  ;;
      4) apk_urls     ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

apk_get_file() {
  echo -ne "${WHITE}  Path file APK${NC}: "
  read -r APK_FILE
  if [[ -z "$APK_FILE" ]]; then
    err "Path kosong!"; return 1
  fi
  if [[ ! -f "$APK_FILE" ]]; then
    err "File tidak ditemukan: $APK_FILE"
    info "Tip: drag & drop file ke Termux atau gunakan path lengkap"
    info "Contoh: /sdcard/Download/app.apk"
    return 1
  fi
  if [[ "${APK_FILE##*.}" != "apk" ]]; then
    warn "Ekstensi bukan .apk, tetap lanjut?"
    echo -ne "${WHITE}  Lanjut? [y/N]${NC}: "
    read -r yn
    [[ ! "$yn" =~ ^[Yy]$ ]] && return 1
  fi
  return 0
}

apk_extract() {
  local apk="$1"
  local tmpdir=$(mktemp -d)
  # APK adalah ZIP, extract
  unzip -q "$apk" -d "$tmpdir" 2>/dev/null
  echo "$tmpdir"
}

apk_full() {
  banner
  echo -e "${CYAN}${BOLD}  📱 APK Full Analysis${NC}\n"
  apk_get_file || { pause; return; }

  section "Analyzing → $(basename "$APK_FILE")"

  info "Mengekstrak APK..."
  TMPDIR=$(apk_extract "$APK_FILE")

  echo ""
  python3 - "$APK_FILE" "$TMPDIR" << 'PYEOF'
import sys, os, re, zipfile, hashlib

apk_path = sys.argv[1]
tmp_path = sys.argv[2]

RED    = '\033[0;31m'
GREEN  = '\033[0;32m'
YELLOW = '\033[1;33m'
CYAN   = '\033[0;36m'
DIM    = '\033[2m'
BOLD   = '\033[1m'
NC     = '\033[0m'

# ── File info ─────────────────────────────────
size_mb = os.path.getsize(apk_path) / 1024 / 1024
md5     = hashlib.md5(open(apk_path,'rb').read()).hexdigest()
sha256  = hashlib.sha256(open(apk_path,'rb').read()).hexdigest()

print(f"  {CYAN}File     :{NC} {os.path.basename(apk_path)}")
print(f"  {CYAN}Size     :{NC} {size_mb:.2f} MB")
print(f"  {CYAN}MD5      :{NC} {md5}")
print(f"  {CYAN}SHA256   :{NC} {sha256[:32]}...")

# ── Files dalam APK ───────────────────────────
with zipfile.ZipFile(apk_path) as z:
    all_files  = z.namelist()
    dex_files  = [f for f in all_files if f.endswith('.dex')]
    so_files   = [f for f in all_files if f.endswith('.so')]
    asset_files= [f for f in all_files if f.startswith('assets/')]

print(f"\n  {CYAN}{BOLD}── Struktur APK ──{NC}")
print(f"  Total files  : {len(all_files)}")
print(f"  DEX files    : {len(dex_files)} {DIM}(kode Java/Kotlin){NC}")
print(f"  Native (.so) : {len(so_files)} {DIM}(kode C/C++){NC}")
print(f"  Assets       : {len(asset_files)}")
for so in so_files[:5]:
    arch = 'arm64' if 'arm64' in so else 'arm' if 'armeabi' in so else 'x86' if 'x86' in so else '?'
    print(f"    {DIM}• {os.path.basename(so)} [{arch}]{NC}")

# ── AndroidManifest ───────────────────────────
manifest_path = os.path.join(tmp_path, 'AndroidManifest.xml')
manifest_raw  = ''
if os.path.exists(manifest_path):
    try:
        with open(manifest_path,'rb') as f: manifest_raw = f.read().decode('utf-8','ignore')
    except: pass

print(f"\n  {CYAN}{BOLD}── Manifest Info ──{NC}")
pkg = re.search(r'package=["\']([^"\']+)["\']', manifest_raw)
ver = re.search(r'versionName=["\']([^"\']+)["\']', manifest_raw)
sdk = re.search(r'minSdkVersion=["\'](\d+)["\']', manifest_raw)
tgt = re.search(r'targetSdkVersion=["\'](\d+)["\']', manifest_raw)

SDK_MAP = {'16':'4.1','19':'4.4','21':'5.0','23':'6.0','26':'8.0',
           '28':'9.0','29':'10','30':'11','31':'12','32':'12L','33':'13','34':'14'}

print(f"  Package      : {pkg.group(1) if pkg else '?'}")
print(f"  Version      : {ver.group(1) if ver else '?'}")
if sdk:
    sdk_name = SDK_MAP.get(sdk.group(1), '')
    print(f"  Min SDK      : {sdk.group(1)} {DIM}(Android {sdk_name}){NC}")
if tgt:
    tgt_name = SDK_MAP.get(tgt.group(1), '')
    print(f"  Target SDK   : {tgt.group(1)} {DIM}(Android {tgt_name}){NC}")

# ── Permissions ───────────────────────────────
perms = re.findall(r'android\.permission\.(\w+)', manifest_raw)
perms = list(set(perms))

DANGEROUS = {
    'READ_CONTACTS':'Baca kontak',
    'WRITE_CONTACTS':'Tulis kontak',
    'READ_SMS':'Baca SMS',
    'SEND_SMS':'Kirim SMS',
    'RECEIVE_SMS':'Terima SMS',
    'READ_CALL_LOG':'Baca log panggilan',
    'RECORD_AUDIO':'Rekam audio/mikrofon',
    'CAMERA':'Akses kamera',
    'ACCESS_FINE_LOCATION':'Lokasi GPS presisi',
    'ACCESS_COARSE_LOCATION':'Lokasi kasar',
    'READ_EXTERNAL_STORAGE':'Baca storage',
    'WRITE_EXTERNAL_STORAGE':'Tulis storage',
    'GET_ACCOUNTS':'Daftar akun di HP',
    'USE_BIOMETRIC':'Akses biometrik',
    'READ_PHONE_STATE':'Info IMEI & telepon',
    'PROCESS_OUTGOING_CALLS':'Intersep panggilan keluar',
    'RECEIVE_BOOT_COMPLETED':'Autostart saat boot',
    'SYSTEM_ALERT_WINDOW':'Overlay di atas app lain',
    'REQUEST_INSTALL_PACKAGES':'Install APK lain',
    'BIND_ACCESSIBILITY_SERVICE':'Akses accessibility',
    'FOREGROUND_SERVICE':'Service background',
    'INTERNET':'Akses internet',
}

dangerous_found = [(p, DANGEROUS[p]) for p in perms if p in DANGEROUS]
normal_found    = [p for p in perms if p not in DANGEROUS]
risk_level      = len([p for p in dangerous_found if p[0] not in ['INTERNET','FOREGROUND_SERVICE']])

print(f"\n  {CYAN}{BOLD}── Permissions ({len(perms)} total) ──{NC}")
if dangerous_found:
    print(f"  {YELLOW}Berbahaya/Sensitif ({len(dangerous_found)}){NC}:")
    for perm, desc in sorted(dangerous_found):
        col = RED if perm in ['READ_SMS','RECORD_AUDIO','BIND_ACCESSIBILITY_SERVICE',
                               'PROCESS_OUTGOING_CALLS','REQUEST_INSTALL_PACKAGES'] else YELLOW
        print(f"    {col}[!]{NC} {perm} {DIM}({desc}){NC}")

# ── Secrets scan (dari strings di DEX) ────────
print(f"\n  {CYAN}{BOLD}── Hardcoded Secrets ──{NC}")
secrets_found = []
secret_patterns = [
    (r'AIza[0-9A-Za-z\-_]{35}',         'Google API Key'),
    (r'AAAA[A-Za-z0-9_-]{7}:[A-Za-z0-9_-]{140}', 'Firebase FCM Key'),
    (r'ya29\.[0-9A-Za-z\-_]+',           'Google OAuth Token'),
    (r'sk-[a-zA-Z0-9]{48}',              'OpenAI API Key'),
    (r'sk-ant-[a-zA-Z0-9\-_]{80,}',      'Anthropic Key'),
    (r'[0-9]+-[0-9A-Za-z_]{32}\.apps\.googleusercontent\.com', 'Google Client ID'),
    (r'(?i)api[_-]?key["\s:=]+["\']([A-Za-z0-9_\-]{20,})["\']', 'Generic API Key'),
    (r'(?i)secret["\s:=]+["\']([A-Za-z0-9_\-]{16,})["\']',      'Secret Key'),
    (r'(?i)password["\s:=]+["\']([^"\']{8,})["\']',              'Hardcoded Password'),
    (r'(?i)aws_secret["\s:=]+["\']([A-Za-z0-9/+=]{40})["\']',   'AWS Secret Key'),
    (r'(?i)jdbc:[a-z]+://[^\s"\']+',     'Database URL'),
    (r'mongodb(\+srv)?://[^\s"\']+',     'MongoDB URL'),
]

# scan semua file text dalam APK
for root, dirs, files in os.walk(tmp_path):
    for fname in files:
        if fname.endswith(('.xml','.json','.js','.html','.properties','.gradle','.txt')):
            fpath = os.path.join(root, fname)
            try:
                content = open(fpath,'r',errors='ignore').read()
                for pattern, label in secret_patterns:
                    matches = re.findall(pattern, content)
                    for m in matches:
                        val = m if isinstance(m, str) else m[0]
                        if len(val) > 8:
                            rel = fpath.replace(tmp_path,'')
                            secrets_found.append((label, val[:30]+'...', rel))
            except: pass

if secrets_found:
    for label, val, path in secrets_found[:10]:
        print(f"  {RED}[!]{NC} {label}: {DIM}{val}{NC}")
        print(f"       {DIM}→ {path}{NC}")
else:
    print(f"  {GREEN}[+]{NC} Tidak ada hardcoded secret ditemukan")

# ── Risk Summary ──────────────────────────────
print(f"\n  {CYAN}{BOLD}── Risk Summary ──{NC}")
total_risk = risk_level + len(secrets_found)
if total_risk == 0:
    print(f"  {GREEN}Risiko rendah — tidak ada temuan signifikan{NC}")
elif total_risk <= 3:
    print(f"  {YELLOW}Risiko sedang — {total_risk} temuan perlu diperhatikan{NC}")
else:
    print(f"  {RED}Risiko tinggi — {total_risk} temuan berbahaya!{NC}")
PYEOF

  rm -rf "$TMPDIR" 2>/dev/null
  pause
}

apk_perms() {
  banner
  echo -e "${CYAN}${BOLD}  📱 APK Permissions${NC}\n"
  apk_get_file || { pause; return; }
  TMPDIR=$(apk_extract "$APK_FILE")
  section "Permissions → $(basename "$APK_FILE")"
  python3 - "$TMPDIR" << 'PYEOF'
import sys, os, re
tmp = sys.argv[1]
manifest = os.path.join(tmp, 'AndroidManifest.xml')
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; DIM='\033[2m'; NC='\033[0m'
DANGEROUS = {'READ_CONTACTS','WRITE_CONTACTS','READ_SMS','SEND_SMS','RECEIVE_SMS',
             'READ_CALL_LOG','RECORD_AUDIO','CAMERA','ACCESS_FINE_LOCATION',
             'ACCESS_COARSE_LOCATION','READ_EXTERNAL_STORAGE','WRITE_EXTERNAL_STORAGE',
             'GET_ACCOUNTS','READ_PHONE_STATE','PROCESS_OUTGOING_CALLS',
             'RECEIVE_BOOT_COMPLETED','SYSTEM_ALERT_WINDOW','REQUEST_INSTALL_PACKAGES',
             'BIND_ACCESSIBILITY_SERVICE','USE_BIOMETRIC'}
try:
    content = open(manifest,'rb').read().decode('utf-8','ignore')
    perms   = sorted(set(re.findall(r'android\.permission\.(\w+)', content)))
    print(f"  Total: {len(perms)} permission\n")
    for p in perms:
        if p in DANGEROUS:
            print(f"  {RED}[DANGER]{NC} {p}")
        elif p == 'INTERNET':
            print(f"  {YELLOW}[NORMAL]{NC} {p}")
        else:
            print(f"  {GREEN}[NORMAL]{NC} {p}")
except Exception as e:
    print(f"  Error: {e}")
PYEOF
  rm -rf "$TMPDIR"
  pause
}

apk_secrets() {
  banner
  echo -e "${CYAN}${BOLD}  📱 Hardcoded Secrets${NC}\n"
  apk_get_file || { pause; return; }
  TMPDIR=$(apk_extract "$APK_FILE")
  section "Secret Scan → $(basename "$APK_FILE")"
  python3 - "$TMPDIR" << 'PYEOF'
import sys, os, re
tmp = sys.argv[1]
RED='\033[0;31m'; DIM='\033[2m'; GREEN='\033[0;32m'; NC='\033[0m'
patterns = [
    (r'AIza[0-9A-Za-z\-_]{35}','Google API Key'),
    (r'sk-[a-zA-Z0-9]{48}','OpenAI Key'),
    (r'sk-ant-[a-zA-Z0-9\-_]{80,}','Anthropic Key'),
    (r'(?i)api[_-]?key["\s:=]+["\']([A-Za-z0-9_\-]{20,})["\']','Generic API Key'),
    (r'(?i)secret["\s:=]+["\']([A-Za-z0-9_\-]{16,})["\']','Secret'),
    (r'(?i)password["\s:=]+["\']([^"\']{8,})["\']','Password'),
    (r'jdbc:[a-z]+://[^\s"\']+','Database URL'),
    (r'mongodb(\+srv)?://[^\s"\']+','MongoDB URL'),
    (r'(?i)private[_-]?key["\s:=]+["\']([^"\']{20,})["\']','Private Key'),
]
found = []
for root, dirs, files in os.walk(tmp):
    for f in files:
        if f.endswith(('.xml','.json','.js','.html','.properties','.txt','.gradle')):
            try:
                c = open(os.path.join(root,f),'r',errors='ignore').read()
                for pat, label in patterns:
                    for m in re.findall(pat, c):
                        v = m if isinstance(m,str) else m[0]
                        if len(v) > 8:
                            found.append((label, v[:35]+'...', f))
            except: pass
if found:
    for label, val, fname in found[:20]:
        print(f"  {RED}[!]{NC} {label}")
        print(f"      Value : {DIM}{val}{NC}")
        print(f"      File  : {DIM}{fname}{NC}\n")
else:
    print(f"  {GREEN}[+]{NC} Tidak ada hardcoded secret ditemukan")
PYEOF
  rm -rf "$TMPDIR"
  pause
}

apk_urls() {
  banner
  echo -e "${CYAN}${BOLD}  📱 URLs di APK${NC}\n"
  apk_get_file || { pause; return; }
  TMPDIR=$(apk_extract "$APK_FILE")
  section "URL Scan → $(basename "$APK_FILE")"
  python3 - "$TMPDIR" << 'PYEOF'
import sys, os, re
tmp = sys.argv[1]
CYAN='\033[0;36m'; RED='\033[0;31m'; DIM='\033[2m'; YELLOW='\033[1;33m'; NC='\033[0m'
urls = set()
for root, dirs, files in os.walk(tmp):
    for f in files:
        if f.endswith(('.xml','.json','.js','.html','.properties','.txt')):
            try:
                c = open(os.path.join(root,f),'r',errors='ignore').read()
                for u in re.findall(r'https?://[^\s"\'<>{}|\\^`\[\]]{10,}', c):
                    urls.add(u.rstrip('.,;)'))
            except: pass
sus = [u for u in urls if any(x in u.lower() for x in ['api','key','secret','token','auth','admin'])]
normal = [u for u in urls if u not in sus]
if sus:
    print(f"  {RED}URL Sensitif ({len(sus)}):{NC}")
    for u in sorted(sus)[:15]:
        print(f"  {RED}[!]{NC} {u[:80]}")
print(f"\n  {CYAN}Semua URL ({len(urls)}):{NC}")
for u in sorted(normal)[:30]:
    print(f"  {DIM}{u[:80]}{NC}")
if len(urls) > 30:
    print(f"\n  ...dan {len(urls)-30} URL lainnya")
PYEOF
  rm -rf "$TMPDIR"
  pause
}
