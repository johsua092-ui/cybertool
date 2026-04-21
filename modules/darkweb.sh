#!/bin/bash
# modules/darkweb.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

darkweb_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🕵️  Dark Web Monitor${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Cek email di breach database"
    echo -e "  ${GREEN}[2]${NC} Cek domain di dark web mentions"
    echo -e "  ${GREEN}[3]${NC} Monitor keyword — alert kalau muncul"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Menggunakan sumber publik: HIBP, IntelX, DeHashed${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) dw_email   ;;
      2) dw_domain  ;;
      3) dw_monitor ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

dw_email() {
  section "Email Breach Check"
  echo -ne "${WHITE}  Email${NC}: "
  read -r email
  [[ -z "$email" ]] && { err "Kosong!"; pause; return; }
  spinner_start "Checking dark web sources"
  python3 - "$email" << 'PYEOF'
import sys, urllib.request, urllib.parse, json, ssl, re, hashlib

email = sys.argv[1].strip()
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'

ctx = ssl.create_default_context()
ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

def fetch(url, headers={}):
    try:
        req = urllib.request.Request(url,
            headers={'User-Agent':'Mozilla/5.0',**headers})
        resp = urllib.request.urlopen(req, timeout=12, context=ctx)
        return resp.read().decode('utf-8','ignore'), resp.getcode()
    except urllib.error.HTTPError as e:
        return '', e.code
    except: return '', 0

print(f"\n  Checking: {CYAN}{email}{NC}\n")

# 1. HIBP public breaches
print(f"  {CYAN}[1/4]{NC} HaveIBeenPwned...")
body, code = fetch(f"https://haveibeenpwned.com/api/v3/breachedaccount/{urllib.parse.quote(email)}?truncateResponse=false",
    headers={'hibp-api-key':'', 'User-Agent':'cybertool'})
if code == 200 and body:
    try:
        breaches = json.loads(body)
        print(f"  {RED}[!] Ditemukan di {len(breaches)} breach:{NC}")
        for b in breaches[:8]:
            print(f"    {RED}•{NC} {b['Name']} ({b['BreachDate']}) — {b['PwnCount']:,} akun")
    except: pass
elif code == 404:
    print(f"  {GREEN}[✓]{NC} Tidak ditemukan di HIBP")
else:
    print(f"  {DIM}[-] Rate limited atau error{NC}")

# 2. LeakCheck
print(f"  {CYAN}[2/4]{NC} LeakCheck...")
body, code = fetch(f"https://leakcheck.io/api/public?check={urllib.parse.quote(email)}")
if body:
    try:
        d = json.loads(body)
        if d.get('found', 0) > 0:
            print(f"  {RED}[!] {d['found']} leak ditemukan:{NC}")
            for s in d.get('sources',[])[:5]:
                print(f"    {RED}•{NC} {s.get('name','?')} ({s.get('date','?')})")
        else:
            print(f"  {GREEN}[✓]{NC} Tidak ditemukan di LeakCheck")
    except: print(f"  {DIM}[-] Error{NC}")

# 3. Gravatar (profil publik)
print(f"  {CYAN}[3/4]{NC} Gravatar profile...")
h = hashlib.md5(email.lower().strip().encode()).hexdigest()
body, code = fetch(f"https://www.gravatar.com/{h}.json")
if code == 200 and body:
    try:
        d = json.loads(body)
        e = d.get('entry',[{}])[0]
        print(f"  {YELLOW}[!]{NC} Gravatar profile ditemukan!")
        if e.get('displayName'): print(f"    Nama: {e['displayName']}")
        if e.get('profileUrl'):  print(f"    URL : {e['profileUrl']}")
    except: pass
else:
    print(f"  {DIM}[-] Tidak ada Gravatar{NC}")

# 4. Intelx
print(f"  {CYAN}[4/4]{NC} IntelX search...")
body, code = fetch(f"https://2.intelx.io/phonebook/search?term={urllib.parse.quote(email)}&maxresults=5&media=0&target=1")
if body and code == 200:
    try:
        d = json.loads(body)
        sels = d.get('selectors',[])
        if sels:
            print(f"  {YELLOW}[!]{NC} {len(sels)} referensi di IntelX:")
            for s in sels[:3]:
                print(f"    {DIM}{s.get('selectvalue','')}  [{s.get('selectortype','')}]{NC}")
        else:
            print(f"  {GREEN}[✓]{NC} Tidak ditemukan di IntelX")
    except: pass
PYEOF
  spinner_stop "Done"
  pause
}

