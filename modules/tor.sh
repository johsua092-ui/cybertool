#!/bin/bash
# modules/tor.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

tor_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🌍 Tor / Proxy Setup${NC}"
    echo ""
    echo -e "  ${YELLOW}── Tor ──${NC}"
    echo -e "  ${GREEN}[1]${NC} Install & start Tor"
    echo -e "  ${GREEN}[2]${NC} Cek status Tor"
    echo -e "  ${GREEN}[3]${NC} Test koneksi via Tor"
    echo -e "  ${GREEN}[4]${NC} Stop Tor"
    echo -e "  ${GREEN}[5]${NC} Ganti exit node (new identity)"
    echo ""
    echo -e "  ${YELLOW}── Proxy ──${NC}"
    echo -e "  ${GREEN}[6]${NC} Set proxy untuk curl/wget"
    echo -e "  ${GREEN}[7]${NC} Cek IP publik lo sekarang"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Tor routing hanya untuk Termux, bukan seluruh HP${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) tor_install  ;;
      2) tor_status   ;;
      3) tor_test     ;;
      4) tor_stop     ;;
      5) tor_newident ;;
      6) proxy_set    ;;
      7) check_ip     ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

tor_install() {
  section "Install & Start Tor"
  if ! command -v tor &>/dev/null; then
    info "Install tor..."
    pkg install -y tor
  fi
  if command -v tor &>/dev/null; then
    ok "Tor terinstall: $(tor --version 2>/dev/null | head -1)"
    info "Starting Tor..."
    tor &>/dev/null &
    TOR_PID=$!
    # tunggu Tor bootstrap
    for i in $(seq 1 30); do
      progress_bar $i 30 "Bootstrapping"
      sleep 1
      if netstat -tlnp 2>/dev/null | grep -q ":9050\|:9150" || \
         ss -tlnp 2>/dev/null | grep -q ":9050\|:9150"; then
        echo ""
        ok "Tor aktif di port 9050 (SOCKS5)"
        break
      fi
    done
    echo ""
    info "Gunakan proxy: ${CYAN}socks5://127.0.0.1:9050${NC}"
    info "Test: ${CYAN}curl --socks5 127.0.0.1:9050 https://check.torproject.org/api/ip${NC}"
  else
    err "Gagal install Tor"
  fi
  pause
}

tor_status() {
  section "Status Tor"
  if pgrep tor &>/dev/null; then
    ok "Tor sedang berjalan (PID: $(pgrep tor))"
    if ss -tlnp 2>/dev/null | grep -q ":9050"; then
      ok "SOCKS5 proxy aktif di port 9050"
    fi
  else
    warn "Tor tidak berjalan"
    info "Jalankan menu [1] untuk start Tor"
  fi
  pause
}

tor_test() {
  section "Test Koneksi Tor"
  if ! pgrep tor &>/dev/null; then
    err "Tor tidak berjalan. Start dulu di menu [1]."
    pause; return
  fi
  spinner_start "Testing via Tor"
  RESULT=$(curl -s --socks5 127.0.0.1:9050 \
    --max-time 30 \
    https://check.torproject.org/api/ip 2>/dev/null)
  spinner_stop "Done"

  if [[ -n "$RESULT" ]]; then
    python3 -c "
import json, sys
d = json.loads('$RESULT')
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
is_tor = d.get('IsTor', False)
ip     = d.get('IP','?')
print(f'  IP via Tor : {CYAN}{ip}{NC}')
if is_tor:
    print(f'  Status     : {GREEN}✓ Terhubung via Tor network{NC}')
else:
    print(f'  Status     : {RED}✗ TIDAK melalui Tor{NC}')
" 2>/dev/null || echo -e "  Result: $RESULT"
  else
    err "Tidak bisa konek via Tor. Cek koneksi internet."
  fi

  # bandingkan IP asli
  echo ""
  REAL_IP=$(curl -s --max-time 10 https://api.ipify.org 2>/dev/null || echo "?")
  info "IP asli lo: ${CYAN}$REAL_IP${NC}"
  pause
}

tor_stop() {
  section "Stop Tor"
  if pgrep tor &>/dev/null; then
    pkill tor
    ok "Tor dihentikan"
  else
    warn "Tor tidak sedang berjalan"
  fi
  pause
}

tor_newident() {
  section "New Tor Identity"
  if ! pgrep tor &>/dev/null; then
    err "Tor tidak berjalan."
    pause; return
  fi
  # kirim NEWNYM signal via control port
  if command -v nc &>/dev/null; then
    echo -e "AUTHENTICATE\r\nSIGNAL NEWNYM\r\nQUIT" | \
      nc 127.0.0.1 9051 2>/dev/null | head -5
    ok "New identity diminta. Tunggu ~10 detik."
  else
    # fallback: restart tor
    pkill tor; sleep 2
    tor &>/dev/null &
    ok "Tor direstart dengan identity baru"
  fi
  pause
}

proxy_set() {
  section "Setup Proxy"
  echo -e "  ${CYAN}Format proxy:${NC} protocol://host:port"
  echo -e "  ${DIM}Contoh: socks5://127.0.0.1:9050${NC}"
  echo -e "  ${DIM}        http://proxy.example.com:8080${NC}\n"
  echo -ne "${WHITE}  Proxy${NC}: "
  read -r proxy
  [[ -z "$proxy" ]] && { err "Kosong!"; pause; return; }

  # export untuk sesi ini
  export http_proxy="$proxy"
  export https_proxy="$proxy"
  export ALL_PROXY="$proxy"

  ok "Proxy diset: ${CYAN}$proxy${NC}"
  info "Berlaku untuk curl, wget, dan tools lain di sesi ini"
  info "Test: curl https://api.ipify.org"

  echo -ne "\n${WHITE}  Test sekarang? [y/N]${NC}: "
  read -r yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    spinner_start "Testing proxy"
    IP=$(curl -s --proxy "$proxy" --max-time 15 https://api.ipify.org 2>/dev/null)
    spinner_stop "Done"
    if [[ -n "$IP" ]]; then
      ok "IP via proxy: ${CYAN}$IP${NC}"
    else
      err "Proxy tidak bisa konek"
    fi
  fi
  pause
}

check_ip() {
  section "IP Publik Lo"
  spinner_start "Checking"
  python3 -c "
import urllib.request, json, ssl
ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=0
GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
try:
    req=urllib.request.Request('http://ip-api.com/json/',
        headers={'User-Agent':'Mozilla/5.0'})
    d=json.loads(urllib.request.urlopen(req,timeout=8,context=ctx).read())
    print(f'  IP       : {GREEN}{d.get(\"query\")}{NC}')
    print(f'  Negara   : {d.get(\"country\")} [{d.get(\"countryCode\")}]')
    print(f'  Kota     : {d.get(\"city\")}')
    print(f'  ISP      : {d.get(\"isp\")}')
    print(f'  Proxy    : {\"Ya\" if d.get(\"proxy\") else \"Tidak\"}')
except Exception as e:
    print(f'  Error: {e}')
" 2>/dev/null
  spinner_stop "Done"
  pause
}
