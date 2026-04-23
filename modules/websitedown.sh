#!/bin/bash
# modules/websitedown.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

DOWN_DIR="$SCRIPT_ROOT/data/downloads"
mkdir -p "$DOWN_DIR"

websitedown_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🌐 Website Downloader${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Download halaman tunggal (HTML+CSS+JS+gambar)"
    echo -e "  ${GREEN}[2]${NC} Clone website lengkap (semua halaman)"
    echo -e "  ${GREEN}[3]${NC} Download assets saja (CSS/JS/gambar)"
    echo -e "  ${GREEN}[4]${NC} Extract semua link dari halaman"
    echo -e "  ${GREEN}[5]${NC} Mirror website offline"
    echo -e "  ${GREEN}[6]${NC} Lihat hasil download"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Hasil disimpan di data/downloads/${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) wd_single   ;;
      2) wd_clone    ;;
      3) wd_assets   ;;
      4) wd_links    ;;
      5) wd_mirror   ;;
      6) wd_list     ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

# ─────────────────────────────────────────────
wd_single() {
  section "Download Halaman Tunggal"
  echo -ne "${WHITE}  URL${NC}: "
  read -r url
  [[ -z "$url" ]] && { err "Kosong!"; pause; return; }
  [[ "$url" != http* ]] && url="https://$url"

  DOMAIN=$(echo "$url" | python3 -c "from urllib.parse import urlparse; import sys; print(urlparse(sys.stdin.read().strip()).netloc)")
  OUTDIR="$DOWN_DIR/${DOMAIN}_$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$OUTDIR"

  info "Downloading $url...\n"

  # download HTML
  spinner_start "Fetching HTML"
  HTML=$(curl -sL "$url" \
    -A "Mozilla/5.0 (Linux; Android 11)" \
    --max-time 30 \
    -k 2>/dev/null)
  spinner_stop "HTML"

  if [[ -z "$HTML" ]]; then
    err "Gagal fetch halaman"
    pause; return
  fi

  # simpan HTML
  echo "$HTML" > "$OUTDIR/index.html"
  ok "HTML disimpan"

  # extract & download CSS
  info "Downloading CSS..."
  echo "$HTML" | python3 -c "
import sys, re, urllib.request, urllib.parse, ssl, os

html    = sys.stdin.read()
base    = '$url'
outdir  = '$OUTDIR'
os.makedirs(f'{outdir}/css', exist_ok=True)

ctx = ssl.create_default_context()
ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

css_links = re.findall(r'href=[\"\'](.*?\.css(?:\?[^\"\']*)?)[\"\'"]', html)
count = 0
for link in css_links[:20]:
    try:
        full = urllib.parse.urljoin(base, link)
        req  = urllib.request.Request(full, headers={'User-Agent':'Mozilla/5.0'})
        data = urllib.request.urlopen(req, timeout=8, context=ctx).read()
        fname = re.sub(r'[^a-zA-Z0-9._-]','_', link.split('/')[-1].split('?')[0]) or f'style_{count}.css'
        with open(f'{outdir}/css/{fname}','wb') as f: f.write(data)
        count += 1
    except: pass
print(f'  {count} CSS files')
" 2>/dev/null

  # extract & download JS
  info "Downloading JavaScript..."
  echo "$HTML" | python3 -c "
import sys, re, urllib.request, urllib.parse, ssl, os

html   = sys.stdin.read()
base   = '$url'
outdir = '$OUTDIR'
os.makedirs(f'{outdir}/js', exist_ok=True)

ctx = ssl.create_default_context()
ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

js_links = re.findall(r'src=[\"\'](.*?\.js(?:\?[^\"\']*)?)[\"\'"]', html)
count = 0
for link in js_links[:20]:
    if 'font' in link.lower(): continue
    try:
        full = urllib.parse.urljoin(base, link)
        req  = urllib.request.Request(full, headers={'User-Agent':'Mozilla/5.0'})
        data = urllib.request.urlopen(req, timeout=8, context=ctx).read()
        fname = re.sub(r'[^a-zA-Z0-9._-]','_', link.split('/')[-1].split('?')[0]) or f'script_{count}.js'
        with open(f'{outdir}/js/{fname}','wb') as f: f.write(data)
        count += 1
    except: pass
print(f'  {count} JS files')
" 2>/dev/null

  # extract & download images
  info "Downloading images..."
  echo "$HTML" | python3 -c "
import sys, re, urllib.request, urllib.parse, ssl, os

html   = sys.stdin.read()
base   = '$url'
outdir = '$OUTDIR'
os.makedirs(f'{outdir}/img', exist_ok=True)

ctx = ssl.create_default_context()
ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

img_links = re.findall(r'src=[\"\'](.*?\.(?:jpg|jpeg|png|gif|svg|webp|ico)(?:\?[^\"\']*)?)[\"\'"]', html, re.I)
count = 0
for link in img_links[:30]:
    try:
        full = urllib.parse.urljoin(base, link)
        req  = urllib.request.Request(full, headers={'User-Agent':'Mozilla/5.0'})
        data = urllib.request.urlopen(req, timeout=8, context=ctx).read()
        ext  = link.split('.')[-1].split('?')[0].lower()[:4]
        fname= re.sub(r'[^a-zA-Z0-9._-]','_', link.split('/')[-1].split('?')[0]) or f'img_{count}.{ext}'
        with open(f'{outdir}/img/{fname}','wb') as f: f.write(data)
        count += 1
    except: pass
print(f'  {count} images')
" 2>/dev/null

  # summary
  TOTAL=$(find "$OUTDIR" -type f | wc -l)
  SIZE=$(du -sh "$OUTDIR" 2>/dev/null | cut -f1)
  echo ""
  ok "Download selesai!"
  ok "Folder  : ${CYAN}$OUTDIR${NC}"
  ok "Total   : ${GREEN}$TOTAL files, $SIZE${NC}"
  pause
}

