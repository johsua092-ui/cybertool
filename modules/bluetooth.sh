#!/bin/bash
# modules/bluetooth.sh

bluetooth_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🔵 Bluetooth Scanner${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Scan device Bluetooth sekitar"
    echo -e "  ${GREEN}[2]${NC} Scan BLE (smartwatch, earphone, sensor)"
    echo -e "  ${GREEN}[3]${NC} Info adapter Bluetooth HP lo"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Scanner only — read only, tidak ada yang dimodifikasi${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1)
        if ! command -v termux-bluetooth-scaninfo &>/dev/null; then
          err "Termux:API tidak terinstall."
          info "Install: ${CYAN}pkg install termux-api${NC}"
          info "Lalu install app ${CYAN}Termux:API${NC} dari F-Droid"
          pause; continue
        fi
        section "Bluetooth Scan"
        info "Scanning... (tunggu ~10 detik)"
        BTRAW=$(termux-bluetooth-scaninfo 2>/dev/null)
        if [[ -z "$BTRAW" || "$BTRAW" == "[]" ]]; then
          warn "Tidak ada device ditemukan."
          warn "Pastikan Bluetooth HP aktif & izin sudah diberikan."
          pause; continue
        fi
        echo "$BTRAW" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if not data:
        print('  Tidak ada device.')
        sys.exit()
    def get_type(dtype):
        types = {
            'CLASSIC':'📱 Classic BT','LE':'📡 BLE',
            'DUAL':'📱📡 Dual','UNKNOWN':'❓ Unknown'
        }
        return types.get(str(dtype).upper(), str(dtype))
    print(f\"\n  {'No':<4} {'Nama Device':<28} {'MAC Address':<20} {'Signal':>8}  {'Bar':<6} Type\")
    print('  ' + '─'*75)
    for i, d in enumerate(data, 1):
        name  = (d.get('name') or 'Unknown Device')[:27]
        mac   = d.get('address','??:??:??:??:??:??')
        rssi  = d.get('rssi', -100)
        dtype = get_type(d.get('type','?'))
        try:
            rssi_int = int(rssi)
            bar  = '█' * max(1, min(5, (rssi_int+100)//10))
            col  = '\033[0;32m' if rssi_int>-60 else '\033[1;33m' if rssi_int>-80 else '\033[0;31m'
            nc   = '\033[0m'
            sig  = f'{col}{rssi_int:>4} dBm{nc}'
        except:
            bar, sig = '?', str(rssi)
        print(f'  {i:<4} {name:<28} {mac:<20} {sig}  {bar:<6} {dtype}')
    print(f\"\n  Total: {len(data)} device terdeteksi\")
    print(\"  \033[2mSignal: hijau >-60 dekat | kuning -60~-80 | merah <-80 jauh\033[0m\")
except Exception as e:
    print(f'  Error: {e}')
" 2>/dev/null
        pause ;;
      2)
        if ! command -v termux-ble-scan &>/dev/null; then
          err "termux-ble-scan tidak tersedia di versi ini."
          info "Coba update: ${CYAN}pkg install termux-api${NC}"
          pause; continue
        fi
        section "BLE Scan (Bluetooth Low Energy)"
        info "Scanning BLE... (Ctrl+C untuk stop)"
        echo -e "\n  ${'Nama':<30} ${'MAC':<20} Signal\n  $(printf '─%.0s' {1..55})"
        termux-ble-scan 2>/dev/null | python3 -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        d = json.loads(line)
        name = (d.get('name') or 'Unknown')[:29]
        mac  = d.get('address','?')
        rssi = d.get('rssi','?')
        try:
            r = int(rssi)
            col = '\033[0;32m' if r>-60 else '\033[1;33m' if r>-80 else '\033[0;31m'
            nc  = '\033[0m'
            sig = f'{col}{r} dBm{nc}'
        except:
            sig = str(rssi)
        print(f'  {name:<30} {mac:<20} {sig}')
    except:
        pass
" 2>/dev/null || {
          warn "BLE scan tidak tersedia / timeout."
        }
        pause ;;
      3)
        section "Info Adapter Bluetooth"
        if [[ -d /sys/class/bluetooth ]]; then
          for dev in /sys/class/bluetooth/*/; do
            name=$(basename "$dev")
            addr=$(cat "$dev/address" 2>/dev/null || echo "N/A")
            ok "Interface : ${CYAN}$name${NC}"
            echo -e "  MAC       : $addr"
          done
        else
          warn "Tidak bisa baca /sys/class/bluetooth"
          info "Coba: ${CYAN}termux-bluetooth-get-adapters${NC}"
          termux-bluetooth-get-adapters 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    for k,v in d.items(): print(f'  {k:<20}: {v}')
except: print('  Info tidak tersedia')
" 2>/dev/null
        fi
        pause ;;
      0) break ;;
      *) err "Pilihan tidak valid!"; sleep 1 ;;
    esac
  done
}
