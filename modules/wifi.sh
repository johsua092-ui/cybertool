#!/bin/bash
# modules/wifi.sh

wifi_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  📡 WiFi Scanner${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Scan WiFi sekitar (SSID, signal, security)"
    echo -e "  ${GREEN}[2]${NC} Info koneksi WiFi aktif"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1)
        if ! command -v termux-wifi-scaninfo &>/dev/null; then
          err "Termux:API tidak terinstall."
          info "Install: ${CYAN}pkg install termux-api${NC}"
          info "Lalu install app ${CYAN}Termux:API${NC} dari F-Droid"
          pause; continue
        fi
        section "WiFi Scan"
        info "Scanning..."
        termux-wifi-scaninfo 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if not data:
        print('  Tidak ada jaringan ditemukan.')
        sys.exit()
    print(f\"\n  {'No':<4} {'SSID':<32} {'Signal':>8}  {'Bar':<6} {'Security':<10} {'Ch'}\")
    print('  ' + '-'*70)
    for i, n in enumerate(sorted(data, key=lambda x: -x.get('level',-100)), 1):
        ssid  = (n.get('SSID') or 'Hidden SSID')[:31]
        level = n.get('level', -100)
        caps  = n.get('capabilities','')
        freq  = n.get('frequency', 0)
        ch    = (freq-2407)//5 if 2400 < freq < 5000 else freq
        sec   = 'WPA3' if 'WPA3' in caps else 'WPA2' if 'WPA2' in caps else 'WPA' if 'WPA' in caps else 'OPEN'
        bar   = '█' * max(1, min(5, (level+100)//10))
        col   = '\033[0;32m' if level>-60 else '\033[1;33m' if level>-80 else '\033[0;31m'
        nc    = '\033[0m'
        print(f'  {i:<4} {ssid:<32} {col}{level:>5} dBm{nc}  {bar:<6}  {sec:<10} {ch}')
    print(f\"\n  Total: {len(data)} jaringan ditemukan\")
    print(\"  \033[2mSignal: hijau >-60 bagus | kuning -60~-80 | merah <-80 lemah\033[0m\")
except Exception as e:
    print(f'  Error: {e}')
    print('  Pastikan izin Lokasi sudah diberikan ke Termux:API')
" 2>/dev/null
        pause ;;
      2)
        if ! command -v termux-wifi-connectioninfo &>/dev/null; then
          err "Termux:API tidak terinstall."
          info "Install: ${CYAN}pkg install termux-api${NC}"
          pause; continue
        fi
        section "Koneksi WiFi Aktif"
        termux-wifi-connectioninfo 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    labels = {
        'ssid':'SSID', 'bssid':'BSSID (MAC AP)',
        'ip':'IP Address', 'mac':'MAC Address lo',
        'frequency':'Frequency (MHz)', 'link_speed':'Link Speed (Mbps)',
        'rssi':'Signal (RSSI)', 'hidden_ssid':'Hidden SSID'
    }
    for k,v in d.items():
        label = labels.get(k, k)
        print(f'  {label:<22}: {v}')
except Exception as e:
    print(f'  Error: {e}')
" 2>/dev/null
        pause ;;
      0) break ;;
      *) err "Pilihan tidak valid!"; sleep 1 ;;
    esac
  done
}
