#!/bin/bash
# modules/hashpro.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

hashpro_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🧬 Hash Identifier Pro${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Identify hash type"
    echo -e "  ${GREEN}[2]${NC} Crack hash online (free services)"
    echo -e "  ${GREEN}[3]${NC} Crack hash dengan wordlist lokal"
    echo -e "  ${GREEN}[4]${NC} Generate hash dari teks"
    echo -e "  ${GREEN}[5]${NC} Verify hash — cocokkan teks dengan hash"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) hash_identify  ;;
      2) hash_crack_online ;;
      3) hash_crack_local  ;;
      4) hash_generate  ;;
      5) hash_verify    ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

hash_identify() {
  section "Hash Identifier"
  echo -ne "${WHITE}  Hash${NC}: "
  read -r hash
  [[ -z "$hash" ]] && { err "Kosong!"; pause; return; }

  python3 - "$hash" << 'PYEOF'
import sys, re

h = sys.argv[1].strip()
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; DIM='\033[2m'; BOLD='\033[1m'; NC='\033[0m'

print(f"\n  {CYAN}Hash   :{NC} {h[:40]}{'...' if len(h)>40 else ''}")
print(f"  {CYAN}Length :{NC} {len(h)} chars")
print(f"  {CYAN}Charset:{NC} {'hex' if all(c in '0123456789abcdefABCDEF' else False for c in h) else 'mixed'}")
print()

results = []

# by length
L = len(h)
HEX = bool(re.match(r'^[0-9a-fA-F]+$', h))
B64 = bool(re.match(r'^[A-Za-z0-9+/=]+$', h))

# common hex hashes
if HEX:
    if L == 32:  results += [('MD5',       'Very Common', 5),
                              ('MD4',       'Less Common', 3),
                              ('NTLM',      'Windows Auth', 4),
                              ('MD2',       'Rare', 1)]
    if L == 40:  results += [('SHA-1',     'Very Common', 5),
                              ('MySQL5',    'DB Auth', 4),
                              ('RIPEMD-160','Less Common', 2)]
    if L == 56:  results += [('SHA-224',   'Common', 3),
                              ('SHA3-224',  'Modern', 3)]
    if L == 64:  results += [('SHA-256',   'Very Common', 5),
                              ('SHA3-256',  'Modern', 4),
                              ('BLAKE2s',   'Modern', 3),
                              ('Keccak-256','Ethereum', 3)]
    if L == 96:  results += [('SHA-384',   'Common', 3)]
    if L == 128: results += [('SHA-512',   'Common', 4),
                              ('SHA3-512',  'Modern', 3),
                              ('BLAKE2b',   'Modern', 3),
                              ('Whirlpool', 'Rare', 2)]
    if L == 8:   results += [('CRC32',     'Checksum', 4)]
    if L == 16:  results += [('CRC64',     'Checksum', 3),
                              ('MD5 (half)','Truncated', 2)]

# prefix-based
if h.startswith('$2'):
    results.insert(0, ('bcrypt', 'Password Hash', 5))
if h.startswith('$1$'):
    results.insert(0, ('MD5crypt', 'Linux Shadow', 5))
if h.startswith('$5$'):
    results.insert(0, ('SHA-256crypt', 'Linux Shadow', 5))
if h.startswith('$6$'):
    results.insert(0, ('SHA-512crypt', 'Linux Shadow', 5))
if h.startswith('$y$') or h.startswith('$7$'):
    results.insert(0, ('yescrypt', 'Modern Linux', 5))
if h.startswith('$apr1$'):
    results.insert(0, ('APR1-MD5', 'Apache', 5))
if h.startswith('sha1$') or h.startswith('sha256$'):
    results.insert(0, ('Django Hash', 'Django Framework', 5))
if re.match(r'^[A-F0-9]{32}:[A-F0-9]{32}$', h.upper()):
    results.insert(0, ('WPA/WPA2 Hash', 'WiFi', 5))
if re.match(r'^[0-9a-f]{32}:[0-9a-f]{5}$', h.lower()):
    results.insert(0, ('MySQL < 4.1', 'Old MySQL', 4))

if results:
    results.sort(key=lambda x: -x[2])
    print(f"  {GREEN}{BOLD}Kemungkinan tipe hash:{NC}\n")
    for name, context, conf in results[:6]:
        stars = '★' * conf + '☆' * (5-conf)
        col = GREEN if conf >= 4 else YELLOW if conf >= 3 else DIM
        print(f"  {col}[{stars}]{NC} {name:<20} {DIM}{context}{NC}")
else:
    print(f"  {YELLOW}Tipe hash tidak dikenali{NC}")
    print(f"  {DIM}Mungkin encoding custom atau format tidak umum{NC}")
PYEOF
  pause
}

