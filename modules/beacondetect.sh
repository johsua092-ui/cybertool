#!/bin/bash
# modules/beacondetect.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

beacondetect_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  📡 Beacon Spammer Detector${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Scan semua WiFi beacon di sekitar"
    echo -e "  ${GREEN}[2]${NC} Detect fake / evil twin AP"
    echo -e "  ${GREEN}[3]${NC} Monitor probe request mencurigakan"
    echo -e "  ${GREEN}[4]${NC} Analisis keamanan AP sekitar"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Butuh Termux:API untuk scan WiFi${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) beacon_scan     ;;
      2) beacon_eviltwin ;;
      3) beacon_probe    ;;
      4) beacon_security ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

beacon_scan() {
  section "WiFi Beacon Scanner"
  if ! command -v termux-wifi-scaninfo &>/dev/null; then
    err "Butuh Termux:API"
    info "Install: ${CYAN}pkg install termux-api${NC}"
    pause; return
  fi
  spinner_start "Scanning beacons"
  DATA=$(termux-wifi-scaninfo 2>/dev/null)
  spinner_stop "Done"

  echo "$DATA" | python3 -c "
import sys, json, re
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; DIM='\033[2m'; BOLD='\033[1m'; NC='\033[0m'

try:
    nets = json.load(sys.stdin)
except: nets = []

if not nets:
    print('  Tidak ada jaringan ditemukan.')
    sys.exit()

print(f'  Total: {len(nets)} beacon terdeteksi\n')
print(f'  {CYAN}{\"SSID\":<28} {\"BSSID\":<20} {\"Signal\":>7}  {\"Security\":<10} {\"Ch\"}{NC}')
print('  ' + '─'*75)

for n in sorted(nets, key=lambda x: -x.get('level',-100)):
    ssid  = (n.get('SSID') or 'Hidden')[:27]
    bssid = n.get('BSSID','?')
    level = n.get('level',-100)
    caps  = n.get('capabilities','')
    freq  = n.get('frequency',0)
    ch    = (freq-2407)//5 if 2400<freq<5000 else freq

    sec = 'WPA3' if 'WPA3' in caps else 'WPA2' if 'WPA2' in caps else 'WPA' if 'WPA' in caps else 'OPEN'
    col = GREEN if level>-60 else YELLOW if level>-80 else RED
    sec_col = RED if sec=='OPEN' else YELLOW if sec=='WPA' else GREEN

    flags = []
    if sec == 'OPEN': flags.append(f'{RED}OPEN!{NC}')
    if not n.get('SSID'): flags.append(f'{YELLOW}HIDDEN{NC}')
    if 'WPS' in caps: flags.append(f'{YELLOW}WPS{NC}')

    flag_str = ' '.join(flags)
    print(f'  {ssid:<28} {DIM}{bssid:<20}{NC} {col}{level:>4}dBm{NC}  {sec_col}{sec:<10}{NC} {ch}  {flag_str}')

# Analisis
opens  = [n for n in nets if 'WPA' not in n.get('capabilities','') and 'WEP' not in n.get('capabilities','')]
hidden = [n for n in nets if not n.get('SSID')]

print()
if opens:  print(f'  {RED}[!] {len(opens)} jaringan OPEN (tanpa password)!{NC}')
if hidden: print(f'  {YELLOW}[!] {len(hidden)} jaringan tersembunyi (hidden SSID){NC}')
" 2>/dev/null
  pause
}

beacon_eviltwin() {
  section "Evil Twin / Fake AP Detector"
  if ! command -v termux-wifi-scaninfo &>/dev/null; then
    err "Butuh Termux:API"; pause; return
  fi
  spinner_start "Scanning"
  DATA=$(termux-wifi-scaninfo 2>/dev/null)
  spinner_stop "Done"

  echo "$DATA" | python3 -c "
import sys, json, collections
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'

try: nets = json.load(sys.stdin)
except: nets = []

# Group by SSID
by_ssid = collections.defaultdict(list)
for n in nets:
    ssid = n.get('SSID','')
    if ssid:
        by_ssid[ssid].append(n)

print(f'  Analisis {len(nets)} jaringan...\n')

found_suspicious = False
for ssid, aps in by_ssid.items():
    if len(aps) > 1:
        # Banyak AP dengan SSID sama — normal untuk enterprise, tapi suspicious kalau security beda
        securities = set()
        for ap in aps:
            caps = ap.get('capabilities','')
            sec = 'WPA3' if 'WPA3' in caps else 'WPA2' if 'WPA2' in caps else 'WPA' if 'WPA' in caps else 'OPEN'
            securities.add(sec)

        if len(securities) > 1:
            found_suspicious = True
            print(f'  {RED}[!!] SUSPICIOUS: \"{ssid}\"{NC}')
            print(f'       {RED}Security berbeda pada AP yang sama!{NC}')
            for ap in aps:
                caps = ap.get('capabilities','')
                sec  = 'WPA3' if 'WPA3' in caps else 'WPA2' if 'WPA2' in caps else 'WPA' if 'WPA' in caps else 'OPEN'
                bssid= ap.get('BSSID','?')
                level= ap.get('level',-100)
                print(f'       {DIM}→ {bssid}  {sec}  {level}dBm{NC}')
            print()
        else:
            print(f'  {GREEN}[✓]{NC} \"{ssid}\" — {len(aps)} AP, security konsisten ({list(securities)[0]})')

if not found_suspicious:
    print(f'\n  {GREEN}Tidak ada evil twin terdeteksi!{NC}')
    print(f'  {DIM}Semua SSID duplikat punya security yang konsisten{NC}')
" 2>/dev/null
  pause
}