# ─────────────────────────────────────────────
wd_clone() {
  section "Clone Website Lengkap"
  check_tool wget || {
    info "Install wget: ${CYAN}pkg install wget${NC}"
    pause; return
  }
  echo -ne "${WHITE}  URL${NC}: "
  read -r url
  [[ -z "$url" ]] && { err "Kosong!"; pause; return; }
  [[ "$url" != http* ]] && url="https://$url"

  echo -ne "${WHITE}  Kedalaman crawl${NC} [1-3, default 2]: "
  read -r depth; depth=${depth:-2}

  DOMAIN=$(echo "$url" | python3 -c "from urllib.parse import urlparse; import sys; print(urlparse(sys.stdin.read().strip()).netloc)" 2>/dev/null)
  OUTDIR="$DOWN_DIR/clone_${DOMAIN}_$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$OUTDIR"

  warn "Clone lengkap bisa makan waktu lama...\n"
  info "Cloning $url (depth: $depth)...\n"

  wget \
    --recursive \
    --level="$depth" \
    --convert-links \
    --adjust-extension \
    --page-requisites \
    --no-parent \
    --no-host-directories \
    --directory-prefix="$OUTDIR" \
    --user-agent="Mozilla/5.0 (Linux; Android 11)" \
    --timeout=15 \
    --tries=2 \
    --wait=1 \
    --quiet \
    --show-progress \
    "$url" 2>/dev/null

  TOTAL=$(find "$OUTDIR" -type f | wc -l)
  SIZE=$(du -sh "$OUTDIR" 2>/dev/null | cut -f1)
  echo ""
  ok "Clone selesai!"
  ok "Folder  : ${CYAN}$OUTDIR${NC}"
  ok "Total   : ${GREEN}$TOTAL files, $SIZE${NC}"
  info "Buka index.html di browser buat lihat offline"
  pause
}

