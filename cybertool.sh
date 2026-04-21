#!/bin/bash
# ================================================
#   cybertool.sh — Entry point utama
#   Jalankan: bash cybertool.sh
# ================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -f "lib/colors.sh" ]]; then
  echo "ERROR: Jalankan dari folder cybertool/ !"
  echo "  cd cybertool && bash cybertool.sh"
  exit 1
fi
source lib/colors.sh

if ! command -v python3 &>/dev/null; then
  echo -e "\033[1;33m[!] python3 tidak ditemukan. Jalankan: pkg install python\033[0m"
  exit 1
fi

for mod in modules/*.sh; do
  source "$mod" 2>/dev/null
done

main_menu() {
  while true; do
    banner
    echo -e "  ${GREEN}[1]${NC}   Network Scanning & Recon"
    echo -e "  ${GREEN}[2]${NC}   Web App Testing"
    echo -e "  ${GREEN}[3]${NC}   Password & Hash Tools"
    echo -e "  ${GREEN}[4]${NC}   WiFi Scanner"
    echo -e "  ${GREEN}[5]${NC}   CTF Tools"
    echo -e "  ${GREEN}[6]${NC}   Bluetooth Scanner"
    echo -e "  ${GREEN}[7]${NC}   OSINT Tools"
    echo -e "  ${GREEN}[8]${NC}   Remote Access"
    echo -e "  ${GREEN}[9]${NC}   Network Monitor"
    echo -e "  ${GREEN}[10]${NC}  AI Security Assistant"
    echo -e "  ${GREEN}[11]${NC}  Recon Otomatis"
    echo -e "  ${GREEN}[12]${NC}  Phishing Detector"
    echo -e "  ${GREEN}[13]${NC}  APK Analyzer"
    echo -e "  ${GREEN}[14]${NC}  Ads & Tracker Blocker"
    echo -e "  ${GREEN}[15]${NC}  Signal Strength Logger"
    echo -e "  ${GREEN}[16]${NC}  Deep Paste Search"
    echo -e "  ${GREEN}[17]${NC}  URL Shortener Inspector"
    echo -e "  ${GREEN}[18]${NC}  Device Info"
    echo -e "  ${GREEN}[19]${NC}  Password Strength Checker"
    echo -e "  ${GREEN}[20]${NC}  Tor / Proxy Setup"
    echo -e "  ${GREEN}[21]${NC}  Hash Identifier Pro"
    echo -e "  ${GREEN}[22]${NC}  Port Knocking"
    echo -e "  ${GREEN}[23]${NC}  Dark Web Monitor"
    echo -e "  ${GREEN}[24]${NC}  Autonomous Recon Bot"
    echo -e "  ${GREEN}[25]${NC}  Attack Surface Mapper"
    echo -e "  ${GREEN}[26]${NC}  Firmware Analyzer"
    echo -e "  ${GREEN}[27]${NC}  Caller ID Lookup"
    echo -e "  ${GREEN}[28]${NC}  Web Crawler"
    echo ""
    echo -e "  ${RED}[0]${NC}   Exit"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r choice
    case $choice in
      1)  loading "Network";   network_menu      ;;
      2)  loading "Web App";   webapp_menu       ;;
      3)  loading "Password";  password_menu     ;;
      4)  loading "WiFi";      wifi_menu         ;;
      5)  loading "CTF";       ctf_menu          ;;
      6)  loading "Bluetooth"; bluetooth_menu    ;;
      7)  loading "OSINT";     osint_menu        ;;
      8)  loading "Remote";    remote_menu       ;;
      9)  loading "Monitor";   netmonitor_menu   ;;
      10) loading "AI";        ai_menu           ;;
      11) loading "Recon";     recon_menu        ;;
      12) loading "Phishing";  phishing_menu     ;;
      13) loading "APK";       apk_menu          ;;
      14) loading "AdBlock";   adblock_menu      ;;
      15) loading "Signal";    signal_menu       ;;
      16) loading "Paste";     pastesearch_menu  ;;
      17) loading "URL";       urlexpand_menu    ;;
      18) loading "Device";    deviceinfo_menu   ;;
      19) loading "PwStrength"; pwstrength_menu  ;;
      20) loading "Tor";       tor_menu          ;;
      21) loading "Hash";      hashpro_menu      ;;
      22) loading "Knock";     portknock_menu    ;;
      23) loading "DarkWeb";   darkweb_menu      ;;
      24) loading "ReconBot";  reconbot_menu     ;;
      25) loading "SurfaceMap"; surfacemap_menu  ;;
      26) loading "Firmware";  firmware_menu     ;;
      27) loading "CallerID";  callerid_menu     ;;
      28) loading "Crawler";   webcrawler_menu   ;;
      0)  echo -e "\n${CYAN}  Bye! Stay legal${NC}\n"; exit 0 ;;
      *)  err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

main_menu
