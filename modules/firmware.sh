#!/bin/bash
# modules/firmware.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

firmware_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🧩 Firmware Analyzer${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Analisis firmware file"
    echo -e "  ${GREEN}[2]${NC} Extract & explore filesystem"
    echo -e "  ${GREEN}[3]${NC} Cari credentials & backdoor"
    echo -e "  ${GREEN}[4]${NC} Cari hardcoded IP & URL"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Support: .bin .img .fw .gz .zip router/IoT firmware${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) fw_analyze   ;;
      2) fw_extract   ;;
      3) fw_creds     ;;
      4) fw_iocs      ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

fw_get_file() {
  echo -ne "${WHITE}  Path firmware${NC}: "
  read -r FW_FILE
  [[ -z "$FW_FILE" ]] && { err "Kosong!"; return 1; }
  [[ ! -f "$FW_FILE" ]] && { err "File tidak ditemukan!"; return 1; }
  return 0
}

fw_analyze() {
  section "Firmware Analysis"
  fw_get_file || { pause; return; }

  info "Analyzing $(basename "$FW_FILE")...\n"

  # basic file info
  SIZE=$(du -sh "$FW_FILE" | cut -f1)
  MD5=$(md5sum "$FW_FILE" | cut -d' ' -f1)
  echo -e "  ${CYAN}File   :${NC} $(basename "$FW_FILE")"
  echo -e "  ${CYAN}Size   :${NC} $SIZE"
  echo -e "  ${CYAN}MD5    :${NC} $MD5"
  echo ""

  # binwalk analysis
  if command -v binwalk &>/dev/null; then
    spinner_start "Binwalk scan"
    BWOUT=$(binwalk "$FW_FILE" 2>/dev/null)
    spinner_stop "Binwalk"
    echo -e "  ${CYAN}${BOLD}── Binwalk Signatures ──${NC}"
    echo "$BWOUT" | grep -v "^DECIMAL\|^---\|^$" | while read -r line; do
      echo -e "  ${DIM}$line${NC}"
    done | head -20
    echo ""

    # hitung berapa component ditemukan
    COMP_COUNT=$(echo "$BWOUT" | grep -c "^[0-9]" || echo 0)
    ok "Ditemukan $COMP_COUNT komponen/signature"
  else
    warn "binwalk tidak terinstall (pkg install binwalk)"
  fi

  # strings analysis
  echo -e "\n  ${CYAN}${BOLD}── Strings Analysis ──${NC}"
  spinner_start "Extracting strings"
  STRINGS=$(strings "$FW_FILE" 2>/dev/null)
  spinner_stop "Strings"

  # detect OS/platform
  if echo "$STRINGS" | grep -qi "linux"; then
    ok "Platform: ${GREEN}Linux${NC}"
    VER=$(echo "$STRINGS" | grep -i "linux version" | head -1)
    [[ -n "$VER" ]] && echo -e "  ${DIM}$VER${NC}"
  fi
  if echo "$STRINGS" | grep -qi "busybox"; then
    ok "BusyBox terdeteksi (typical embedded Linux)"
  fi
  if echo "$STRINGS" | grep -qi "openwrt\|dd-wrt\|tomato"; then
    ok "Router firmware terdeteksi"
  fi
  if echo "$STRINGS" | grep -qi "vxworks\|ucos\|freertos"; then
    ok "RTOS terdeteksi"
  fi
  pause
}

fw_extract() {
  section "Extract Firmware"
  fw_get_file || { pause; return; }
  check_tool binwalk || return

  OUTDIR="$SCRIPT_ROOT/data/firmware/$(basename "$FW_FILE")_extracted"
  mkdir -p "$OUTDIR"

  spinner_start "Extracting"
  binwalk -e --directory="$OUTDIR" "$FW_FILE" 2>/dev/null
  spinner_stop "Extract"

  if [[ -n "$(ls "$OUTDIR" 2>/dev/null)" ]]; then
    ok "Extracted ke: ${CYAN}$OUTDIR${NC}"
    echo ""
    echo -e "  ${CYAN}Isi:${NC}"
    find "$OUTDIR" -maxdepth 3 -type f 2>/dev/null | head -30 | while read -r f; do
      echo -e "  ${DIM}$f${NC}"
    done
    TOTAL=$(find "$OUTDIR" -type f 2>/dev/null | wc -l)
    echo -e "\n  Total: $TOTAL files"
  else
    warn "Extract gagal atau tidak ada content yang bisa diekstrak"
  fi
  pause
}

