#!/bin/bash
# modules/signal.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

SIGNAL_DIR="$SCRIPT_ROOT/data/signal"

signal_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  📶 Signal Strength Logger${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Live monitor sinyal WiFi"
    echo -e "  ${GREEN}[2]${NC} Log sinyal selama X menit"
    echo -e "  ${GREEN}[3]${NC} Lihat grafik ASCII dari log"
    echo -e "  ${GREEN}[4]${NC} Export log ke CSV"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Butuh Termux:API untuk baca sinyal WiFi${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) signal_live   ;;
      2) signal_log    ;;
      3) signal_graph  ;;
      4) signal_export ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

signal_check_api() {
  if ! command -v termux-wifi-connectioninfo &>/dev/null; then
    err "Termux:API tidak terinstall."
    info "Install: ${CYAN}pkg install termux-api${NC}"
    info "Lalu install app Termux:API dari F-Droid"
    pause; return 1
  fi
  return 0
}

signal_get_rssi() {
  termux-wifi-connectioninfo 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print(d.get('rssi','-100'))
except: print('-100')
" 2>/dev/null || echo "-100"
}

signal_get_ssid() {
  termux-wifi-connectioninfo 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print(d.get('ssid','Unknown'))
except: print('Unknown')
" 2>/dev/null || echo "Unknown"
}

signal_bar() {
  local rssi=$1
  local bars=5
  local filled
  if   [[ $rssi -ge -50 ]]; then filled=5
  elif [[ $rssi -ge -60 ]]; then filled=4
  elif [[ $rssi -ge -70 ]]; then filled=3
  elif [[ $rssi -ge -80 ]]; then filled=2
  else filled=1
  fi
  local bar=""
  local col
  [[ $filled -ge 4 ]] && col=$GREEN || { [[ $filled -ge 2 ]] && col=$YELLOW || col=$RED; }
  for ((i=0;i<filled;i++));  do bar+="█"; done
  for ((i=filled;i<bars;i++)); do bar+="░"; done
  echo -e "${col}${bar}${NC}"
}

signal_quality() {
  local rssi=$1
  if   [[ $rssi -ge -50 ]]; then echo "Excellent"
  elif [[ $rssi -ge -60 ]]; then echo "Good"
  elif [[ $rssi -ge -70 ]]; then echo "Fair"
  elif [[ $rssi -ge -80 ]]; then echo "Weak"
  else echo "Very Weak"
  fi
}

signal_live() {
  signal_check_api || return
  section "Live Signal Monitor"
  SSID=$(signal_get_ssid)
  info "WiFi: ${CYAN}$SSID${NC}"
  warn "Tekan Ctrl+C untuk stop\n"
  printf "  %-10s %-8s %-10s %s\n" "Time" "RSSI" "Quality" "Bar"
  echo "  ────────────────────────────────────"
  while true; do
    RSSI=$(signal_get_rssi)
    TIME=$(date '+%H:%M:%S')
    QUALITY=$(signal_quality "$RSSI")
    BAR=$(signal_bar "$RSSI")
    # warna RSSI
    if [[ $RSSI -ge -60 ]]; then COL=$GREEN
    elif [[ $RSSI -ge -75 ]]; then COL=$YELLOW
    else COL=$RED; fi
    printf "  %-10s ${COL}%-8s${NC} %-10s %b\n" "$TIME" "${RSSI}dBm" "$QUALITY" "$BAR"
    sleep 2
  done
}

signal_log() {
  signal_check_api || return
  section "Log Signal"
  mkdir -p "$SIGNAL_DIR"
  echo -ne "${WHITE}  Durasi log${NC} (menit, default 5): "
  read -r dur
  dur=${dur:-5}
  echo -ne "${WHITE}  Interval${NC} (detik, default 10): "
  read -r interval
  interval=${interval:-10}
  total_reads=$(( dur * 60 / interval ))
  LOGFILE="$SIGNAL_DIR/log_$(date +%Y%m%d_%H%M%S).csv"
  echo "timestamp,ssid,rssi,quality" > "$LOGFILE"
  SSID=$(signal_get_ssid)
  info "Logging ${CYAN}$SSID${NC} selama ${dur} menit..."
  warn "Tekan Ctrl+C untuk stop\n"
  current=0
  while [[ $current -lt $total_reads ]]; do
    ((current++))
    progress_bar $current $total_reads "Logging"
    RSSI=$(signal_get_rssi)
    TIME=$(date '+%Y-%m-%d %H:%M:%S')
    QUALITY=$(signal_quality "$RSSI")
    echo "$TIME,$SSID,$RSSI,$QUALITY" >> "$LOGFILE"
    sleep "$interval"
  done
  echo ""
  ok "Log selesai: ${CYAN}$LOGFILE${NC}"
  ok "Total sampel: $current"
  # hitung rata-rata
  python3 -c "
import csv
with open('$LOGFILE') as f:
    rows = list(csv.DictReader(f))
vals = [int(r['rssi']) for r in rows if r['rssi'].lstrip('-').isdigit()]
if vals:
    print(f'  Avg RSSI : {sum(vals)//len(vals)} dBm')
    print(f'  Min RSSI : {min(vals)} dBm')
    print(f'  Max RSSI : {max(vals)} dBm')
" 2>/dev/null
  pause
}