hash_crack_online() {
  section "Crack Hash Online"
  echo -ne "${WHITE}  Hash${NC}: "
  read -r hash
  [[ -z "$hash" ]] && { err "Kosong!"; pause; return; }

  info "Mencari di database online...\n"

  python3 - "$hash" << 'PYEOF'
import sys, urllib.request, urllib.parse, ssl, json, re, threading

h = sys.argv[1].strip()
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'

ctx = ssl.create_default_context()
ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

found = []
lock  = threading.Lock()

def fetch(url, data=None, headers={}):
    try:
        req = urllib.request.Request(url,
            data=data, headers={'User-Agent':'Mozilla/5.0',**headers})
        resp = urllib.request.urlopen(req, timeout=10, context=ctx)
        return resp.read().decode('utf-8','ignore')
    except: return ''

# ── 1. md5decrypt.net ─────────────────────────
def try_md5decrypt(h):
    body = fetch(f"https://md5decrypt.net/Api/api.php?hash={h}&hash_type=md5&email=guest&code=guest_code")
    if body and body != 'Not found':
        with lock: found.append(('md5decrypt.net', body.strip()))

# ── 2. nitrxgen ──────────────────────────────
def try_nitrxgen(h):
    body = fetch(f"http://www.nitrxgen.net/md5db/{h}")
    if body and len(body) < 200 and body.strip():
        with lock: found.append(('nitrxgen', body.strip()))

# ── 3. hashtoolkit ───────────────────────────
def try_hashtoolkit(h):
    body = fetch(f"https://hashtoolkit.com/reverse-hash?hash={h}")
    m = re.search(r'Decrypted.*?<strong>([^<]+)</strong>', body)
    if m:
        with lock: found.append(('hashtoolkit', m.group(1)))

# ── 4. hashes.com ────────────────────────────
def try_hashes(h):
    body = fetch(f"https://hashes.com/en/decrypt/hash",
        data=f"hashes={h}&type=plaintext".encode())
    m = re.search(r'"plaintext":"([^"]+)"', body)
    if m:
        with lock: found.append(('hashes.com', m.group(1)))

threads = [
    threading.Thread(target=try_md5decrypt, args=(h,)),
    threading.Thread(target=try_nitrxgen,   args=(h,)),
    threading.Thread(target=try_hashtoolkit,args=(h,)),
    threading.Thread(target=try_hashes,     args=(h,)),
]

import time
frames = ['⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏']
for t in threads: t.daemon=True; t.start()
i=0
while any(t.is_alive() for t in threads):
    print(f"\r  {CYAN}{frames[i%10]}{NC} Searching...", end='', flush=True)
    i+=1; time.sleep(0.15)
for t in threads: t.join()
print(f"\r  {GREEN}✓{NC} Done!              \n")

if found:
    print(f"  {GREEN}[CRACKED!]{NC}\n")
    for src, val in found:
        print(f"  {GREEN}[+]{NC} {CYAN}{val}{NC}  {DIM}(via {src}){NC}")
else:
    print(f"  {YELLOW}[-]{NC} Hash tidak ditemukan di database online")
    print(f"  {DIM}Coba crack lokal dengan wordlist di menu [3]{NC}")
PYEOF
  pause
}

hash_crack_local() {
  section "Crack Hash dengan Wordlist"
  check_tool john || return
  echo -ne "${WHITE}  Hash${NC}: "
  read -r hash
  [[ -z "$hash" ]] && { err "Kosong!"; pause; return; }
  echo -ne "${WHITE}  Wordlist${NC}: "
  read -r wl
  [[ ! -f "$wl" ]] && { err "Wordlist tidak ada!"; pause; return; }

  # tulis hash ke tmp file
  TMPF=$(mktemp)
  echo "$hash" > "$TMPF"
  info "Cracking..."
  john "$TMPF" --wordlist="$wl" 2>/dev/null
  echo ""
  info "Hasil:"
  john "$TMPF" --show 2>/dev/null
  rm -f "$TMPF"
  pause
}

hash_generate() {
  section "Generate Hash"
  echo -ne "${WHITE}  Teks${NC}: "
  read -r txt
  [[ -z "$txt" ]] && { err "Kosong!"; pause; return; }
  echo ""
  python3 -c "
import hashlib, sys
txt = sys.argv[1].encode()
CYAN='\033[0;36m'; NC='\033[0m'
algos = [('MD5','md5'),('SHA-1','sha1'),('SHA-224','sha224'),
         ('SHA-256','sha256'),('SHA-384','sha384'),('SHA-512','sha512'),
         ('SHA3-256','sha3_256'),('BLAKE2b','blake2b')]
for name, algo in algos:
    try:
        h = hashlib.new(algo, txt).hexdigest()
        print(f'  {CYAN}{name:<12}{NC}: {h}')
    except: pass
" "$txt" 2>/dev/null
  pause
}

hash_verify() {
  section "Verify Hash"
  echo -ne "${WHITE}  Teks asli${NC}: "
  read -r txt
  echo -ne "${WHITE}  Hash yang mau dicocokkan${NC}: "
  read -r hash
  [[ -z "$txt" || -z "$hash" ]] && { err "Kosong!"; pause; return; }
  python3 -c "
import hashlib
txt = '$txt'.encode()
h   = '$hash'.lower()
L   = len(h)
algos = {'32':['md5'],'40':['sha1'],'56':['sha224'],'64':['sha256'],
         '96':['sha384'],'128':['sha512']}
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
matched = False
for length, names in algos.items():
    if len(h) == int(length):
        for name in names:
            try:
                calc = hashlib.new(name, txt).hexdigest()
                if calc == h:
                    print(f'  {GREEN}✓ MATCH! ({name.upper()}){NC}')
                    matched = True
            except: pass
if not matched:
    print(f'  {RED}✗ Hash tidak cocok{NC}')
" 2>/dev/null
  pause
}