fw_creds() {
  section "Credential & Backdoor Hunt"
  fw_get_file || { pause; return; }

  spinner_start "Hunting credentials"
  python3 - "$FW_FILE" << 'PYEOF'
import sys, re, subprocess

fw = sys.argv[1]
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'

try:
    strings_out = subprocess.run(['strings', '-n', '6', fw],
        capture_output=True, text=True, timeout=60).stdout
except Exception as e:
    print(f"Error: {e}"); sys.exit()

lines = strings_out.splitlines()
found = {'passwords':[], 'users':[], 'keys':[], 'backdoors':[]}

for line in lines:
    l = line.strip()
    if not l or len(l) > 200: continue

    # passwords
    if re.search(r'(?i)(password|passwd|pwd)\s*[=:]\s*\S+', l):
        found['passwords'].append(l)
    # users
    if re.search(r'(?i)(username|user|login|admin)\s*[=:]\s*\S+', l):
        found['users'].append(l)
    # private keys
    if re.search(r'BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY', l):
        found['keys'].append(l)
    # backdoor indicators
    if re.search(r'(?i)(backdoor|shell|netcat|/bin/sh|/bin/bash|telnetd|dropbear)', l):
        found['backdoors'].append(l)
    # hardcoded creds
    if re.search(r'(?i)(root:.*:|admin:.*:)', l):
        found['passwords'].append(l)

for category, items in found.items():
    if items:
        print(f"\n  {RED}[!] {category.upper()} ({len(items)} ditemukan):{NC}")
        for item in list(set(items))[:5]:
            print(f"  {YELLOW}  →{NC} {DIM}{item[:100]}{NC}")

if not any(found.values()):
    print(f"  {GREEN}[✓]{NC} Tidak ada credentials/backdoor obvious ditemukan")
    print(f"  {DIM}Coba extract dulu (menu [2]) untuk analisis lebih dalam{NC}")
PYEOF
  spinner_stop "Done"
  pause
}

fw_iocs() {
  section "IP & URL Hunt"
  fw_get_file || { pause; return; }

  spinner_start "Extracting IOCs"
  python3 - "$FW_FILE" << 'PYEOF'
import sys, re, subprocess

fw = sys.argv[1]
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'

try:
    strings_out = subprocess.run(['strings', '-n', '6', fw],
        capture_output=True, text=True, timeout=60).stdout
except Exception as e:
    print(f"Error: {e}"); sys.exit()

ips   = set(re.findall(r'\b(?!192\.168|10\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[01]\.|127\.|0\.0\.0)(?:\d{1,3}\.){3}\d{1,3}\b', strings_out))
urls  = set(re.findall(r'https?://[^\s"\'<>]{10,100}', strings_out))
hosts = set(re.findall(r'\b[a-z0-9][a-z0-9\-]{2,}\.[a-z]{2,6}\b', strings_out))

sus_tlds = ['.ru','.cn','.tk','.ml','.ga','.cf','.gq','.top','.xyz']
sus_hosts = [h for h in hosts if any(h.endswith(t) for t in sus_tlds)]

print(f"\n  {CYAN}{BOLD}── Public IPs ({len(ips)}) ──{NC}")
for ip in sorted(ips)[:15]:
    print(f"  {YELLOW}→{NC} {ip}")

print(f"\n  {CYAN}{BOLD}── URLs ({len(urls)}) ──{NC}")
for url in sorted(urls)[:15]:
    col = RED if any(t in url for t in sus_tlds) else DIM
    print(f"  {YELLOW}→{NC} {col}{url[:80]}{NC}")

if sus_hosts:
    print(f"\n  {RED}{BOLD}── Suspicious Hosts ──{NC}")
    for h in sorted(sus_hosts)[:10]:
        print(f"  {RED}[!]{NC} {h}")
PYEOF
  spinner_stop "Done"
  pause
}
