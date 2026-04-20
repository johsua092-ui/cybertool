#!/bin/bash
# modules/osint.sh

osint_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🕵️  OSINT Tools${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Username Search — cek username di 20+ platform"
    echo -e "  ${GREEN}[2]${NC} IP Geolocation — lokasi, ISP, org dari IP"
    echo -e "  ${GREEN}[3]${NC} Email Breach Check — cek email kena breach"
    echo -e "  ${GREEN}[4]${NC} Subdomain Finder — enumerate subdomain"
    echo -e "  ${GREEN}[5]${NC} Google Dork Generator — buat query pencarian"
    echo -e "  ${GREEN}[6]${NC} Phone Number Lookup — info nomor telepon"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Semua info diambil dari sumber publik${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) osint_username ;;
      2) osint_ip       ;;
      3) osint_email    ;;
      4) osint_subdomain ;;
      5) osint_dork     ;;
      6) osint_phone    ;;
      0) break          ;;
      *) err "Pilihan tidak valid!"; sleep 1 ;;
    esac
  done
}

# ─────────────────────────────────────────
osint_username() {
  echo -ne "${WHITE}  Username${NC}: "
  read -r username
  [[ -z "$username" ]] && { err "Username kosong!"; pause; return; }

  section "Username Search → $username"
  info "Mengecek $username di berbagai platform...\n"

  python3 - "$username" << 'PYEOF'
import sys, urllib.request, urllib.error, ssl, threading, time

username = sys.argv[1]

# platform: (url_template, expected_status_kalau_ada)
PLATFORMS = {
    "GitHub"        : f"https://github.com/{username}",
    "Reddit"        : f"https://www.reddit.com/user/{username}",
    "Twitter/X"     : f"https://twitter.com/{username}",
    "Instagram"     : f"https://www.instagram.com/{username}",
    "TikTok"        : f"https://www.tiktok.com/@{username}",
    "LinkedIn"      : f"https://www.linkedin.com/in/{username}",
    "Pinterest"     : f"https://www.pinterest.com/{username}",
    "Twitch"        : f"https://www.twitch.tv/{username}",
    "YouTube"       : f"https://www.youtube.com/@{username}",
    "SoundCloud"    : f"https://soundcloud.com/{username}",
    "Spotify"       : f"https://open.spotify.com/user/{username}",
    "Steam"         : f"https://steamcommunity.com/id/{username}",
    "Gitlab"        : f"https://gitlab.com/{username}",
    "Keybase"       : f"https://keybase.io/{username}",
    "HackerNews"    : f"https://news.ycombinator.com/user?id={username}",
    "Dev.to"        : f"https://dev.to/{username}",
    "Medium"        : f"https://medium.com/@{username}",
    "Pastebin"      : f"https://pastebin.com/u/{username}",
    "Replit"        : f"https://replit.com/@{username}",
    "Linktree"      : f"https://linktr.ee/{username}",
    "Gravatar"      : f"https://en.gravatar.com/{username}",
    "Flickr"        : f"https://www.flickr.com/people/{username}",
}

results = {}
lock    = threading.Lock()

def check(name, url):
    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        req = urllib.request.Request(url, headers={
            'User-Agent': 'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36'
        })
        resp = urllib.request.urlopen(req, timeout=8, context=ctx)
        code = resp.getcode()
        with lock:
            results[name] = ('found', url) if code == 200 else ('unknown', url)
    except urllib.error.HTTPError as e:
        with lock:
            results[name] = ('not_found', url) if e.code == 404 else ('unknown', url)
    except Exception:
        with lock:
            results[name] = ('error', url)

threads = []
for name, url in PLATFORMS.items():
    t = threading.Thread(target=check, args=(name, url))
    t.daemon = True
    threads.append(t)
    t.start()

# progress indicator
total = len(threads)
while any(t.is_alive() for t in threads):
    done = sum(1 for n in PLATFORMS if n in results)
    print(f"\r  Checking... {done}/{total}", end='', flush=True)
    time.sleep(0.3)

for t in threads:
    t.join()

print(f"\r  Selesai! {total}/{total}           \n")

GREEN  = '\033[0;32m'
RED    = '\033[0;31m'
YELLOW = '\033[1;33m'
DIM    = '\033[2m'
NC     = '\033[0m'

found     = [(n,u) for n,(s,u) in results.items() if s == 'found']
not_found = [(n,u) for n,(s,u) in results.items() if s == 'not_found']
unknown   = [(n,u) for n,(s,u) in results.items() if s in ('unknown','error')]

print(f"  {GREEN}✓ Ditemukan ({len(found)}){NC}")
for name, url in sorted(found):
    print(f"    {GREEN}[+]{NC} {name:<15} → {DIM}{url}{NC}")

if not_found:
    print(f"\n  {RED}✗ Tidak ditemukan ({len(not_found)}){NC}")
    for name, _ in sorted(not_found):
        print(f"    {RED}[-]{NC} {name}")

if unknown:
    print(f"\n  {YELLOW}? Tidak pasti / error ({len(unknown)}){NC}")
    for name, _ in sorted(unknown):
        print(f"    {YELLOW}[?]{NC} {name}")

print(f"\n  {DIM}Catatan: 'tidak pasti' bisa karena rate limit atau bot detection{NC}")
PYEOF
  pause
}

