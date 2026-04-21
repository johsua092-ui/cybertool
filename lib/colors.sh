#!/bin/bash
# lib/colors.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

export RED GREEN YELLOW BLUE CYAN MAGENTA WHITE BOLD DIM NC

# ── Status Bar ──────────────────────────────────
statusbar() {
  local ip time_now wifi
  ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || echo "no IP")
  time_now=$(date '+%H:%M:%S')
  wifi=$(termux-wifi-connectioninfo 2>/dev/null | python3 -c "
import sys,json
try: d=json.load(sys.stdin); print(d.get('ssid','?'))
except: print('?')
" 2>/dev/null || echo "?")
  echo -e "${DIM}  ${CYAN}IP:${NC}${DIM} $ip   ${CYAN}WiFi:${NC}${DIM} $wifi   ${CYAN}Time:${NC}${DIM} $time_now${NC}"
}

# ── Loading Animation ───────────────────────────
loading() {
  local msg="${1:-Loading}"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  # spin selama 0.8 detik (8 x 0.1)
  while [[ $i -lt 8 ]]; do
    local f=${frames[$((i % ${#frames[@]}))]}
    echo -ne "\r  ${CYAN}${f}${NC} ${msg}..."
    sleep 0.1
    ((i++))
  done
  echo -ne "\r  ${GREEN}✓${NC} ${msg}   \n"
}

# ── Banner ──────────────────────────────────────
banner() {
  clear
  echo -e "${CYAN}${BOLD}"
  echo " ██████╗██╗   ██╗██████╗ ███████╗██████╗ "
  echo "██╔════╝╚██╗ ██╔╝██╔══██╗██╔════╝██╔══██╗"
  echo "██║      ╚████╔╝ ██████╔╝█████╗  ██████╔╝"
  echo "██║       ╚██╔╝  ██╔══██╗██╔══╝  ██╔══██╗"
  echo "╚██████╗   ██║   ██████╔╝███████╗██║  ██║"
  echo " ╚═════╝   ╚═╝   ╚═════╝ ╚══════╝╚═╝  ╚═╝"
  echo -e "${NC}${YELLOW}        Termux Cybersecurity Toolkit v3.0${NC}"
  echo -e "${DIM}${RED}    [!] Hanya untuk penggunaan legal & authorized${NC}"
  echo -e "${BLUE}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  statusbar
  echo ""
}

# ── Helpers ─────────────────────────────────────
pause()   { echo ""; echo -e "${DIM}  Tekan Enter untuk kembali...${NC}"; read -r _; }
info()    { echo -e "${CYAN}[*]${NC} $*"; }
ok()      { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
err()     { echo -e "${RED}[-]${NC} $*"; }
section() { echo -e "\n${BLUE}${BOLD}── $* ──${NC}\n"; }

check_tool() {
  if ! command -v "$1" &>/dev/null; then
    err "'$1' belum terinstall."
    warn "Jalankan ${CYAN}bash install.sh${NC} dulu."
    pause; return 1
  fi
  return 0
}

get_target() {
  echo -ne "${WHITE}  Target${NC} (IP/domain): "
  read -r TARGET
  [[ -z "$TARGET" ]] && { err "Target kosong!"; return 1; }
  return 0
}

export -f banner statusbar loading pause info ok warn err section check_tool get_target
