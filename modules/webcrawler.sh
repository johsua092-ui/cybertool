#!/bin/bash
# modules/webcrawler.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

webcrawler_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🕸️  Web Crawler${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Crawl website — extract semua links"
    echo -e "  ${GREEN}[2]${NC} Extract semua email dari website"
    echo -e "  ${GREEN}[3]${NC} Extract semua form & input fields"
    echo -e "  ${GREEN}[4]${NC} Cari komentar HTML tersembunyi"
    echo -e "  ${GREEN}[5]${NC} Full crawl — semua sekaligus"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Crawl hanya halaman yang diizinkan. Hormati robots.txt${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) crawl_links    ;;
      2) crawl_emails   ;;
      3) crawl_forms    ;;
      4) crawl_comments ;;
      5) crawl_full     ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

crawl_fetch() {
  local url="$1"
  curl -sL "$url" --max-time 15 \
    -A "Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36" \
    -k 2>/dev/null
}

crawl_links() {
  banner
  echo -e "${CYAN}${BOLD}  🕸️  Link Extractor${NC}\n"
  echo -ne "${WHITE}  URL${NC}: "
  read -r url
  [[ -z "$url" ]] && { err "Kosong!"; pause; return; }
  [[ "$url" != http* ]] && url="https://$url"

  echo -ne "${WHITE}  Depth${NC} [1-3, default 1]: "
  read -r depth
  depth=${depth:-1}

  section "Crawling → $url"
  spinner_start "Fetching"
  BODY=$(crawl_fetch "$url")
  spinner_stop "Done"

  python3 - "$url" "$depth" << PYEOF
import sys, re, urllib.parse, urllib.request, ssl, time

base_url = sys.argv[1]
depth    = int(sys.argv[2])
parsed   = urllib.parse.urlparse(base_url)
base_dom = f"{parsed.scheme}://{parsed.netloc}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'

ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=0
visited = set()
all_links = {'internal':set(), 'external':set(), 'media':set(), 'api':set()}

def fetch(u):
    try:
        req = urllib.request.Request(u, headers={'User-Agent':'Mozilla/5.0'})
        return urllib.request.urlopen(req, timeout=10, context=ctx).read().decode('utf-8','ignore')
    except: return ''

def extract_links(body, current_url):
    links = re.findall(r'href=["\']([^"\']+)["\']|src=["\']([^"\']+)["\']|action=["\']([^"\']+)["\']', body)
    result = set()
    for grp in links:
        for link in grp:
            if not link: continue
            if link.startswith('//'):
                link = parsed.scheme + ':' + link
            elif link.startswith('/'):
                link = base_dom + link
            elif not link.startswith('http'):
                link = urllib.parse.urljoin(current_url, link)
            result.add(link.split('#')[0].rstrip('/'))
    return result

def categorize(link):
    if re.search(r'\.(jpg|jpeg|png|gif|svg|ico|webp|mp4|mp3|pdf|doc|zip)(\?|$)', link, re.I):
        return 'media'
    elif '/api/' in link or '/v1/' in link or '/v2/' in link or '.json' in link:
        return 'api'
    elif parsed.netloc in link:
        return 'internal'
    else:
        return 'external'

queue = [(base_url, 0)]
while queue:
    curr_url, curr_depth = queue.pop(0)
    if curr_url in visited or curr_depth > depth: continue
    visited.add(curr_url)
    body = fetch(curr_url)
    if not body: continue
    for link in extract_links(body, curr_url):
        if not link or len(link) < 10: continue
        cat = categorize(link)
        all_links[cat].add(link)
        if cat == 'internal' and link not in visited and curr_depth < depth:
            queue.append((link, curr_depth+1))

print(f"\n  Crawled {len(visited)} halaman\n")
for cat, links in all_links.items():
    if links:
        col = GREEN if cat=='internal' else YELLOW if cat=='external' else CYAN
        print(f"  {col}{BOLD}{cat.upper()} ({len(links)}){NC}")
        for l in sorted(links)[:15]:
            print(f"  {DIM}{l[:80]}{NC}")
        if len(links) > 15: print(f"  {DIM}...dan {len(links)-15} lagi{NC}")
        print()
PYEOF
  pause
}