beacon_probe() {
  section "Probe Request Monitor"
  info "Monitoring probe request dari device sekitar...\n"
  warn "Butuh Termux:API. Tekan Ctrl+C untuk stop.\n"

  if ! command -v termux-wifi-scaninfo &>/dev/null; then
    err "Butuh Termux:API"; pause; return
  fi

  PREV=""
  ROUND=0
  while true; do
    CURR=$(termux-wifi-scaninfo 2>/dev/null | python3 -c "
import sys,json
try:
    nets=json.load(sys.stdin)
    ssids=sorted([n.get('SSID','?') for n in nets])
    print('\n'.join(ssids))
except: pass
" 2>/dev/null)

    NEW=$(comm -13 <(echo "$PREV" | sort) <(echo "$CURR" | sort) 2>/dev/null)
    GONE=$(comm -23 <(echo "$PREV" | sort) <(echo "$CURR" | sort) 2>/dev/null)

    [[ -n "$NEW" ]]  && echo -e "  ${GREEN}[+]${NC} $(date '+%H:%M:%S') Muncul: ${GREEN}$NEW${NC}"
    [[ -n "$GONE" ]] && echo -e "  ${RED}[-]${NC} $(date '+%H:%M:%S') Hilang: ${RED}$GONE${NC}"
    [[ -z "$NEW" && -z "$GONE" ]] && echo -ne "\r  ${DIM}[$(date '+%H:%M:%S')] Monitoring... ($((++ROUND)) scan)${NC}  "

    PREV="$CURR"
    sleep 10
  done
}

beacon_security() {
  section "Security Analysis"
  if ! command -v termux-wifi-scaninfo &>/dev/null; then
    err "Butuh Termux:API"; pause; return
  fi
  spinner_start "Analyzing"
  DATA=$(termux-wifi-scaninfo 2>/dev/null)
  spinner_stop "Done"

  echo "$DATA" | python3 -c "
import sys, json
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'

try: nets = json.load(sys.stdin)
except: nets = []

total  = len(nets)
wpa3   = sum(1 for n in nets if 'WPA3' in n.get('capabilities',''))
wpa2   = sum(1 for n in nets if 'WPA2' in n.get('capabilities','') and 'WPA3' not in n.get('capabilities',''))
wpa    = sum(1 for n in nets if 'WPA' in n.get('capabilities','') and 'WPA2' not in n.get('capabilities','') and 'WPA3' not in n.get('capabilities',''))
wps    = sum(1 for n in nets if 'WPS' in n.get('capabilities',''))
open_  = sum(1 for n in nets if 'WPA' not in n.get('capabilities',''))

print(f'  Analisis {total} jaringan WiFi di sekitar:\n')
print(f'  {GREEN}WPA3     : {wpa3:3d} ({wpa3*100//total if total else 0}%) ← paling aman{NC}')
print(f'  {GREEN}WPA2     : {wpa2:3d} ({wpa2*100//total if total else 0}%) ← aman{NC}')
print(f'  {YELLOW}WPA      : {wpa:3d} ({wpa*100//total if total else 0}%) ← lemah{NC}')
print(f'  {RED}OPEN     : {open_:3d} ({open_*100//total if total else 0}%) ← BERBAHAYA{NC}')
print(f'  {YELLOW}WPS      : {wps:3d} ({wps*100//total if total else 0}%) ← vulnerable{NC}')

print()
if open_ > 0:
    print(f'  {RED}[!] {open_} jaringan tanpa enkripsi — hindari konek!{NC}')
if wps > 0:
    print(f'  {YELLOW}[!] {wps} jaringan dengan WPS aktif — bisa di-bruteforce{NC}')
if wpa > 0:
    print(f'  {YELLOW}[!] {wpa} jaringan WPA (bukan WPA2/3) — enkripsi lemah{NC}')
if wpa3 == total:
    print(f'  {GREEN}Semua jaringan pakai WPA3 — area ini aman!{NC}')
" 2>/dev/null
  pause
}
