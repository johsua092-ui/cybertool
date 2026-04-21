#!/bin/bash
# ================================================
#   install.sh — Setup CyberTool di Termux
# ================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}"
echo " ██████╗██╗   ██╗██████╗ ███████╗██████╗ "
echo "██╔════╝╚██╗ ██╔╝██╔══██╗██╔════╝██╔══██╗"
echo "██║      ╚████╔╝ ██████╔╝█████╗  ██████╔╝"
echo "██║       ╚██╔╝  ██╔══██╗██╔══╝  ██╔══██╗"
echo "╚██████╗   ██║   ██████╔╝███████╗██║  ██║"
echo " ╚═════╝   ╚═╝   ╚═════╝ ╚══════╝╚═╝  ╚═╝"
echo -e "${NC}${YELLOW}           Installer v3.0${NC}"
echo ""

step() { echo -e "${GREEN}[$1/$2]${NC} $3"; }
ok()   { echo -e "  ${GREEN}+${NC} $*"; }
warn() { echo -e "  ${YELLOW}!${NC} $*"; }
err()  { echo -e "  ${RED}-${NC} $*"; }

step 1 6 "Update package list..."
pkg update -y 2>/dev/null
echo ""

step 2 6 "Install Python (wajib)..."
pkg install -y python 2>/dev/null
# verifikasi
if command -v python3 &>/dev/null; then
  ok "python3 OK: $(python3 --version)"
else
  err "python3 gagal install. Coba manual: pkg install python"
fi
echo ""

step 3 6 "Install core tools..."
pkg install -y \
  nmap whois dnsutils traceroute \
  netcat-openbsd curl git \
  binwalk exiftool john hydra \
  nikto gobuster openssh 2>/dev/null
echo ""

step 4 6 "Install Python packages..."
pip install --quiet --upgrade pip 2>/dev/null
pip install --quiet sqlmap requests beautifulsoup4 2>/dev/null
ok "sqlmap, requests, beautifulsoup4"
echo ""

step 5 6 "Install Termux:API (opsional)..."
pkg install -y termux-api 2>/dev/null
ok "termux-api"
warn "Kalau mau WiFi/BT scan: install juga app Termux:API dari F-Droid"
echo ""

step 6 6 "Set permission..."
chmod +x cybertool.sh
ok "cybertool.sh siap"
echo ""

# verifikasi final
echo -e "${CYAN}${BOLD}── Verifikasi Instalasi ──${NC}"
for tool in python3 nmap curl git john hydra nikto gobuster ssh; do
  if command -v "$tool" &>/dev/null; then
    echo -e "  ${GREEN}+${NC} $tool"
  else
    echo -e "  ${YELLOW}!${NC} $tool — tidak ditemukan (opsional)"
  fi
done

echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  OK  Instalasi selesai!${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Jalankan dengan:"
echo -e "  ${CYAN}${BOLD}bash cybertool.sh${NC}"
echo ""