# ─────────────────────────────────────────────
wd_assets() {
  section "Download Assets (CSS/JS/Gambar)"
  echo -ne "${WHITE}  URL${NC}: "
  read -r url
  [[ -z "$url" ]] && { err "Kosong!"; pause; return; }
  [[ "$url" != http* ]] && url="https://$url"

  echo -e "  ${DIM}Pilih jenis assets:${NC}"
  echo -e "  ${GREEN}[1]${NC} CSS saja"
  echo -e "  ${GREEN}[2]${NC} JavaScript saja"
  echo -e "  ${GREEN}[3]${NC} Gambar saja"
  echo -e "  ${GREEN}[4]${NC} Font saja"
  echo -e "  ${GREEN}[5]${NC} Semua assets"
  echo -ne "${WHITE}  Pilih${NC}: "
  read -r aopt

  DOMAIN=$(echo "$url" | python3 -c "from urllib.parse import urlparse; import sys; print(urlparse(sys.stdin.read().strip()).netloc)" 2>/dev/null)
  OUTDIR="$DOWN_DIR/assets_${DOMAIN}_$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$OUTDIR"

  spinner_start "Fetching page"
  HTML=$(curl -sL "$url" -A "Mozilla/5.0" --max-time 20 -k 2>/dev/null)
  spinner_stop "Done"

  python3 - "$url" "$OUTDIR" "$aopt" << 'PYEOF'
import sys, re, urllib.request, urllib.parse, ssl, os

base   = sys.argv[1]
outdir = sys.argv[2]
mode   = sys.argv[3]

import subprocess
html = subprocess.run(['cat'], input=None, capture_output=True).stdout.decode('utf-8','ignore')

# baca dari stdin
import sys as _sys
html = _sys.stdin.read() if not html else html

ctx = ssl.create_default_context()
ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'

PATTERNS = {
    'css':   (r'href=["\']([^"\']*\.css[^"\']*)["\']',   'css'),
    'js':    (r'src=["\']([^"\']*\.js[^"\']*)["\']',     'js'),
    'img':   (r'src=["\']([^"\']*\.(?:jpg|jpeg|png|gif|svg|webp|ico)[^"\']*)["\']', 'img'),
    'font':  (r'href=["\']([^"\']*\.(?:woff|woff2|ttf|eot)[^"\']*)["\']', 'fonts'),
}

selected = []
if mode == '1': selected = ['css']
elif mode == '2': selected = ['js']
elif mode == '3': selected = ['img']
elif mode == '4': selected = ['font']
else: selected = list(PATTERNS.keys())

total = 0
for key in selected:
    pattern, folder = PATTERNS[key]
    os.makedirs(f'{outdir}/{folder}', exist_ok=True)
    links = re.findall(pattern, html, re.I)[:30]
    count = 0
    for link in links:
        try:
            full  = urllib.parse.urljoin(base, link)
            req   = urllib.request.Request(full, headers={'User-Agent':'Mozilla/5.0'})
            data  = urllib.request.urlopen(req, timeout=8, context=ctx).read()
            fname = re.sub(r'[^a-zA-Z0-9._-]','_', link.split('/')[-1].split('?')[0]) or f'file_{count}.{key}'
            with open(f'{outdir}/{folder}/{fname}','wb') as f: f.write(data)
            print(f'  {GREEN}✓{NC} {fname}')
            count += 1
            total += 1
        except Exception as e:
            print(f'  {RED}✗{NC} {link.split("/")[-1][:40]}')
    print(f'  → {count} {key} files\n')

print(f'\n  Total: {total} files')
PYEOF
  pause
}

