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
ok()   { echo -e "  ${GREEN}✓${NC} $*"; }
warn() { echo -e "  ${YELLOW}!${NC} $*"; }

step 1 5 "Update package list..."
pkg update -y && pkg upgrade -y
echo ""

step 2 5 "Install core tools..."
pkg install -y \
  nmap whois dnsutils traceroute \
  netcat-openbsd curl git python \
  binwalk exiftool john hydra \
  nikto gobuster openssh
echo ""

step 3 5 "Install Python packages..."
pip install --quiet --upgrade pip 2>/dev/null
pip install --quiet sqlmap requests beautifulsoup4 2>/dev/null
ok "sqlmap, requests, beautifulsoup4"
echo ""

step 4 5 "Install Termux:API (opsional — WiFi & BT scan)..."
pkg install -y termux-api 2>/dev/null
ok "termux-api"
warn "Kalau mau WiFi/BT scan: install juga app Termux:API dari F-Droid"
echo ""

step 5 5 "Set permission..."
chmod +x cybertool.sh
ok "cybertool.sh ready"
echo ""

echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ✅  Instalasi selesai!${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Jalankan dengan:"
echo -e "  ${CYAN}${BOLD}bash cybertool.sh${NC}"
echo ""
