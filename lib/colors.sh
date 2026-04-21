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
  echo ""
}

pause() {
  echo ""
  echo -e "${DIM}  Tekan Enter untuk kembali...${NC}"
  read -r _
}

info()    { echo -e "${CYAN}[*]${NC} $*"; }
ok()      { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
err()     { echo -e "${RED}[-]${NC} $*"; }
section() { echo -e "\n${BLUE}${BOLD}── $* ──${NC}\n"; }

check_tool() {
  if ! command -v "$1" &>/dev/null; then
    err "'$1' belum terinstall."
    warn "Jalankan ${CYAN}bash install.sh${NC} dulu."
    pause
    return 1
  fi
  return 0
}

get_target() {
  echo -ne "${WHITE}  Target${NC} (IP/domain): "
  read -r TARGET
  [[ -z "$TARGET" ]] && { err "Target kosong!"; return 1; }
  return 0
}

export -f banner pause info ok warn err section check_tool get_target
