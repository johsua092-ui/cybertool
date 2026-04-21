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

# ── Status Bar (non-blocking, timeout 1 detik) ──
statusbar() {
  local ip time_now
  # ip — cepet, langsung dari route table
  ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || echo "-")
  time_now=$(date '+%H:%M:%S')
  echo -e "${DIM}  ${CYAN}IP:${NC}${DIM} $ip   ${CYAN}Time:${NC}${DIM} $time_now${NC}"
}

# ── Loading Animation ───────────────────────────
loading() {
  local msg="${1:-Loading}"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  while [[ $i -lt 8 ]]; do
    echo -ne "\r  ${CYAN}${frames[$((i % 10))]}${NC} ${msg}..."
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

# ── Progress Bar ─────────────────────────────────
# Usage: progress_bar <current> <total> <label>
progress_bar() {
  local current=$1
  local total=$2
  local label="${3:-Progress}"
  local width=30
  local pct=$(( current * 100 / total ))
  local filled=$(( current * width / total ))
  local empty=$(( width - filled ))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++));  do bar+="░"; done
  echo -ne "\r  ${CYAN}${label}${NC} [${GREEN}${bar}${NC}] ${pct}%  "
  [[ $current -eq $total ]] && echo ""
}

# Usage: spinner_start "message" → returns PID, kill when done
spinner_msg=""
spinner_run() {
  local msg="$1"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  while true; do
    echo -ne "\r  ${CYAN}${frames[$((i % 10))]}${NC} ${msg}..."
    sleep 0.1
    ((i++))
  done
}

spinner_start() {
  spinner_run "$1" &
  SPINNER_PID=$!
}

spinner_stop() {
  [[ -n "$SPINNER_PID" ]] && kill "$SPINNER_PID" 2>/dev/null && wait "$SPINNER_PID" 2>/dev/null
  echo -ne "\r  ${GREEN}✓${NC} ${1:-Done}              \n"
  SPINNER_PID=""
}

export -f progress_bar spinner_run spinner_start spinner_stop