# ─────────────────────────────────────────
osint_ip() {
  echo -ne "${WHITE}  IP Address${NC} (kosong = IP lo sendiri): "
  read -r ip

  section "IP Geolocation → ${ip:-IP lo}"
  info "Fetching info...\n"

  python3 - "$ip" << 'PYEOF'
import sys, urllib.request, urllib.error, json, ssl

ip = sys.argv[1].strip() if sys.argv[1].strip() else ""
url = f"http://ip-api.com/json/{ip}?fields=status,message,country,countryCode,regionName,city,zip,lat,lon,timezone,isp,org,as,query,mobile,proxy,hosting"

try:
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    req  = urllib.request.Request(url, headers={'User-Agent':'Mozilla/5.0'})
    resp = urllib.request.urlopen(req, timeout=10)
    data = json.loads(resp.read().decode())
except Exception as e:
    print(f"  Error: {e}")
    sys.exit()

if data.get('status') != 'success':
    print(f"  Gagal: {data.get('message','unknown error')}")
    sys.exit()

GREEN  = '\033[0;32m'
CYAN   = '\033[0;36m'
YELLOW = '\033[1;33m'
RED    = '\033[0;31m'
NC     = '\033[0m'

flags = []
if data.get('proxy'):   flags.append(f"{YELLOW}⚠ PROXY/VPN{NC}")
if data.get('hosting'): flags.append(f"{YELLOW}⚠ HOSTING/DATACENTER{NC}")
if data.get('mobile'):  flags.append(f"{CYAN}📱 MOBILE{NC}")

print(f"  {'IP Address':<18}: {GREEN}{data.get('query')}{NC}  {'  '.join(flags)}")
print(f"  {'Negara':<18}: {data.get('country')} [{data.get('countryCode')}]")
print(f"  {'Region':<18}: {data.get('regionName')}")
print(f"  {'Kota':<18}: {data.get('city')}")
print(f"  {'ZIP':<18}: {data.get('zip','-')}")
print(f"  {'Koordinat':<18}: {data.get('lat')}, {data.get('lon')}")
print(f"  {'Timezone':<18}: {data.get('timezone')}")
print(f"  {'ISP':<18}: {data.get('isp')}")
print(f"  {'Organisasi':<18}: {data.get('org')}")
print(f"  {'AS':<18}: {data.get('as')}")
print()
lat = data.get('lat')
lon = data.get('lon')
print(f"  Google Maps: https://maps.google.com/?q={lat},{lon}")
PYEOF
  pause
}

