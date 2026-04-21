#!/bin/bash
# modules/urlexpand.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

urlexpand_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🔗 URL Shortener Inspector${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Expand & analisis URL pendek"
    echo -e "  ${GREEN}[2]${NC} Cek banyak URL sekaligus"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Support: bit.ly, tinyurl, s.id, t.co, gg.gg, dll${NC}"
    echo -e "  ${DIM}   Analisis: redirect chain, final URL, phishing check${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) url_single ;;
      2) url_bulk   ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

url_analyze() {
  local SHORT_URL="$1"
  python3 - "$SHORT_URL" << 'PYEOF'
import sys, ssl, urllib.request, urllib.error, re, json, socket
from urllib.parse import urlparse

url = sys.argv[1].strip()
if not url.startswith(('http://','https://')):
    url = 'http://' + url

RED    = '\033[0;31m'
GREEN  = '\033[0;32m'
YELLOW = '\033[1;33m'
CYAN   = '\033[0;36m'
DIM    = '\033[2m'
BOLD   = '\033[1m'
NC     = '\033[0m'

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

SHORT_DOMAINS = {
    'bit.ly','tinyurl.com','t.co','ow.ly','buff.ly','dlvr.it',
    'ift.tt','goo.gl','rb.gy','cutt.ly','s.id','zws.im','v.gd',
    'is.gd','tiny.cc','shorturl.at','gg.gg','ouo.io','adf.ly',
    'link.tl','bc.vc','sh.st','j.mp','lnkd.in','youtu.be'
}

SUSPICIOUS_DOMAINS = {
    'ouo.io':'ad injection / misleading',
    'adf.ly':'ad injection',
    'bc.vc':'ad injection',
    'sh.st':'adware',
    'link.tl':'suspicious redirects',
}

# ── Trace redirect chain ──────────────────────
print(f"\n  {CYAN}Original URL:{NC} {url}")
print(f"  {DIM}{'─'*50}{NC}")
print(f"  {CYAN}Tracing redirect chain...{NC}\n")

redirect_chain = []
current_url    = url
max_hops       = 10

class NoRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

for hop in range(max_hops):
    parsed = urlparse(current_url)
    domain = parsed.netloc.lower()

    try:
        opener = urllib.request.build_opener(NoRedirectHandler())
        req    = opener.open(
            urllib.request.Request(current_url,
                headers={'User-Agent':'Mozilla/5.0'}),
            timeout=8
        )
        # no redirect = final destination
        final_code = req.getcode()
        redirect_chain.append((hop+1, current_url, final_code, 'FINAL'))
        break
    except urllib.error.HTTPError as e:
        loc = e.headers.get('Location','')
        redirect_chain.append((hop+1, current_url, e.code, loc[:60] if loc else ''))
        if loc:
            # resolve relative URL
            if loc.startswith('/'):
                current_url = f"{parsed.scheme}://{parsed.netloc}{loc}"
            elif not loc.startswith('http'):
                current_url = f"{parsed.scheme}://{parsed.netloc}/{loc}"
            else:
                current_url = loc
        else:
            break
    except Exception as e:
        redirect_chain.append((hop+1, current_url, 0, f'Error: {e}'))
        break

# print redirect chain
for hop, url_hop, code, dest in redirect_chain:
    arrow = f"{GREEN}✓{NC}" if dest == 'FINAL' else f"{YELLOW}→{NC}"
    col   = GREEN if code == 200 else YELLOW if code in [301,302,307,308] else RED
    print(f"  {arrow} Hop {hop}: {col}[{code}]{NC} {DIM}{url_hop[:60]}{NC}")
    if dest and dest != 'FINAL':
        print(f"       └→ {dest}")

# ── Analisis final URL ────────────────────────
if redirect_chain:
    final_url    = redirect_chain[-1][1]
    final_parsed = urlparse(final_url)
    final_domain = final_parsed.netloc.lower().replace('www.','')

    print(f"\n  {CYAN}{BOLD}── Final Destination ──{NC}")
    print(f"  URL    : {GREEN}{final_url}{NC}")
    print(f"  Domain : {final_domain}")
    print(f"  Scheme : {final_parsed.scheme}")
    print(f"  Path   : {final_parsed.path or '/'}")

    # IP lookup
    try:
        ip = socket.gethostbyname(final_domain)
        print(f"  IP     : {ip}")
    except: pass

    # hops
    hop_count = len(redirect_chain) - 1
    print(f"  Hops   : {hop_count}")

    print(f"\n  {CYAN}{BOLD}── Risk Analysis ──{NC}")
    risks   = []
    safe    = []
    score   = 0

    # known suspicious shortener
    orig_domain = urlparse(url).netloc.lower()
    if orig_domain in SUSPICIOUS_DOMAINS:
        score += 3
        risks.append(f"Shortener mencurigakan: {SUSPICIOUS_DOMAINS[orig_domain]}")

    # terlalu banyak redirect
    if hop_count > 3:
        score += 2
        risks.append(f"Redirect chain panjang ({hop_count} hops) — mungkin tracking/cloaking")

    # beda scheme (http → http padahal harusnya https)
    if final_parsed.scheme == 'http':
        score += 1
        risks.append("Final URL tidak pakai HTTPS")
    else:
        safe.append("Final URL pakai HTTPS")

    # brand impersonation di final domain
    brands = ['paypal','apple','google','facebook','amazon','netflix',
              'microsoft','instagram','tokopedia','shopee','bca','mandiri']
    for brand in brands:
        if brand in final_domain and not final_domain.endswith(f'{brand}.com'):
            score += 4
            risks.append(f"Brand impersonation: '{brand}' di {final_domain}")

    # IP langsung sebagai domain
    if re.match(r'^\d+\.\d+\.\d+\.\d+$', final_domain):
        score += 3
        risks.append("Final URL pakai IP address langsung")

    # domain sangat panjang
    if len(final_domain) > 40:
        score += 1
        risks.append(f"Domain tujuan sangat panjang ({len(final_domain)} char)")

    # suspicious keywords
    sus = ['login','signin','verify','account','secure','update','confirm']
    found = [w for w in sus if w in final_domain or w in final_parsed.path.lower()]
    if found:
        score += 1
        risks.append(f"Keyword mencurigakan: {', '.join(found)}")

    if not risks:
        safe.append("Tidak ada redirect mencurigakan")

    if risks:
        for r in risks:
            print(f"  {RED}[!]{NC} {r}")
    if safe:
        for s in safe:
            print(f"  {GREEN}[+]{NC} {s}")

    # verdict
    print()
    if score == 0:
        print(f"  Verdict: {GREEN}{BOLD}AMAN{NC} (score: 0)")
    elif score <= 2:
        print(f"  Verdict: {YELLOW}{BOLD}PERLU PERHATIAN{NC} (score: {score})")
    elif score <= 5:
        print(f"  Verdict: {YELLOW}{BOLD}MENCURIGAKAN{NC} (score: {score})")
    else:
        print(f"  Verdict: {RED}{BOLD}BERBAHAYA / KEMUNGKINAN PHISHING{NC} (score: {score})")
PYEOF
}

url_single() {
  banner
  echo -e "${CYAN}${BOLD}  🔗 URL Inspector${NC}\n"
  echo -ne "${WHITE}  URL pendek${NC}: "
  read -r url
  [[ -z "$url" ]] && { err "Kosong!"; pause; return; }
  spinner_start "Analyzing"
  url_analyze "$url"
  spinner_stop
  pause
}

url_bulk() {
  banner
  echo -e "${CYAN}${BOLD}  🔗 Bulk URL Inspector${NC}\n"
  echo -e "  ${DIM}Masukkan URL satu per baris, ketik END setelah selesai${NC}\n"
  URLS=()
  while true; do
    echo -ne "  URL: "
    read -r u
    [[ "$u" == "END" || -z "$u" ]] && break
    URLS+=("$u")
  done
  [[ ${#URLS[@]} -eq 0 ]] && { err "Kosong!"; pause; return; }
  total=${#URLS[@]}
  for i in "${!URLS[@]}"; do
    progress_bar $((i+1)) $total "Analyzing"
    section "URL $((i+1))/$total"
    url_analyze "${URLS[$i]}"
    echo ""
  done
  pause
}