crawl_emails() {
  banner
  echo -e "${CYAN}${BOLD}  🕸️  Email Extractor${NC}\n"
  echo -ne "${WHITE}  URL${NC}: "
  read -r url
  [[ -z "$url" ]] && { err "Kosong!"; pause; return; }
  [[ "$url" != http* ]] && url="https://$url"

  spinner_start "Crawling"
  BODY=$(crawl_fetch "$url")
  spinner_stop "Done"

  echo "$BODY" | python3 -c "
import sys, re
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'
body  = sys.stdin.read()
emails= sorted(set(re.findall(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}', body)))
if emails:
    print(f'\n  {GREEN}[+] {len(emails)} email ditemukan:{NC}\n')
    for e in emails:
        print(f'  {CYAN}→{NC} {e}')
else:
    print(f'  {DIM}Tidak ada email ditemukan di halaman ini{NC}')
"
  pause
}

crawl_forms() {
  banner
  echo -e "${CYAN}${BOLD}  🕸️  Form Extractor${NC}\n"
  echo -ne "${WHITE}  URL${NC}: "
  read -r url
  [[ -z "$url" ]] && { err "Kosong!"; pause; return; }
  [[ "$url" != http* ]] && url="https://$url"

  spinner_start "Fetching"
  BODY=$(crawl_fetch "$url")
  spinner_stop "Done"

  echo "$BODY" | python3 -c "
import sys, re
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'
body   = sys.stdin.read()
forms  = re.findall(r'<form[^>]*>(.*?)</form>', body, re.DOTALL|re.IGNORECASE)
print(f'\n  Ditemukan {len(forms)} form\n')
for i, form in enumerate(forms, 1):
    action = re.search(r'action=[\"\'](.*?)[\"\']', form)
    method = re.search(r'method=[\"\'](.*?)[\"\']', form, re.I)
    inputs = re.findall(r'<input[^>]*>', form, re.I)
    print(f'  {GREEN}Form {i}:{NC}')
    print(f'    Action : {action.group(1) if action else \"/\"}')
    print(f'    Method : {(method.group(1) if method else \"GET\").upper()}')
    print(f'    Inputs :')
    for inp in inputs:
        name = re.search(r'name=[\"\'](.*?)[\"\']', inp)
        itype= re.search(r'type=[\"\'](.*?)[\"\']', inp, re.I)
        n    = name.group(1) if name else '?'
        t    = (itype.group(1) if itype else 'text').lower()
        col  = RED if t in ['password','hidden'] else YELLOW if t in ['email','tel'] else DIM
        print(f'    {col}  [{t}] {n}{NC}')
    print()
"
  pause
}

crawl_comments() {
  banner
  echo -e "${CYAN}${BOLD}  🕸️  HTML Comment Hunter${NC}\n"
  echo -ne "${WHITE}  URL${NC}: "
  read -r url
  [[ -z "$url" ]] && { err "Kosong!"; pause; return; }
  [[ "$url" != http* ]] && url="https://$url"

  spinner_start "Fetching"
  BODY=$(crawl_fetch "$url")
  spinner_stop "Done"

  echo "$BODY" | python3 -c "
import sys, re
RED='\033[0;31m'; YELLOW='\033[1;33m'; DIM='\033[2m'; GREEN='\033[0;32m'; NC='\033[0m'
body     = sys.stdin.read()
comments = re.findall(r'<!--(.*?)-->', body, re.DOTALL)
if comments:
    print(f'\n  Ditemukan {len(comments)} komentar HTML:\n')
    for i, c in enumerate(comments, 1):
        c = c.strip()
        if not c: continue
        sus = any(w in c.lower() for w in ['todo','fixme','hack','password','key','token','debug','test','remove','api'])
        col = RED if sus else DIM
        print(f'  {RED if sus else YELLOW}[{i}]{NC} {col}{c[:120]}{NC}')
        if sus: print(f'  {RED}    ↑ MENCURIGAKAN!{NC}')
        print()
else:
    print(f'  {DIM}Tidak ada komentar HTML ditemukan{NC}')
"
  pause
}

crawl_full() {
  banner
  echo -e "${CYAN}${BOLD}  🕸️  Full Crawl${NC}\n"
  echo -ne "${WHITE}  URL${NC}: "
  read -r url
  [[ -z "$url" ]] && { err "Kosong!"; pause; return; }
  [[ "$url" != http* ]] && url="https://$url"

  BODY=$(crawl_fetch "$url")
  for i in 1 2 3 4; do
    progress_bar $i 4 "Crawling"
    sleep 0.3
  done
  echo ""

  section "Links"
  echo "$BODY" | python3 -c "
import sys,re,urllib.parse
body=sys.stdin.read(); CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'
links=list(set(re.findall(r'href=[\"\'](https?://[^\"\']+)[\"\']\|src=[\"\'](https?://[^\"\']+)[\"\'']',body)))
hrefs=sorted(set(re.findall(r'href=[\"\'](https?://[^\"\']{5,})[\"\'']',body)))[:10]
for l in hrefs: print(f'  {DIM}{l[:80]}{NC}')
print(f'  {CYAN}...lihat menu [1] untuk crawl lengkap{NC}')
"

  section "Emails"
  echo "$BODY" | python3 -c "
import sys,re
body=sys.stdin.read(); GREEN='\033[0;32m'; NC='\033[0m'
emails=sorted(set(re.findall(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}',body)))
for e in emails[:10]: print(f'  {GREEN}→{NC} {e}')
print(f'  ({len(emails)} total)') if emails else print('  Tidak ada')
"

  section "Komentar Mencurigakan"
  echo "$BODY" | python3 -c "
import sys,re
body=sys.stdin.read(); RED='\033[0;31m'; DIM='\033[2m'; NC='\033[0m'
comments=re.findall(r'<!--(.*?)-->',body,re.DOTALL)
sus=[c.strip() for c in comments if any(w in c.lower() for w in ['todo','password','key','token','debug','api'])]
for c in sus[:5]: print(f'  {RED}[!]{NC} {DIM}{c[:100]}{NC}')
print(f'  {len(sus)} komentar mencurigakan') if sus else print('  Tidak ada')
"
  pause
}
