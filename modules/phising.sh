#!/bin/bash
# modules/phishing.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

phishing_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🕷️  Phishing Detector${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Cek URL / domain tunggal"
    echo -e "  ${GREEN}[2]${NC} Cek banyak URL sekaligus"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Analisis: blacklist, typosquat, SSL, redirect, skor risiko${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) phishing_check_single ;;
      2) phishing_check_bulk   ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

phishing_analyze() {
  local URL="$1"
  python3 - "$URL" << 'PYEOF'
import sys, re, ssl, socket, urllib.request, urllib.error, json, hashlib
from datetime import datetime

url = sys.argv[1].strip()
if not url.startswith(('http://','https://')):
    url = 'http://' + url

# ── parse ────────────────────────────────────────
from urllib.parse import urlparse
parsed   = urlparse(url)
domain   = parsed.netloc.lower().replace('www.','')
path     = parsed.path
scheme   = parsed.scheme

RED    = '\033[0;31m'
GREEN  = '\033[0;32m'
YELLOW = '\033[1;33m'
CYAN   = '\033[0;36m'
WHITE  = '\033[1;37m'
DIM    = '\033[2m'
BOLD   = '\033[1m'
NC     = '\033[0m'

score  = 0   # 0=aman, makin tinggi makin bahaya
flags  = []
good   = []

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

def fetch(u, timeout=8):
    try:
        req = urllib.request.Request(u, headers={'User-Agent':'Mozilla/5.0'})
        r   = urllib.request.urlopen(req, timeout=timeout, context=ctx)
        return r.read(5000).decode('utf-8','ignore'), r.getcode(), dict(r.headers)
    except urllib.error.HTTPError as e:
        return '', e.code, {}
    except Exception:
        return '', 0, {}

print(f"\n  {CYAN}{BOLD}Target   :{NC} {url}")
print(f"  {CYAN}Domain   :{NC} {domain}")
print(f"  {CYAN}Scheme   :{NC} {scheme}")
print(f"  {'─'*50}")

# ── 1. HTTP vs HTTPS ─────────────────────────────
if scheme == 'http':
    score += 1
    flags.append("HTTP (tidak terenkripsi)")
else:
    good.append("Menggunakan HTTPS")

# ── 2. SSL cert check ────────────────────────────
print(f"  {DIM}[1/7] Cek SSL...{NC}", end='', flush=True)
try:
    ctx2 = ssl.create_default_context()
    with socket.create_connection((domain, 443), timeout=6) as sock:
        with ctx2.wrap_socket(sock, server_hostname=domain) as ssock:
            cert = ssock.getpeercert()
            exp  = datetime.strptime(cert['notAfter'], '%b %d %H:%M:%S %Y %Z')
            days_left = (exp - datetime.utcnow()).days
            if days_left < 7:
                score += 3; flags.append(f"SSL expired / hampir expired ({days_left} hari)")
            elif days_left < 30:
                score += 1; flags.append(f"SSL akan expire dalam {days_left} hari")
            else:
                good.append(f"SSL valid ({days_left} hari tersisa)")
    print(f" {GREEN}✓{NC}")
except ssl.SSLError:
    score += 2; flags.append("SSL error / invalid cert")
    print(f" {YELLOW}!{NC}")
except Exception:
    print(f" {DIM}skip{NC}")

# ── 3. Suspicious keywords di domain ─────────────
print(f"  {DIM}[2/7] Analisis domain...{NC}", end='', flush=True)
sus_words = ['login','signin','secure','account','verify','update','confirm',
             'banking','paypal','apple','google','facebook','amazon','netflix',
             'support','helpdesk','wallet','crypto','free','win','prize','click']
legit_brands = ['paypal','apple','google','facebook','amazon','netflix','bank',
                'microsoft','instagram','tiktok','tokopedia','shopee','bca','mandiri','bni']

found_sus   = [w for w in sus_words if w in domain]
found_brand = [b for b in legit_brands if b in domain]

# brand ada tapi bukan domain aslinya
for brand in found_brand:
    brand_domains = {
        'paypal':'paypal.com','apple':'apple.com','google':'google.com',
        'facebook':'facebook.com','amazon':'amazon.com','netflix':'netflix.com',
        'microsoft':'microsoft.com','instagram':'instagram.com',
        'tiktok':'tiktok.com','tokopedia':'tokopedia.com','shopee':'shopee.co.id',
        'bca':'klikbca.com','mandiri':'bankmandiri.co.id','bni':'bni.co.id'
    }
    real = brand_domains.get(brand,'')
    if real and domain != real and not domain.endswith('.'+real):
        score += 5
        flags.append(f"Brand impersonation: '{brand}' (asli: {real})")

if found_sus and not found_brand:
    score += 1
    flags.append(f"Kata mencurigakan di domain: {', '.join(found_sus[:3])}")
print(f" {GREEN}✓{NC}")

# ── 4. Typosquatting ─────────────────────────────
print(f"  {DIM}[3/7] Typosquat check...{NC}", end='', flush=True)
targets = ['google.com','facebook.com','paypal.com','apple.com','amazon.com',
           'instagram.com','twitter.com','netflix.com','microsoft.com',
           'tokopedia.com','shopee.co.id','bukalapak.com','gojek.com']

def levenshtein(s1, s2):
    m,n = len(s1),len(s2)
    dp = list(range(n+1))
    for i in range(1,m+1):
        prev = dp[:]
        dp[0] = i
        for j in range(1,n+1):
            dp[j] = prev[j-1] if s1[i-1]==s2[j-1] else 1+min(prev[j],dp[j-1],prev[j-1])
    return dp[n]

# strip TLD untuk perbandingan
d_base = re.sub(r'\.[a-z]{2,6}$','',domain)
for t in targets:
    t_base = re.sub(r'\.[a-z]{2,6}$','',t)
    dist = levenshtein(d_base, t_base)
    if 0 < dist <= 2:
        score += 4
        flags.append(f"Typosquatting '{t}' (jarak edit: {dist})")
        break
print(f" {GREEN}✓{NC}")

# ── 5. IP sebagai domain ──────────────────────────
print(f"  {DIM}[4/7] Cek format domain...{NC}", end='', flush=True)
if re.match(r'^\d+\.\d+\.\d+\.\d+$', domain):
    score += 3
    flags.append("Domain pakai IP address langsung")
# subdomain berlebihan
sub_count = domain.count('.')
if sub_count > 3:
    score += 2
    flags.append(f"Terlalu banyak subdomain ({sub_count} titik)")
# domain sangat panjang
if len(domain) > 40:
    score += 1
    flags.append(f"Domain sangat panjang ({len(domain)} karakter)")
# karakter aneh
if re.search(r'[-]{2,}|[0-9]{4,}', domain):
    score += 1
    flags.append("Pola aneh di domain (double dash / banyak angka)")
print(f" {GREEN}✓{NC}")

# ── 6. Redirect check ────────────────────────────
print(f"  {DIM}[5/7] Cek redirect...{NC}", end='', flush=True)
try:
    import urllib.request as ur
    class NoRedirect(ur.HTTPErrorProcessor):
        def http_response(self, req, resp): return resp
        https_response = http_response
    opener = ur.build_opener(NoRedirect)
    resp   = opener.open(url, timeout=6)
    loc    = resp.headers.get('Location','')
    if loc and loc != url:
        score += 1
        flags.append(f"Redirect ke: {loc[:60]}")
    else:
        good.append("Tidak ada redirect mencurigakan")
    print(f" {GREEN}✓{NC}")
except Exception:
    print(f" {DIM}skip{NC}")

# ── 7. Google Safe Browsing (lookup via VirusTotal free) ─
print(f"  {DIM}[6/7] Reputation check...{NC}", end='', flush=True)
try:
    # VirusTotal free URL check (no API key, public endpoint)
    url_id = hashlib.sha256(url.encode()).hexdigest() # bukan actual VT check tapi hash lookup
    # pakai URLScan.io free search
    req = urllib.request.Request(
        f"https://urlscan.io/api/v1/search/?q=domain:{domain}&size=3",
        headers={'User-Agent':'Mozilla/5.0'}
    )
    resp = urllib.request.urlopen(req, timeout=8, context=ctx)
    data = json.loads(resp.read())
    results = data.get('results',[])
    malicious = sum(1 for r in results
                    if r.get('verdicts',{}).get('overall',{}).get('malicious',False))
    if malicious > 0:
        score += 5
        flags.append(f"URLScan: {malicious} scan mendeteksi sebagai malicious")
    elif results:
        good.append(f"URLScan: {len(results)} scan, tidak ada yang malicious")
    print(f" {GREEN}✓{NC}")
except Exception:
    print(f" {DIM}skip{NC}")

# ── 8. Page content check ────────────────────────
print(f"  {DIM}[7/7] Analisis konten...{NC}", end='', flush=True)
body, code, headers = fetch(url)
if body:
    body_lower = body.lower()
    sus_content = ['password','credit card','social security','ssn','cvv',
                   'login','username','email','verify your','confirm your']
    found_content = [w for w in sus_content if w in body_lower]
    if len(found_content) >= 3:
        score += 2
        flags.append(f"Konten meminta info sensitif: {', '.join(found_content[:3])}")
    # form action ke domain lain
    form_actions = re.findall(r'action=["\']([^"\']+)["\']', body_lower)
    for action in form_actions:
        if action.startswith('http') and domain not in action:
            score += 3
            flags.append(f"Form submit ke domain lain: {action[:50]}")
            break
print(f" {GREEN}✓{NC}")

# ── OUTPUT HASIL ─────────────────────────────────
print(f"\n  {'═'*50}")

# risk level
if score == 0:
    risk_color = GREEN
    risk_label = "AMAN"
    risk_icon  = "✓"
elif score <= 2:
    risk_color = YELLOW
    risk_label = "PERLU PERHATIAN"
    risk_icon  = "!"
elif score <= 5:
    risk_color = f'\033[0;33m'
    risk_label = "MENCURIGAKAN"
    risk_icon  = "⚠"
else:
    risk_color = RED
    risk_label = "KEMUNGKINAN PHISHING"
    risk_icon  = "✗"

print(f"\n  Risk Score : {BOLD}{score}/15{NC}")
print(f"  Status     : {risk_color}{BOLD}{risk_icon} {risk_label}{NC}")

if flags:
    print(f"\n  {RED}Tanda Bahaya:{NC}")
    for f in flags:
        print(f"    {RED}[!]{NC} {f}")

if good:
    print(f"\n  {GREEN}Indikator Aman:{NC}")
    for g in good:
        print(f"    {GREEN}[+]{NC} {g}")

print(f"\n  {DIM}Catatan: Hasil ini bukan 100% akurat. Selalu waspada.{NC}")
PYEOF
}

phishing_check_single() {
  banner
  echo -e "${CYAN}${BOLD}  🕷️  Phishing Check${NC}\n"
  echo -ne "${WHITE}  URL / Domain${NC}: "
  read -r url
  [[ -z "$url" ]] && { err "Kosong!"; pause; return; }
  section "Analyzing → $url"
  phishing_analyze "$url"
  pause
}

phishing_check_bulk() {
  banner
  echo -e "${CYAN}${BOLD}  🕷️  Bulk Phishing Check${NC}\n"
  echo -e "  ${DIM}Masukkan URL satu per baris, ketik END setelah selesai${NC}\n"
  URLS=()
  while true; do
    echo -ne "  URL: "
    read -r u
    [[ "$u" == "END" || -z "$u" ]] && break
    URLS+=("$u")
  done
  [[ ${#URLS[@]} -eq 0 ]] && { err "Tidak ada URL!"; pause; return; }
  for u in "${URLS[@]}"; do
    section "→ $u"
    phishing_analyze "$u"
    echo ""
  done
  pause
}
