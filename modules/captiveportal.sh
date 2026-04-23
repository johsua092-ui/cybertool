#!/bin/bash
# modules/captiveportal.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

captiveportal_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🔓 Captive Portal Detector${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Detect captive portal"
    echo -e "  ${GREEN}[2]${NC} Coba bypass captive portal"
    echo -e "  ${GREEN}[3]${NC} DNS bypass (pakai DNS publik)"
    echo -e "  ${GREEN}[4]${NC} Analisis portal login"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Captive portal = halaman login WiFi hotel/sekolah/cafe${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) cp_detect   ;;
      2) cp_bypass   ;;
      3) cp_dns      ;;
      4) cp_analyze  ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

cp_detect() {
  section "Detect Captive Portal"
  info "Mengecek apakah jaringan ini punya captive portal...\n"

  python3 - << 'PYEOF'
import urllib.request, ssl, re, sys

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'

ctx = ssl.create_default_context()
ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

# Test URLs yang biasa dipakai untuk deteksi captive portal
TEST_URLS = [
    ('http://connectivitycheck.gstatic.com/generate_204', 204, 'Google'),
    ('http://clients3.google.com/generate_204', 204, 'Google Alt'),
    ('http://detectportal.firefox.com/success.txt', 200, 'Firefox'),
    ('http://www.msftncsi.com/ncsi.txt', 200, 'Microsoft'),
    ('http://captive.apple.com/hotspot-detect.html', 200, 'Apple'),
    ('http://nmcheck.gnome.org/check_network_status.txt', 200, 'GNOME'),
]

portal_url = None
is_portal  = False

for url, expected_code, source in TEST_URLS:
    try:
        req  = urllib.request.Request(url, headers={'User-Agent':'Mozilla/5.0'})
        resp = urllib.request.urlopen(req, timeout=5, context=ctx)
        code = resp.getcode()
        body = resp.read(500).decode('utf-8','ignore')
        final_url = resp.geturl()

        if code != expected_code or final_url != url:
            is_portal  = True
            portal_url = final_url
            print(f'  {YELLOW}[!]{NC} {source}: redirect terdeteksi!')
            print(f'       Expected {expected_code}, got {code}')
            print(f'       Redirect ke: {DIM}{final_url[:80]}{NC}')
        else:
            print(f'  {GREEN}[✓]{NC} {source}: OK ({code})')
    except urllib.error.HTTPError as e:
        if e.code in [301, 302, 307, 308]:
            is_portal  = True
            portal_url = e.headers.get('Location','?')
            print(f'  {RED}[!]{NC} {source}: redirect {e.code} → {DIM}{portal_url[:60]}{NC}')
        else:
            print(f'  {DIM}[-]{NC} {source}: error {e.code}')
    except Exception as e:
        print(f'  {DIM}[-]{NC} {source}: {str(e)[:40]}')

print()
if is_portal:
    print(f'  {RED}╔══════════════════════════════════════╗{NC}')
    print(f'  {RED}║  CAPTIVE PORTAL TERDETEKSI!          ║{NC}')
    print(f'  {RED}╚══════════════════════════════════════╝{NC}')
    print(f'\n  Portal URL: {CYAN}{portal_url}{NC}')
    print(f'\n  {YELLOW}Coba bypass di menu [2] atau [3]{NC}')
else:
    print(f'  {GREEN}╔══════════════════════════════════════╗{NC}')
    print(f'  {GREEN}║  Tidak ada captive portal — internet OK! ║{NC}')
    print(f'  {GREEN}╚══════════════════════════════════════╝{NC}')
PYEOF
  pause
}