# ─────────────────────────────────────────
osint_email() {
  echo -ne "${WHITE}  Email${NC}: "
  read -r email
  [[ -z "$email" ]] && { err "Email kosong!"; pause; return; }

  section "Email Breach Check → $email"

  python3 - "$email" << 'PYEOF'
import sys, urllib.request, urllib.error, json, ssl, hashlib

email = sys.argv[1].strip()

GREEN  = '\033[0;32m'
RED    = '\033[0;31m'
YELLOW = '\033[1;33m'
CYAN   = '\033[0;36m'
DIM    = '\033[2m'
NC     = '\033[0m'

def fetch(url, headers={}):
    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        req = urllib.request.Request(url, headers={
            'User-Agent': 'Mozilla/5.0',
            **headers
        })
        resp = urllib.request.urlopen(req, timeout=10, context=ctx)
        return resp.read().decode(), resp.getcode()
    except urllib.error.HTTPError as e:
        return None, e.code
    except Exception as e:
        return None, 0

# 1. Cek via LeakCheck (free endpoint)
print(f"  {CYAN}[1/3]{NC} Mengecek via LeakCheck API...")
body, code = fetch(f"https://leakcheck.io/api/public?check={email}")
if body:
    try:
        data = json.loads(body)
        if data.get('found', 0) > 0:
            print(f"  {RED}[!] DITEMUKAN di {data['found']} breach!{NC}")
            for src in data.get('sources', [])[:10]:
                print(f"      {RED}•{NC} {src.get('name','?')}  {DIM}({src.get('date','?')}){NC}")
        else:
            print(f"  {GREEN}[✓] Tidak ditemukan di breach yang diketahui{NC}")
    except:
        print(f"  {YELLOW}[?] Tidak bisa parse response{NC}")
elif code == 429:
    print(f"  {YELLOW}[!] Rate limit — coba lagi sebentar lagi{NC}")
else:
    print(f"  {YELLOW}[?] Tidak dapat response (kode: {code}){NC}")

# 2. Validasi format & domain MX
print(f"\n  {CYAN}[2/3]{NC} Validasi email & cek domain...")
import re
pattern = r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$'
if re.match(pattern, email):
    print(f"  {GREEN}[✓]{NC} Format email valid")
    domain = email.split('@')[1]
    # cek MX record via DNS API
    mx_body, mx_code = fetch(f"https://dns.google/resolve?name={domain}&type=MX")
    if mx_body:
        try:
            mx_data = json.loads(mx_body)
            mx_records = mx_data.get('Answer', [])
            if mx_records:
                print(f"  {GREEN}[✓]{NC} Domain {domain} punya MX record → email bisa diterima")
                for mx in mx_records[:3]:
                    print(f"      {DIM}{mx.get('data','')}{NC}")
            else:
                print(f"  {YELLOW}[!]{NC} Domain {domain} tidak punya MX record")
        except:
            pass
else:
    print(f"  {RED}[✗]{NC} Format email tidak valid")

# 3. Cek Gravatar (profil publik terkait email)
print(f"\n  {CYAN}[3/3]{NC} Cek Gravatar profile...")
email_hash = hashlib.md5(email.lower().strip().encode()).hexdigest()
gravatar_url = f"https://www.gravatar.com/{email_hash}.json"
body, code = fetch(gravatar_url)
if code == 200 and body:
    try:
        gdata = json.loads(body)
        entry = gdata.get('entry', [{}])[0]
        display = entry.get('displayName', '')
        profile_url = entry.get('profileUrl', '')
        print(f"  {GREEN}[+]{NC} Gravatar ditemukan!")
        if display:    print(f"      Nama     : {display}")
        if profile_url: print(f"      Profile  : {profile_url}")
        accounts = entry.get('accounts', [])
        if accounts:
            print(f"      Akun terhubung:")
            for acc in accounts:
                print(f"        {DIM}• {acc.get('shortname','?')} — {acc.get('url','')}{NC}")
    except:
        print(f"  {GREEN}[+]{NC} Gravatar ada tapi tidak bisa parse detail")
else:
    print(f"  {DIM}[-] Tidak ada Gravatar profile{NC}")

print()
PYEOF
  pause
}