dw_domain() {
  section "Domain Dark Web Check"
  echo -ne "${WHITE}  Domain${NC}: "
  read -r domain
  [[ -z "$domain" ]] && { err "Kosong!"; pause; return; }
  spinner_start "Searching"
  python3 - "$domain" << 'PYEOF'
import sys, urllib.request, urllib.parse, json, ssl, re

domain = sys.argv[1].strip()
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'

ctx = ssl.create_default_context()
ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

def fetch(url):
    try:
        req = urllib.request.Request(url, headers={'User-Agent':'Mozilla/5.0'})
        return urllib.request.urlopen(req, timeout=12, context=ctx).read().decode('utf-8','ignore')
    except: return ''

print(f"\n  Domain: {CYAN}{domain}{NC}\n")

# HIBP breaches by domain
print(f"  {CYAN}[1/3]{NC} HIBP breach database...")
body = fetch("https://haveibeenpwned.com/api/v3/breaches")
if body:
    try:
        breaches = json.loads(body)
        matched  = [b for b in breaches if domain.lower() in b.get('Domain','').lower()]
        if matched:
            print(f"  {RED}[!] {len(matched)} breach terkait {domain}:{NC}")
            for b in matched[:5]:
                print(f"    {RED}•{NC} {b['Name']} ({b['BreachDate']}) — {b['PwnCount']:,} akun")
        else:
            print(f"  {GREEN}[✓]{NC} Tidak ada breach langsung untuk {domain}")
    except: pass

# URLScan
print(f"  {CYAN}[2/3]{NC} URLScan.io...")
body = fetch(f"https://urlscan.io/api/v1/search/?q=domain:{domain}&size=5")
if body:
    try:
        d = json.loads(body)
        results = d.get('results',[])
        mal = sum(1 for r in results if r.get('verdicts',{}).get('overall',{}).get('malicious',False))
        print(f"  {'⚠' if mal else '✓'} URLScan: {len(results)} scan, {mal} malicious")
    except: pass

# Pastebin
print(f"  {CYAN}[3/3]{NC} Paste sites...")
q = urllib.parse.quote(f'site:pastebin.com "{domain}"')
body = fetch(f"https://www.google.com/search?q={q}&num=5")
links = list(set(re.findall(r'pastebin\.com/[A-Za-z0-9]{8}', body)))
if links:
    print(f"  {YELLOW}[!]{NC} {len(links)} paste ditemukan:")
    for l in links[:3]: print(f"    {DIM}https://{l}{NC}")
else:
    print(f"  {GREEN}[✓]{NC} Tidak ditemukan di Pastebin")
PYEOF
  spinner_stop "Done"
  pause
}

dw_monitor() {
  section "Monitor Keyword"
  echo -ne "${WHITE}  Keyword${NC}: "
  read -r kw
  [[ -z "$kw" ]] && { err "Kosong!"; pause; return; }
  echo -ne "${WHITE}  Interval${NC} (menit, default 60): "
  read -r interval
  interval=${interval:-60}
  warn "Monitoring '$kw' setiap $interval menit. Ctrl+C untuk stop.\n"
  PREV=0
  while true; do
    NOW=$(date '+%H:%M:%S')
    COUNT=$(python3 -c "
import urllib.request, urllib.parse, ssl, re, json
ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=0
total=0
try:
    q=urllib.parse.quote(f'site:pastebin.com \"${kw}\"')
    body=urllib.request.urlopen(urllib.request.Request(
        f'https://www.google.com/search?q={q}',
        headers={'User-Agent':'Mozilla/5.0'}),timeout=10,context=ctx).read().decode()
    total+=len(set(re.findall(r'pastebin\.com/[A-Za-z0-9]{8}',body)))
except: pass
print(total)
" 2>/dev/null || echo 0)
    if [[ "$COUNT" -gt "$PREV" ]]; then
      echo -e "\n  ${RED}[!] $NOW — HASIL BARU! ($COUNT total)${NC}"
      PREV=$COUNT
    else
      echo -ne "\r  ${DIM}[$NOW] Memantau '$kw'... ($COUNT hasil, cek lagi $(date -d "+${interval} minutes" '+%H:%M' 2>/dev/null || echo 'nanti'))${NC}  "
    fi
    sleep $((interval * 60))
  done
}