cp_bypass() {
  section "Bypass Captive Portal"
  info "Mencoba berbagai metode bypass...\n"

  python3 - << 'PYEOF'
import urllib.request, subprocess, ssl, sys, time

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'

ctx = ssl.create_default_context()
ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

def test_internet():
    try:
        urllib.request.urlopen('http://clients3.google.com/generate_204',
                               timeout=5, context=ctx)
        return True
    except: return False

methods = [
    ('DNS 8.8.8.8 (Google)',   ['8.8.8.8',   '8.8.4.4']),
    ('DNS 1.1.1.1 (Cloudflare)',['1.1.1.1',  '1.0.0.1']),
    ('DNS 208.67.222.222 (OpenDNS)',['208.67.222.222','208.67.220.220']),
    ('DNS 9.9.9.9 (Quad9)',    ['9.9.9.9',   '149.112.112.112']),
]

print(f'  {CYAN}[1/4]{NC} Coba bypass via DNS change...\n')
for method, dns in methods:
    print(f'  Testing {method}...', end='', flush=True)
    # set DNS sementara via resolv.conf
    try:
        with open('/etc/resolv.conf', 'w') as f:
            for d in dns: f.write(f'nameserver {d}\n')
        time.sleep(1)
        if test_internet():
            print(f' {GREEN}BYPASS BERHASIL!{NC}')
            print(f'\n  {GREEN}[+] Internet terbuka via {method}{NC}')
            print(f'  DNS aktif: {dns[0]}, {dns[1]}')
            sys.exit(0)
        else:
            print(f' {RED}gagal{NC}')
    except Exception as e:
        print(f' {DIM}skip ({e}){NC}')

print(f'\n  {CYAN}[2/4]{NC} Coba User-Agent bypass...')
agents = [
    'Mozilla/5.0 (compatible; Googlebot/2.1)',
    'CaptiveNetworkSupport/1.0 wispr',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0)',
]
for agent in agents:
    try:
        req = urllib.request.Request(
            'http://clients3.google.com/generate_204',
            headers={'User-Agent': agent})
        resp = urllib.request.urlopen(req, timeout=5, context=ctx)
        if resp.getcode() == 204:
            print(f'  {GREEN}[+] Bypass via User-Agent: {agent[:40]}{NC}')
            break
    except: pass

print(f'\n  {CYAN}[3/4]{NC} Coba HTTP tunnel...')
# Coba akses via port 80 langsung
for host in ['8.8.8.8', '1.1.1.1', '208.67.222.222']:
    try:
        import socket
        s = socket.create_connection((host, 80), timeout=3)
        s.close()
        print(f'  {GREEN}[+] Port 80 terbuka ke {host}{NC}')
        break
    except:
        print(f'  {DIM}[-] {host}:80 blocked{NC}')

print(f'\n  {CYAN}[4/4]{NC} Coba HTTPS (443)...')
for host in ['8.8.8.8', '1.1.1.1']:
    try:
        import socket
        s = socket.create_connection((host, 443), timeout=3)
        s.close()
        print(f'  {GREEN}[+] Port 443 terbuka ke {host} — bisa pakai VPN/HTTPS tunnel{NC}')
        break
    except:
        print(f'  {DIM}[-] {host}:443 blocked{NC}')

print(f'\n  {YELLOW}Tip: Kalau semua gagal, coba:{NC}')
print(f'  {DIM}• Pakai Tor (menu [20]) — bypass lewat onion network{NC}')
print(f'  {DIM}• Minta kredensial login dari admin jaringan{NC}')
PYEOF
  pause
}

cp_dns() {
  section "DNS Bypass"
  info "Ganti DNS ke server publik untuk bypass portal\n"

  echo -e "  ${GREEN}[1]${NC} Google DNS (8.8.8.8)"
  echo -e "  ${GREEN}[2]${NC} Cloudflare DNS (1.1.1.1)"
  echo -e "  ${GREEN}[3]${NC} OpenDNS (208.67.222.222)"
  echo -e "  ${GREEN}[4]${NC} Quad9 (9.9.9.9)"
  echo -e "  ${GREEN}[5]${NC} Custom DNS"
  echo -e "  ${GREEN}[6]${NC} Reset ke default"
  echo ""
  echo -ne "${WHITE}  Pilih${NC}: "
  read -r opt

  case $opt in
    1) DNS1="8.8.8.8";         DNS2="8.8.4.4"         ; NAME="Google" ;;
    2) DNS1="1.1.1.1";         DNS2="1.0.0.1"          ; NAME="Cloudflare" ;;
    3) DNS1="208.67.222.222";  DNS2="208.67.220.220"   ; NAME="OpenDNS" ;;
    4) DNS1="9.9.9.9";         DNS2="149.112.112.112"  ; NAME="Quad9" ;;
    5) echo -ne "${WHITE}  DNS 1${NC}: "; read -r DNS1
       echo -ne "${WHITE}  DNS 2${NC}: "; read -r DNS2
       NAME="Custom" ;;
    6) info "Reset DNS ke default..."
       echo "nameserver 192.168.1.1" > /etc/resolv.conf 2>/dev/null || \
       echo "nameserver 8.8.8.8" > /etc/resolv.conf 2>/dev/null
       ok "DNS direset"; pause; return ;;
    *) err "Tidak valid!"; pause; return ;;
  esac

  # Apply DNS
  {
    echo "nameserver $DNS1"
    echo "nameserver $DNS2"
  } > /etc/resolv.conf 2>/dev/null

  if [[ $? -eq 0 ]]; then
    ok "DNS diubah ke $NAME ($DNS1, $DNS2)"
    info "Testing koneksi..."
    if nslookup google.com "$DNS1" &>/dev/null; then
      ok "DNS works! Coba akses internet sekarang"
    else
      warn "DNS terset tapi mungkin masih diblokir portal"
    fi
  else
    warn "Perlu root untuk edit /etc/resolv.conf"
    info "Alternatif: set DNS di pengaturan WiFi HP lo secara manual"
    info "Buka: Settings → WiFi → [nama jaringan] → IP Settings → Static → DNS"
    info "DNS 1: ${CYAN}$DNS1${NC}"
    info "DNS 2: ${CYAN}$DNS2${NC}"
  fi
  pause
}