# ─────────────────────────────────────────
osint_subdomain() {
  echo -ne "${WHITE}  Domain${NC} (contoh: example.com): "
  read -r domain
  [[ -z "$domain" ]] && { err "Domain kosong!"; pause; return; }

  section "Subdomain Finder → $domain"

  python3 - "$domain" << 'PYEOF'
import sys, urllib.request, urllib.error, json, ssl, threading

domain = sys.argv[1].strip()

GREEN  = '\033[0;32m'
RED    = '\033[0;31m'
YELLOW = '\033[1;33m'
CYAN   = '\033[0;36m'
DIM    = '\033[2m'
NC     = '\033[0m'

found = set()
lock  = threading.Lock()

def fetch_json(url):
    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        resp = urllib.request.urlopen(req, timeout=10, context=ctx)
        return json.loads(resp.read().decode())
    except:
        return None

# Sumber 1: crt.sh (certificate transparency logs)
print(f"  {CYAN}[1/3]{NC} crt.sh (SSL certificate logs)...")
data = fetch_json(f"https://crt.sh/?q=%.{domain}&output=json")
if data:
    for entry in data:
        names = entry.get('name_value', '')
        for name in names.split('\n'):
            name = name.strip().lstrip('*.')
            if name.endswith(f'.{domain}') or name == domain:
                with lock: found.add(name)
    print(f"  {GREEN}[+]{NC} crt.sh: {len(found)} subdomain ditemukan")
else:
    print(f"  {YELLOW}[?]{NC} crt.sh tidak merespons")

# Sumber 2: HackerTarget
prev = len(found)
print(f"  {CYAN}[2/3]{NC} HackerTarget API...")
try:
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    req = urllib.request.Request(
        f"https://api.hackertarget.com/hostsearch/?q={domain}",
        headers={'User-Agent': 'Mozilla/5.0'}
    )
    resp = urllib.request.urlopen(req, timeout=10, context=ctx)
    text = resp.read().decode()
    if 'error' not in text.lower() and 'API count' not in text:
        for line in text.strip().split('\n'):
            if ',' in line:
                sub = line.split(',')[0].strip()
                if sub.endswith(f'.{domain}'):
                    with lock: found.add(sub)
        print(f"  {GREEN}[+]{NC} HackerTarget: {len(found)-prev} subdomain baru")
    else:
        print(f"  {YELLOW}[!]{NC} HackerTarget rate limit")
except:
    print(f"  {YELLOW}[?]{NC} HackerTarget tidak merespons")

# Sumber 3: DNS brute common subdomains
common = ['www','mail','ftp','smtp','pop','imap','api','dev','staging','test',
          'admin','portal','vpn','remote','cloud','app','mobile','cdn','blog',
          'shop','store','payment','status','docs','support','help','auth']
print(f"  {CYAN}[3/3]{NC} DNS brute ({len(common)} common subdomains)...")
import socket
brute_found = []
for sub in common:
    full = f"{sub}.{domain}"
    try:
        socket.gethostbyname(full)
        with lock:
            found.add(full)
            brute_found.append(full)
    except:
        pass
print(f"  {GREEN}[+]{NC} DNS brute: {len(brute_found)} subdomain aktif")

# Output hasil
print(f"\n  {'─'*55}")
print(f"  Total unik: {GREEN}{len(found)}{NC} subdomain\n")
for sub in sorted(found):
    marker = f"{GREEN}[+]{NC}" if any(sub.startswith(f"{c}.") for c in common) else f"{CYAN}[+]{NC}"
    print(f"  {marker} {sub}")

if not found:
    print(f"  {YELLOW}Tidak ada subdomain ditemukan.{NC}")
PYEOF
  pause
}

# ─────────────────────────────────────────
osint_dork() {
  section "Google Dork Generator"
  echo -e "  ${DIM}Google dork = query pencarian canggih buat nemuin info tersembunyi${NC}\n"

  echo -ne "${WHITE}  Target${NC} (domain atau nama): "
  read -r target
  [[ -z "$target" ]] && { err "Target kosong!"; pause; return; }

  echo -e "\n  ${CYAN}${BOLD}── File & Dokumen Sensitif ──${NC}"
  echo -e "  site:$target filetype:pdf"
  echo -e "  site:$target filetype:xls OR filetype:xlsx OR filetype:csv"
  echo -e "  site:$target filetype:sql OR filetype:db"
  echo -e "  site:$target filetype:log"
  echo -e "  site:$target filetype:env OR filetype:config"
  echo -e "  site:$target filetype:bak OR filetype:backup"

  echo -e "\n  ${CYAN}${BOLD}── Login & Admin Pages ──${NC}"
  echo -e "  site:$target inurl:login OR inurl:signin OR inurl:admin"
  echo -e "  site:$target inurl:dashboard OR inurl:panel OR inurl:portal"
  echo -e "  site:$target inurl:wp-admin OR inurl:administrator"
  echo -e "  site:$target intitle:\"index of\""

  echo -e "\n  ${CYAN}${BOLD}── Info Bocor ──${NC}"
  echo -e "  site:$target intext:password OR intext:passwd OR intext:secret"
  echo -e "  site:$target intext:\"api_key\" OR intext:\"api key\" OR intext:\"token\""
  echo -e "  site:$target intext:\"BEGIN RSA PRIVATE KEY\""
  echo -e "  \"$target\" site:pastebin.com"
  echo -e "  \"$target\" site:github.com password OR secret OR key"

  echo -e "\n  ${CYAN}${BOLD}── Subdomain & Tech ──${NC}"
  echo -e "  site:*.$target"
  echo -e "  site:$target inurl:phpinfo OR inurl:info.php"
  echo -e "  site:$target ext:php intitle:\"phpMyAdmin\""

  echo -e "\n  ${DIM}Copy-paste query di atas ke Google / Bing / DuckDuckGo${NC}"
  pause
}

