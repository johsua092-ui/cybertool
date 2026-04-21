#!/bin/bash
# modules/pastesearch.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

pastesearch_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🔎 Deep Paste Search${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Cari by keyword (email, domain, username)"
    echo -e "  ${GREEN}[2]${NC} Cari data breach by domain"
    echo -e "  ${GREEN}[3]${NC} Monitor keyword — alert kalau ada hasil baru"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Sumber: Pastebin, GitHub Gist, BreachDirectory, IntelX${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) paste_search   ;;
      2) paste_domain   ;;
      3) paste_monitor  ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

paste_search() {
  section "Keyword Search"
  echo -ne "${WHITE}  Keyword${NC} (email/username/domain/dll): "
  read -r keyword
  [[ -z "$keyword" ]] && { err "Kosong!"; pause; return; }

  info "Searching '$keyword' di berbagai sumber...\n"

  python3 - "$keyword" << 'PYEOF'
import sys, urllib.request, urllib.parse, json, ssl, re, threading

keyword = sys.argv[1]
RED    = '\033[0;31m'
GREEN  = '\033[0;32m'
YELLOW = '\033[1;33m'
CYAN   = '\033[0;36m'
DIM    = '\033[2m'
NC     = '\033[0m'

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

def fetch(url, headers={}):
    try:
        req = urllib.request.Request(url, headers={
            'User-Agent': 'Mozilla/5.0 (Linux; Android 11)',
            **headers
        })
        resp = urllib.request.urlopen(req, timeout=12, context=ctx)
        return resp.read().decode('utf-8','ignore'), resp.getcode()
    except Exception as e:
        return '', 0

results = []
lock = threading.Lock()

# ── 1. GitHub Gist search ──────────────────────
def search_github(kw):
    q = urllib.parse.quote(kw)
    body, code = fetch(f"https://gist.github.com/search?q={q}")
    if body:
        gists = re.findall(r'href="(/[^/"]+/[a-f0-9]{32})"', body)
        for g in gists[:5]:
            with lock:
                results.append(('GitHub Gist', f"https://gist.github.com{g}"))

# ── 2. BreachDirectory ─────────────────────────
def search_breach(kw):
    if '@' in kw:
        q = urllib.parse.quote(kw)
        body, code = fetch(f"https://breachdirectory.org/api?func=auto&term={q}")
        if body and code == 200:
            try:
                data = json.loads(body)
                if data.get('found', 0) > 0:
                    for entry in data.get('result', [])[:5]:
                        src  = entry.get('sources', ['?'])[0]
                        pwd  = entry.get('password','')
                        sha1 = entry.get('sha1','')
                        with lock:
                            results.append(('BreachDirectory',
                                f"Found in: {src} | Pass: {pwd[:3]}*** | SHA1: {sha1[:10]}..."))
            except: pass

# ── 3. IntelX search (free tier) ───────────────
def search_intelx(kw):
    body, code = fetch(
        f"https://2.intelx.io/phonebook/search?term={urllib.parse.quote(kw)}&maxresults=5&media=0&target=2",
        headers={'x-key': 'null'}
    )
    if body and code == 200:
        try:
            data = json.loads(body)
            for r in data.get('selectors', [])[:5]:
                val = r.get('selectvalue','')
                if val and val != kw:
                    with lock:
                        results.append(('IntelX', val))
        except: pass

# ── 4. Pastebin via Google dork ────────────────
def search_pastebin(kw):
    q = urllib.parse.quote(f'site:pastebin.com "{kw}"')
    body, code = fetch(f"https://www.google.com/search?q={q}&num=5")
    if body:
        links = re.findall(r'https://pastebin\.com/[A-Za-z0-9]{8}', body)
        for l in set(links)[:3]:
            with lock:
                results.append(('Pastebin', l))

threads = [
    threading.Thread(target=search_github,   args=(keyword,)),
    threading.Thread(target=search_breach,   args=(keyword,)),
    threading.Thread(target=search_intelx,   args=(keyword,)),
    threading.Thread(target=search_pastebin, args=(keyword,)),
]

frames = ['⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏']
for t in threads: t.daemon=True; t.start()

i = 0
while any(t.is_alive() for t in threads):
    print(f"\r  {CYAN}{frames[i%10]}{NC} Searching...", end='', flush=True)
    i+=1; import time; time.sleep(0.15)
for t in threads: t.join()
print(f"\r  {GREEN}✓{NC} Selesai!              \n")

if results:
    print(f"  {RED}[!] Ditemukan {len(results)} hasil:{NC}\n")
    for source, info in results:
        print(f"  {YELLOW}[{source}]{NC}")
        print(f"    {DIM}{info}{NC}\n")
else:
    print(f"  {GREEN}[✓]{NC} Tidak ditemukan di sumber yang dicek")
    print(f"  {DIM}Bukan berarti 100% aman — cek manual di haveibeenpwned.com{NC}")
PYEOF
  pause
}