cp_analyze() {
  section "Analisis Portal Login"
  echo -ne "${WHITE}  URL portal${NC} (kosong = auto-detect): "
  read -r portal_url

  if [[ -z "$portal_url" ]]; then
    spinner_start "Detecting portal"
    portal_url=$(python3 -c "
import urllib.request, ssl
ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=0
try:
    resp=urllib.request.urlopen('http://connectivitycheck.gstatic.com/generate_204',
                                timeout=5,context=ctx)
    print(resp.geturl())
except urllib.error.HTTPError as e:
    loc=e.headers.get('Location','')
    print(loc if loc else '')
except: print('')
" 2>/dev/null)
    spinner_stop "Done"
  fi

  [[ -z "$portal_url" ]] && { warn "Portal tidak terdeteksi / sudah terbuka"; pause; return; }

  info "Menganalisis: $portal_url\n"

  python3 - "$portal_url" << 'PYEOF'
import sys, urllib.request, ssl, re

url = sys.argv[1]
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'

ctx = ssl.create_default_context()
ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

try:
    req  = urllib.request.Request(url, headers={'User-Agent':'Mozilla/5.0'})
    resp = urllib.request.urlopen(req, timeout=8, context=ctx)
    body = resp.read(5000).decode('utf-8','ignore')
    headers = dict(resp.headers)
except Exception as e:
    print(f'  Error: {e}'); sys.exit()

# Analisis form
forms   = re.findall(r'<form[^>]*>(.*?)</form>', body, re.DOTALL|re.I)
inputs  = re.findall(r'<input[^>]*>', body, re.I)
actions = re.findall(r'action=["\']([^"\']+)["\']', body, re.I)

print(f'  {CYAN}Server     :{NC} {headers.get("Server","?")}')
print(f'  {CYAN}Forms      :{NC} {len(forms)}')
print(f'  {CYAN}Inputs     :{NC} {len(inputs)}')
if actions:
    print(f'  {CYAN}Form action:{NC} {actions[0]}')

print(f'\n  {CYAN}Input fields:{NC}')
for inp in inputs[:10]:
    name  = re.search(r'name=["\']([^"\']+)["\']', inp)
    itype = re.search(r'type=["\']([^"\']+)["\']', inp, re.I)
    n = name.group(1)  if name  else '?'
    t = itype.group(1) if itype else 'text'
    col = RED if t.lower()=='password' else YELLOW if t.lower() in ['email','tel'] else DIM
    print(f'  {col}  [{t}] {n}{NC}')

# Detect portal type
body_lower = body.lower()
if 'voucher' in body_lower or 'kode' in body_lower:
    print(f'\n  {YELLOW}[!] Portal tipe VOUCHER — butuh kode akses{NC}')
elif 'username' in body_lower and 'password' in body_lower:
    print(f'\n  {YELLOW}[!] Portal tipe LOGIN — butuh username & password{NC}')
elif 'agree' in body_lower or 'accept' in body_lower:
    print(f'\n  {GREEN}[+] Portal tipe TERMS — klik agree/accept aja!{NC}')
    print(f'  {GREEN}    Coba: curl -X POST {url} -d "accept=1"{NC}')
elif 'phone' in body_lower or 'sms' in body_lower:
    print(f'\n  {YELLOW}[!] Portal tipe SMS/OTP — butuh nomor HP{NC}')
else:
    print(f'\n  {DIM}Tipe portal tidak dikenali{NC}')
PYEOF
  pause
}