# ─────────────────────────────────────────
osint_phone() {
  echo -ne "${WHITE}  Nomor HP${NC} (format internasional, contoh +628123456789): "
  read -r phone
  [[ -z "$phone" ]] && { err "Nomor kosong!"; pause; return; }

  section "Phone Lookup → $phone"

  python3 - "$phone" << 'PYEOF'
import sys, re

phone = sys.argv[1].strip().replace(' ','').replace('-','')

GREEN  = '\033[0;32m'
RED    = '\033[0;31m'
YELLOW = '\033[1;33m'
CYAN   = '\033[0;36m'
DIM    = '\033[2m'
NC     = '\033[0m'

# Validasi format
if not re.match(r'^\+?[0-9]{7,15}$', phone):
    print(f"  {RED}[✗]{NC} Format tidak valid. Gunakan format: +628xxx atau 08xxx")
    sys.exit()

# Tambah + kalau belum ada
if not phone.startswith('+'):
    if phone.startswith('0'):
        phone = '+62' + phone[1:]
    else:
        phone = '+' + phone

# Country code database (sebagian)
COUNTRY_CODES = {
    '+1':'🇺🇸 USA / Canada', '+44':'🇬🇧 UK', '+62':'🇮🇩 Indonesia',
    '+60':'🇲🇾 Malaysia', '+65':'🇸🇬 Singapore', '+63':'🇵🇭 Philippines',
    '+66':'🇹🇭 Thailand', '+84':'🇻🇳 Vietnam', '+82':'🇰🇷 South Korea',
    '+81':'🇯🇵 Japan', '+86':'🇨🇳 China', '+91':'🇮🇳 India',
    '+61':'🇦🇺 Australia', '+49':'🇩🇪 Germany', '+33':'🇫🇷 France',
    '+39':'🇮🇹 Italy', '+34':'🇪🇸 Spain', '+55':'🇧🇷 Brazil',
    '+7':'🇷🇺 Russia', '+27':'🇿🇦 South Africa', '+20':'🇪🇬 Egypt',
    '+966':'🇸🇦 Saudi Arabia', '+971':'🇦🇪 UAE', '+90':'🇹🇷 Turkey',
    '+880':'🇧🇩 Bangladesh', '+92':'🇵🇰 Pakistan', '+94':'🇱🇰 Sri Lanka',
    '+95':'🇲🇲 Myanmar', '+855':'🇰🇭 Cambodia', '+856':'🇱🇦 Laos',
}

# ID operator prefixes
ID_OPERATORS = {
    ('0811','0812','0813','0821','0822','0823','0851','0852','0853'): 'Telkomsel (Simpati/AS/Loop)',
    ('0814','0815','0816','0855','0856','0857','0858'): 'Indosat Ooredoo (IM3/Mentari)',
    ('0817','0818','0819','0859','0877','0878'): 'XL Axiata',
    ('0838','0831','0832','0833'): 'Axis (XL)',
    ('0881','0882','0883','0884','0885','0886','0887','0888','0889'): 'Smartfren',
    ('0895','0896','0897','0898','0899'): 'Three (3)',
    ('0828'): 'Indosat Ooredoo (Matrix)',
}

# detect country
country = 'Unknown'
for code, name in sorted(COUNTRY_CODES.items(), key=lambda x: -len(x[0])):
    if phone.startswith(code):
        country = name
        break

print(f"  {CYAN}Nomor${NC}    : {GREEN}{phone}{NC}")
print(f"  {CYAN}Negara${NC}   : {country}")

# kalau Indonesia, detect operator
if phone.startswith('+62'):
    local = '0' + phone[3:]
    prefix4 = local[:4]
    prefix3 = local[:3]
    operator = 'Tidak diketahui'
    for prefixes, op in ID_OPERATORS.items():
        if isinstance(prefixes, tuple):
            if prefix4 in prefixes:
                operator = op
                break
        else:
            if prefix4 == prefixes:
                operator = op
                break
    print(f"  {CYAN}Operator${NC} : {operator}")
    print(f"  {CYAN}Format lokal${NC}: {local}")

print(f"\n  {DIM}Cek lebih lanjut:{NC}")
print(f"  https://www.truecaller.com/search/id/{phone.lstrip('+')}")
print(f"  https://www.getcontact.com/en/phone/{phone}")
PYEOF
  pause
}