paste_domain() {
  section "Domain Breach Search"
  echo -ne "${WHITE}  Domain${NC} (contoh: company.com): "
  read -r domain
  [[ -z "$domain" ]] && { err "Kosong!"; pause; return; }

  info "Mencari data bocor terkait $domain...\n"

  python3 - "$domain" << 'PYEOF'
import sys, urllib.request, urllib.parse, json, ssl, re

domain = sys.argv[1]
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'

ctx = ssl.create_default_context()
ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

def fetch(url, headers={}):
    try:
        req = urllib.request.Request(url, headers={'User-Agent':'Mozilla/5.0',**headers})
        resp = urllib.request.urlopen(req, timeout=12, context=ctx)
        return json.loads(resp.read()), resp.getcode()
    except: return None, 0

# HIBP via unofficial lookup
print(f"  {CYAN}[1/3]{NC} Cek HaveIBeenPwned breaches...")
data, code = fetch(f"https://haveibeenpwned.com/api/v3/breaches")
if data:
    domain_breaches = [b for b in data if domain.lower() in b.get('Domain','').lower()]
    if domain_breaches:
        print(f"  {RED}[!] {len(domain_breaches)} breach ditemukan untuk {domain}:{NC}")
        for b in domain_breaches[:5]:
            print(f"    {RED}•{NC} {b['Name']} ({b['BreachDate']}) — {b['PwnCount']:,} akun")
    else:
        print(f"  {GREEN}[✓]{NC} Tidak ada breach langsung untuk {domain}")

# crt.sh email harvest
print(f"  {CYAN}[2/3]{NC} Cek email di certificate logs...")
try:
    req = urllib.request.Request(
        f"https://crt.sh/?q=%40{domain}&output=json",
        headers={'User-Agent':'Mozilla/5.0'})
    resp = urllib.request.urlopen(req, timeout=10, context=ctx)
    certs = json.loads(resp.read())
    emails = set()
    for c in certs:
        for e in re.findall(r'[\w.+-]+@'+re.escape(domain), c.get('name_value','')):
            emails.add(e)
    if emails:
        print(f"  {YELLOW}[!]{NC} {len(emails)} email ditemukan di SSL certs:")
        for e in list(emails)[:10]:
            print(f"    {DIM}{e}{NC}")
    else:
        print(f"  {GREEN}[✓]{NC} Tidak ada email di SSL logs")
except Exception as e:
    print(f"  {DIM}Skip: {e}{NC}")

# Pastebin search
print(f"  {CYAN}[3/3]{NC} Cek Pastebin mentions...")
try:
    q = urllib.parse.quote(f'site:pastebin.com "{domain}"')
    req = urllib.request.Request(
        f"https://www.google.com/search?q={q}&num=5",
        headers={'User-Agent':'Mozilla/5.0'})
    resp = urllib.request.urlopen(req, timeout=10, context=ctx)
    body = resp.read().decode('utf-8','ignore')
    links = list(set(re.findall(r'https://pastebin\.com/[A-Za-z0-9]{8}', body)))[:5]
    if links:
        print(f"  {YELLOW}[!]{NC} {len(links)} paste ditemukan:")
        for l in links: print(f"    {DIM}{l}{NC}")
    else:
        print(f"  {GREEN}[✓]{NC} Tidak ada di Pastebin")
except: print(f"  {DIM}Skip (rate limited){NC}")
PYEOF
  pause
}

paste_monitor() {
  section "Monitor Keyword"
  echo -ne "${WHITE}  Keyword${NC}: "
  read -r keyword
  [[ -z "$keyword" ]] && { err "Kosong!"; pause; return; }
  echo -ne "${WHITE}  Interval cek${NC} (menit, default 30): "
  read -r interval
  interval=${interval:-30}
  warn "Monitoring '${keyword}' setiap ${interval} menit. Ctrl+C untuk stop.\n"
  LAST_COUNT=0
  while true; do
    NOW=$(date '+%H:%M:%S')
    COUNT=$(python3 -c "
import urllib.request, urllib.parse, ssl, re
ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=0
try:
    q=urllib.parse.quote('site:pastebin.com \"${keyword}\"')
    req=urllib.request.Request(f'https://www.google.com/search?q={q}',
        headers={'User-Agent':'Mozilla/5.0'})
    body=urllib.request.urlopen(req,timeout=10,context=ctx).read().decode('utf-8','ignore')
    print(len(set(re.findall(r'pastebin\.com/[A-Za-z0-9]{8}',body))))
except: print(0)
" 2>/dev/null || echo 0)
    if [[ "$COUNT" -gt "$LAST_COUNT" ]]; then
      echo -e "\n  ${RED}[!] $NOW — ADA HASIL BARU! ($COUNT total)${NC}"
      LAST_COUNT=$COUNT
    else
      echo -ne "\r  ${DIM}[$NOW] Memantau '$keyword'... ($COUNT hasil)${NC}  "
    fi
    sleep $((interval * 60))
  done
}