# ─────────────────────────────────────────────
wd_links() {
  section "Extract Semua Link"
  echo -ne "${WHITE}  URL${NC}: "
  read -r url
  [[ -z "$url" ]] && { err "Kosong!"; pause; return; }
  [[ "$url" != http* ]] && url="https://$url"

  spinner_start "Fetching"
  HTML=$(curl -sL "$url" -A "Mozilla/5.0" --max-time 20 -k 2>/dev/null)
  spinner_stop "Done"

  echo "$HTML" | python3 -c "
import sys, re, urllib.parse

html = sys.stdin.read()
base = '$url'
parsed = urllib.parse.urlparse(base)
base_domain = parsed.netloc

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; DIM='\033[2m'; NC='\033[0m'

# extract semua link
hrefs = re.findall(r'href=[\"\'](.*?)[\"\'"]', html)
srcs  = re.findall(r'src=[\"\'](.*?)[\"\'"]', html)
all_links = set()

for link in hrefs + srcs:
    link = link.strip()
    if not link or link.startswith('#') or link.startswith('javascript'): continue
    full = urllib.parse.urljoin(base, link)
    all_links.add(full)

# kategorikan
internal = sorted([l for l in all_links if base_domain in l])
external = sorted([l for l in all_links if base_domain not in l and l.startswith('http')])
assets   = sorted([l for l in all_links if re.search(r'\.(css|js|png|jpg|gif|svg|woff|ico)(\?|$)', l, re.I)])

print(f'  Total links: {len(all_links)}\n')
print(f'  {GREEN}Internal ({len(internal)}):{NC}')
for l in internal[:15]: print(f'  {DIM}{l[:80]}{NC}')

print(f'\n  {YELLOW}External ({len(external)}):{NC}')
for l in external[:15]: print(f'  {DIM}{l[:80]}{NC}')

print(f'\n  {CYAN}Assets ({len(assets)}):{NC}')
for l in assets[:10]: print(f'  {DIM}{l[:80]}{NC}')

# save ke file
with open('links.txt','w') as f:
    f.write('\n'.join(sorted(all_links)))
print(f'\n  Semua link disimpan ke: links.txt')
" 2>/dev/null
  pause
}

# ─────────────────────────────────────────────
wd_mirror() {
  section "Mirror Website Offline"
  check_tool wget || {
    info "Install: ${CYAN}pkg install wget${NC}"
    pause; return
  }

  echo -ne "${WHITE}  URL${NC}: "
  read -r url
  [[ -z "$url" ]] && { err "Kosong!"; pause; return; }
  [[ "$url" != http* ]] && url="https://$url"

  DOMAIN=$(echo "$url" | python3 -c "from urllib.parse import urlparse; import sys; print(urlparse(sys.stdin.read().strip()).netloc)" 2>/dev/null)
  OUTDIR="$DOWN_DIR/mirror_${DOMAIN}"
  mkdir -p "$OUTDIR"

  info "Mirroring $url untuk akses offline...\n"
  warn "Ini download SELURUH website — bisa lama & besar!\n"

  wget \
    --mirror \
    --convert-links \
    --adjust-extension \
    --page-requisites \
    --no-parent \
    --directory-prefix="$OUTDIR" \
    --user-agent="Mozilla/5.0 (Linux; Android 11)" \
    --timeout=15 \
    --tries=2 \
    --wait=0.5 \
    --quiet \
    --show-progress \
    "$url" 2>/dev/null

  TOTAL=$(find "$OUTDIR" -type f | wc -l)
  SIZE=$(du -sh "$OUTDIR" 2>/dev/null | cut -f1)
  echo ""
  ok "Mirror selesai!"
  ok "Folder : ${CYAN}$OUTDIR${NC}"
  ok "Total  : ${GREEN}$TOTAL files, $SIZE${NC}"
  pause
}

# ─────────────────────────────────────────────
wd_list() {
  section "Hasil Download"
  if [[ -z "$(ls "$DOWN_DIR" 2>/dev/null)" ]]; then
    warn "Belum ada hasil download."
    pause; return
  fi

  echo -e "  ${CYAN}Folder downloads:${NC}\n"
  i=1
  declare -a DIRS
  for d in "$DOWN_DIR"/*/; do
    [[ ! -d "$d" ]] && continue
    name=$(basename "$d")
    size=$(du -sh "$d" 2>/dev/null | cut -f1)
    files=$(find "$d" -type f | wc -l)
    echo -e "  ${GREEN}[$i]${NC} $name"
    echo -e "       ${DIM}$files files, $size${NC}"
    DIRS+=("$d")
    ((i++))
  done

  echo ""
  echo -ne "${WHITE}  Buka folder mana? (nomor/Enter skip)${NC}: "
  read -r idx
  if [[ -n "$idx" ]]; then
    idx=$((idx-1))
    if [[ $idx -ge 0 && $idx -lt ${#DIRS[@]} ]]; then
      ls -la "${DIRS[$idx]}"
    fi
  fi
  pause
}