signal_graph() {
  section "Grafik ASCII"
  if [[ -z "$(ls "$SIGNAL_DIR"/*.csv 2>/dev/null)" ]]; then
    warn "Belum ada log. Jalankan menu [2] dulu."
    pause; return
  fi
  # pilih file log
  FILES=("$SIGNAL_DIR"/*.csv)
  if [[ ${#FILES[@]} -eq 1 ]]; then
    LOGFILE="${FILES[0]}"
  else
    echo -e "  Pilih log:\n"
    for i in "${!FILES[@]}"; do
      echo -e "  ${GREEN}[$((i+1))]${NC} $(basename "${FILES[$i]}")"
    done
    echo -ne "\n  Pilih: "
    read -r idx
    LOGFILE="${FILES[$((idx-1))]}"
  fi
  [[ ! -f "$LOGFILE" ]] && { err "File tidak ada!"; pause; return; }
  python3 - "$LOGFILE" << 'PYEOF'
import sys, csv

RED    = '\033[0;31m'
GREEN  = '\033[0;32m'
YELLOW = '\033[1;33m'
CYAN   = '\033[0;36m'
NC     = '\033[0m'

with open(sys.argv[1]) as f:
    rows = list(csv.DictReader(f))

vals  = [(r['timestamp'], int(r['rssi'])) for r in rows if r['rssi'].lstrip('-').isdigit()]
if not vals:
    print("  Tidak ada data.")
    sys.exit()

times = [v[0][-8:] for v in vals]  # HH:MM:SS
rssiv = [v[1] for v in vals]
mn, mx = min(rssiv), max(rssiv)

HEIGHT = 12
WIDTH  = min(len(vals), 50)
step   = max(1, len(vals)//WIDTH)
sampled = [(times[i], rssiv[i]) for i in range(0, len(vals), step)][:WIDTH]

print(f"\n  {'─'*55}")
print(f"  RSSI Range: {mn} dBm — {mx} dBm  |  Samples: {len(vals)}")
print(f"  {'─'*55}\n")

# normalize ke HEIGHT
def norm(v): return int((v - mn) / max(mx - mn, 1) * (HEIGHT-1))

# build grid
grid = [[' ']*(len(sampled)) for _ in range(HEIGHT)]
for x,(t,v) in enumerate(sampled):
    y = norm(v)
    grid[HEIGHT-1-y][x] = '█'

# print dengan y-axis label
for row_i, row in enumerate(grid):
    rssi_label = mn + int((HEIGHT-1-row_i) * (mx-mn) / (HEIGHT-1)) if mx!=mn else mn
    col = GREEN if rssi_label >= -60 else YELLOW if rssi_label >= -75 else RED
    bar_str = ''
    for cell in row:
        if cell == '█':
            bar_str += f'{col}█{NC}'
        else:
            bar_str += ' '
    print(f"  {col}{rssi_label:4d}dBm{NC} │{bar_str}")

# x-axis (waktu)
print(f"         └{'─'*len(sampled)}")
# label waktu pertama & terakhir
if sampled:
    print(f"          {sampled[0][0]}{'':>{len(sampled)-17}}{sampled[-1][0]}")
PYEOF
  pause
}

signal_export() {
  section "Export ke /sdcard"
  if [[ -z "$(ls "$SIGNAL_DIR"/*.csv 2>/dev/null)" ]]; then
    warn "Belum ada log."
    pause; return
  fi
  DEST="/sdcard/Download/"
  cp "$SIGNAL_DIR"/*.csv "$DEST" 2>/dev/null
  ok "Log CSV tersimpan di /sdcard/Download/"
  ls "$SIGNAL_DIR"/*.csv | while read f; do
    echo -e "  ${DIM}$(basename "$f")${NC}"
  done
  pause
}
