#!/bin/bash
# modules/recon.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

recon_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🎯 Recon Otomatis${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Full Recon — scan lengkap 1 target"
    echo -e "  ${GREEN}[2]${NC} Quick Recon — versi cepat (< 2 menit)"
    echo -e "  ${GREEN}[3]${NC} Lihat hasil recon tersimpan"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Menggabungkan: Nmap + Whois + DNS + Subdomain + Tech${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) recon_full  ;;
      2) recon_quick ;;
      3) recon_list  ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

recon_run() {
  local TARGET="$1"
  local MODE="$2"       # full / quick
  local OUTDIR="$SCRIPT_ROOT/reports/recon_${TARGET}_$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$OUTDIR"
  local REPORT="$OUTDIR/report.txt"

  {
    echo "══════════════════════════════════════════════"
    echo "  CyberTool Recon Report"
    echo "  Target : $TARGET"
    echo "  Mode   : $MODE"
    echo "  Date   : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "══════════════════════════════════════════════"
    echo ""
  } | tee "$REPORT"

  # ── 1. Whois ──────────────────────────────
  echo -ne "  ${CYAN}[1/6]${NC} Whois lookup..."
  if command -v whois &>/dev/null; then
    {
      echo "── WHOIS ──────────────────────────────────"
      whois "$TARGET" 2>/dev/null | grep -Ev "^#|^%|^$" | head -30
      echo ""
    } | tee -a "$REPORT" > /dev/null
    echo -e " ${GREEN}✓${NC}"
  else
    echo -e " ${YELLOW}skip (whois tidak ada)${NC}"
  fi

  # ── 2. DNS Lookup ─────────────────────────
  echo -ne "  ${CYAN}[2/6]${NC} DNS lookup..."
  {
    echo "── DNS RECORDS ────────────────────────────"
    for type in A AAAA MX NS TXT; do
      result=$(dig +short "$type" "$TARGET" 2>/dev/null)
      [[ -n "$result" ]] && echo "  $type: $result"
    done
    echo ""
  } | tee -a "$REPORT" > /dev/null
  echo -e " ${GREEN}✓${NC}"

  # ── 3. Nmap Port Scan ─────────────────────
  echo -ne "  ${CYAN}[3/6]${NC} Port scan..."
  if command -v nmap &>/dev/null; then
    if [[ "$MODE" == "quick" ]]; then
      NMAP_RESULT=$(nmap -T4 --top-ports 100 "$TARGET" 2>/dev/null)
    else
      NMAP_RESULT=$(nmap -sV -T4 "$TARGET" 2>/dev/null)
    fi
    {
      echo "── PORT SCAN ──────────────────────────────"
      echo "$NMAP_RESULT"
      echo ""
    } | tee -a "$REPORT" > /dev/null
    OPEN_PORTS=$(echo "$NMAP_RESULT" | grep "^[0-9]" | grep "open" | awk '{print $1}' | tr '\n' ' ')
    echo -e " ${GREEN}✓${NC} open: ${OPEN_PORTS:-none}"
  else
    echo -e " ${YELLOW}skip (nmap tidak ada)${NC}"
  fi

  # ── 4. HTTP Headers & Tech ────────────────
  echo -ne "  ${CYAN}[4/6]${NC} Web fingerprint..."
  {
    echo "── WEB FINGERPRINT ────────────────────────"
    HEADERS=$(curl -sI "http://$TARGET" --max-time 8 2>/dev/null)
    echo "$HEADERS" | grep -iE "server:|x-powered-by:|content-type:|location:" | head -10
    # cek HTTPS juga
    HEADERS_S=$(curl -sI "https://$TARGET" --max-time 8 -k 2>/dev/null)
    echo "$HEADERS_S" | grep -iE "server:|x-powered-by:|strict-transport:" | head -5
    echo ""
  } | tee -a "$REPORT" > /dev/null
  echo -e " ${GREEN}✓${NC}"

  # ── 5. Subdomain (quick = crt.sh aja) ────
  echo -ne "  ${CYAN}[5/6]${NC} Subdomain enum..."
  {
    echo "── SUBDOMAINS ─────────────────────────────"
    python3 -c "
import urllib.request, json, ssl
ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=0
try:
    req = urllib.request.Request(f'https://crt.sh/?q=%.${TARGET}&output=json',
          headers={'User-Agent':'Mozilla/5.0'})
    data = json.loads(urllib.request.urlopen(req,timeout=10,context=ctx).read())
    subs = sorted(set(n.strip().lstrip('*.') for e in data
                  for n in e.get('name_value','').split('\n')
                  if n.endswith('.${TARGET}')))
    [print(f'  {s}') for s in subs[:30]]
    print(f'  Total: {len(subs)} subdomain')
except Exception as e:
    print(f'  Error: {e}')
" 2>/dev/null
    echo ""
  } | tee -a "$REPORT" > /dev/null
  echo -e " ${GREEN}✓${NC}"

  # ── 6. IP Geolocation ────────────────────
  echo -ne "  ${CYAN}[6/6]${NC} IP geolocation..."
  {
    echo "── IP GEOLOCATION ─────────────────────────"
    python3 -c "
import urllib.request, json, ssl
ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=0
try:
    req = urllib.request.Request(f'http://ip-api.com/json/${TARGET}',
          headers={'User-Agent':'Mozilla/5.0'})
    d = json.loads(urllib.request.urlopen(req,timeout=8,context=ctx).read())
    if d.get('status')=='success':
        print(f'  IP      : {d.get(\"query\")}')
        print(f'  Country : {d.get(\"country\")} [{d.get(\"countryCode\")}]')
        print(f'  City    : {d.get(\"city\")}')
        print(f'  ISP     : {d.get(\"isp\")}')
        print(f'  Org     : {d.get(\"org\")}')
        if d.get(\"proxy\"): print(f'  [!] PROXY/VPN terdeteksi!')
except Exception as e:
    print(f'  Error: {e}')
" 2>/dev/null
    echo ""
  } | tee -a "$REPORT" > /dev/null
  echo -e " ${GREEN}✓${NC}"

  echo ""
  echo -e "${GREEN}${BOLD}  ══ SUMMARY ══${NC}"

  # tampil ringkasan dari report
  python3 -c "
import re
with open('$REPORT') as f: content = f.read()

# open ports
ports = re.findall(r'(\d+/\w+)\s+open\s+(\S+)', content)
if ports:
    print('\n  \033[0;32m[+] Open Ports:\033[0m')
    for p,s in ports[:10]: print(f'      {p:<20} {s}')

# subdomains
subs = re.findall(r'^\s{2}(\S+\.$TARGET)', content, re.M)
if subs:
    print(f'\n  \033[0;32m[+] Subdomains ({len(subs)}):\033[0m')
    for s in subs[:8]: print(f'      {s}')

# server
server = re.search(r'[Ss]erver:\s*(.+)', content)
if server: print(f'\n  \033[0;32m[+] Server:\033[0m {server.group(1).strip()}')

# geo
country = re.search(r'Country\s*:\s*(.+)', content)
isp     = re.search(r'ISP\s*:\s*(.+)', content)
if country: print(f'\n  \033[0;32m[+] Location:\033[0m {country.group(1).strip()}')
if isp:     print(f'  \033[0;32m[+] ISP:\033[0m {isp.group(1).strip()}')
" TARGET="$TARGET" 2>/dev/null

  echo ""
  ok "Report lengkap disimpan di: ${CYAN}$OUTDIR/report.txt${NC}"
}

recon_full() {
  banner
  echo -e "${CYAN}${BOLD}  🎯 Full Recon${NC}\n"
  echo -ne "${WHITE}  Target${NC} (domain/IP): "
  read -r TARGET
  [[ -z "$TARGET" ]] && { err "Kosong!"; pause; return; }
  warn "Full recon bisa makan 3-5 menit...\n"
  recon_run "$TARGET" "full"
  pause
}

recon_quick() {
  banner
  echo -e "${CYAN}${BOLD}  🎯 Quick Recon${NC}\n"
  echo -ne "${WHITE}  Target${NC} (domain/IP): "
  read -r TARGET
  [[ -z "$TARGET" ]] && { err "Kosong!"; pause; return; }
  info "Quick recon (~1-2 menit)\n"
  recon_run "$TARGET" "quick"
  pause
}

recon_list() {
  section "Hasil Recon Tersimpan"
  REPDIR="$SCRIPT_ROOT/reports"
  if [[ ! -d "$REPDIR" ]] || [[ -z "$(ls "$REPDIR" 2>/dev/null)" ]]; then
    warn "Belum ada hasil recon."
    pause; return
  fi
  echo -e "  ${DIM}Folder: $REPDIR${NC}\n"
  i=1
  declare -a DIRS
  for d in "$REPDIR"/recon_*/; do
    name=$(basename "$d")
    date_str=$(echo "$name" | grep -oP '\d{8}_\d{6}')
    target=$(echo "$name" | sed 's/recon_//' | sed "s/_${date_str}//")
    echo -e "  ${GREEN}[$i]${NC} $target  ${DIM}($date_str)${NC}"
    DIRS+=("$d")
    ((i++))
  done
  echo ""
  echo -ne "${WHITE}  Lihat report no${NC}: "
  read -r idx
  idx=$((idx-1))
  if [[ $idx -ge 0 && $idx -lt ${#DIRS[@]} ]]; then
    less "${DIRS[$idx]}/report.txt"
  else
    err "Tidak valid!"
  fi
  pause
}
