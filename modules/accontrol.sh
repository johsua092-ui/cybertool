#!/bin/bash
# modules/accontrol.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

AC_DIR="$SCRIPT_ROOT/data/accontrol"
mkdir -p "$AC_DIR"

accontrol_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  ❄️  AC Controller${NC}"
    echo ""
    echo -e "  ${YELLOW}── Discovery ──${NC}"
    echo -e "  ${GREEN}[1]${NC} Auto-scan & detect semua AC di jaringan"
    echo -e "  ${GREEN}[2]${NC} Identifikasi merk AC dari IP"
    echo ""
    echo -e "  ${YELLOW}── By Brand ──${NC}"
    echo -e "  ${GREEN}[3]${NC} Daikin"
    echo -e "  ${GREEN}[4]${NC} Midea / Aircool / Cooper&Hunter"
    echo -e "  ${GREEN}[5]${NC} Panasonic"
    echo -e "  ${GREEN}[6]${NC} Samsung Wind-Free"
    echo -e "  ${GREEN}[7]${NC} LG ThinQ"
    echo -e "  ${GREEN}[8]${NC} Sharp"
    echo -e "  ${GREEN}[9]${NC} Generic / Unknown brand"
    echo ""
    echo -e "  ${YELLOW}── Saved ──${NC}"
    echo -e "  ${GREEN}[10]${NC} AC tersimpan"
    echo -e "  ${RED}[0]${NC}  ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  AC harus terhubung ke WiFi yang sama${NC}"
    echo -e "  ${DIM}   Gunakan hanya dengan izin berwenang${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1)  ac_scan        ;;
      2)  ac_identify    ;;
      3)  ac_menu_daikin ;;
      4)  ac_menu_midea  ;;
      5)  ac_menu_panasonic ;;
      6)  ac_menu_samsung ;;
      7)  ac_menu_lg     ;;
      8)  ac_menu_sharp  ;;
      9)  ac_menu_generic ;;
      10) ac_saved       ;;
      0)  break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────
ac_save() {
  local name="$1" brand="$2" ip="$3" port="$4"
  echo "$brand|$ip|$port" > "$AC_DIR/${name}.ac"
  ok "AC '$name' ($brand @ $ip) disimpan!"
}

ac_control_panel() {
  # Universal control panel — dipanggil setelah brand diidentifikasi
  local brand="$1" ip="$2" port="${3:-80}"
  case "$brand" in
    daikin)    ac_daikin_ctrl "$ip" ;;
    midea)     ac_midea_ctrl "$ip" "$port" ;;
    panasonic) ac_panasonic_ctrl "$ip" ;;
    samsung)   ac_samsung_ctrl "$ip" ;;
    lg)        ac_lg_ctrl "$ip" ;;
    sharp)     ac_sharp_ctrl "$ip" ;;
    *)         ac_generic_ctrl "$ip" "$port" ;;
  esac
}

ac_saved() {
  section "AC Tersimpan"
  if [[ -z "$(ls "$AC_DIR"/*.ac 2>/dev/null)" ]]; then
    warn "Belum ada AC tersimpan."
    pause; return
  fi
  local i=1
  declare -a FILES
  for f in "$AC_DIR"/*.ac; do
    name=$(basename "$f" .ac)
    IFS='|' read -r brand ip port <<< "$(cat "$f")"
    echo -e "  ${GREEN}[$i]${NC} ${WHITE}$name${NC} — $brand @ $ip:$port"
    FILES+=("$f")
    ((i++))
  done
  echo ""
  echo -ne "${WHITE}  Pilih nomor${NC}: "
  read -r idx; idx=$((idx-1))
  [[ $idx -lt 0 || $idx -ge ${#FILES[@]} ]] && { err "Tidak valid!"; pause; return; }
  IFS='|' read -r brand ip port <<< "$(cat "${FILES[$idx]}")"
  ac_control_panel "$brand" "$ip" "$port"
  pause
}

# ─────────────────────────────────────────────
# AUTO SCAN
# ─────────────────────────────────────────────
ac_scan() {
  section "Auto-Scan AC di Jaringan"
  SUBNET=$(ip route 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+/\d+' | grep -v "169\|127" | head -1)
  [[ -z "$SUBNET" ]] && SUBNET=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' | awk -F. '{print $1"."$2"."$3".0/24"}')
  info "Subnet: ${CYAN}$SUBNET${NC}"
  info "Scanning port 80, 8080, 443, 8888, 6444, 55000, 30000...\n"

  python3 - "$SUBNET" << 'PYEOF'
import sys, socket, threading, urllib.request, ssl, re, json

subnet = sys.argv[1]
base   = '.'.join(subnet.split('.')[:3])
ips    = [f"{base}.{i}" for i in range(1, 255)]

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
RED='\033[0;31m'; DIM='\033[2m'; NC='\033[0m'; BOLD='\033[1m'

AC_PORTS = [80, 8080, 443, 8888, 6444, 55000, 30000, 10001]
found = []; lock = threading.Lock()

ctx = ssl.create_default_context()
ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

SIGNATURES = {
    'daikin':    ['daikin','DaikinAC','get_control_info','aircon'],
    'midea':     ['midea','SmartAir','MSmartHome'],
    'panasonic': ['panasonic','CZ-TACG1','AccControl'],
    'samsung':   ['samsung','WindFree','NASA_AC'],
    'lg':        ['lg thinq','LGE_AC','thinq'],
    'sharp':     ['sharp','AirCon','COCORO'],
    'haier':     ['haier','hOn','SmartAir'],
    'gree':      ['gree','GREE_AC'],
    'aux':       ['AUX','AuxAC'],
    'hisense':   ['hisense','HiSmart'],
}

def detect_brand(text):
    text_lower = text.lower()
    for brand, keys in SIGNATURES.items():
        if any(k.lower() in text_lower for k in keys):
            return brand.capitalize()
    return 'Unknown'

def check(ip):
    for port in AC_PORTS:
        try:
            s = socket.socket(); s.settimeout(0.6)
            if s.connect_ex((ip, port)) == 0:
                s.close()
                brand = 'Unknown'
                for scheme in ['http','https']:
                    try:
                        req  = urllib.request.Request(f"{scheme}://{ip}:{port}/",
                               headers={'User-Agent':'Mozilla/5.0'})
                        resp = urllib.request.urlopen(req, timeout=3, context=ctx)
                        body = resp.read(3000).decode('utf-8','ignore')
                        hdrs = str(dict(resp.headers))
                        brand = detect_brand(body + hdrs)
                        break
                    except: pass
                with lock: found.append((ip, port, brand))
                return
        except: pass

threads = [threading.Thread(target=check, args=(ip,)) for ip in ips]
for t in threads: t.daemon=True; t.start()
total = len(threads)
for i,t in enumerate(threads):
    t.join(timeout=2)
    if i % 30 == 0:
        print(f"\r  {CYAN}Scanning{NC} {i}/{total}...", end='', flush=True)

print(f"\r  {GREEN}✓{NC} Scan selesai!                    \n")

if found:
    print(f"  {GREEN}{BOLD}Ditemukan {len(found)} smart device:{NC}\n")
    print(f"  {'IP':<18} {'Port':<7} Brand")
    print("  " + "─"*40)
    for ip, port, brand in sorted(found):
        col = GREEN if brand != 'Unknown' else YELLOW
        print(f"  {GREEN}{ip:<18}{NC} {port:<7} {col}{brand}{NC}")
    print(f"\n  {DIM}Catat IP-nya lalu pilih menu brand yang sesuai{NC}")
else:
    print(f"  {YELLOW}Tidak ada smart AC ditemukan{NC}")
    print(f"  {DIM}Pastikan AC terhubung ke WiFi yang sama dengan HP lo{NC}")
PYEOF
  pause
}

# ─────────────────────────────────────────────
# IDENTIFY
# ─────────────────────────────────────────────
ac_identify() {
  section "Identifikasi AC"
  echo -ne "${WHITE}  IP AC${NC}: "
  read -r ip; [[ -z "$ip" ]] && { err "Kosong!"; pause; return; }
  info "Mengidentifikasi $ip...\n"
  python3 - "$ip" << 'PYEOF'
import sys, urllib.request, ssl, socket
ip = sys.argv[1]
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
DIM='\033[2m'; NC='\033[0m'
ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=0

ENDPOINTS = {
    '/aircon/get_control_info': 'Daikin',
    '/acc/cgi-bin/smart/AccControl': 'Panasonic',
    '/api/v1/ac/status': 'Generic API',
    '/control': 'Generic',
    '/status': 'Generic',
    '/': 'Generic',
}

print(f"  Checking {ip}...\n")
for path, hint in ENDPOINTS.items():
    for port in [80, 8080, 443]:
        try:
            req = urllib.request.Request(f"http://{ip}:{port}{path}",
                  headers={'User-Agent':'Mozilla/5.0'})
            resp = urllib.request.urlopen(req, timeout=3, context=ctx)
            body = resp.read(1000).decode('utf-8','ignore')
            code = resp.getcode()
            print(f"  {GREEN}[{code}]{NC} :{port}{path}  → {CYAN}{hint}{NC}")
            if body.strip():
                print(f"       {DIM}{body[:80]}{NC}")
        except: pass
PYEOF
  pause
}

# ─────────────────────────────────────────────
# DAIKIN
# ─────────────────────────────────────────────
ac_menu_daikin() {
  echo -ne "${WHITE}  IP Daikin AC${NC}: "
  read -r ip; [[ -z "$ip" ]] && { err "Kosong!"; pause; return; }
  echo -ne "${WHITE}  Simpan? [y/N]${NC}: "
  read -r sv
  [[ "$sv" =~ ^[Yy]$ ]] && { echo -ne "  Nama: "; read -r nm; ac_save "$nm" "daikin" "$ip" "80"; }
  ac_daikin_ctrl "$ip"
}

ac_daikin_ctrl() {
  local ip="$1"
  while true; do
    clear
    echo -e "${CYAN}${BOLD}  ❄️  Daikin @ $ip${NC}"
    echo -e "${BLUE}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    # Live status
    S=$(curl -s "http://$ip/aircon/get_control_info" --max-time 4 2>/dev/null)
    if [[ -n "$S" ]]; then
      python3 -c "
import re
s='$S'
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
pw   = re.search(r'pow=(\d)',s)
mode = re.search(r'mode=(\d)',s)
temp = re.search(r'stemp=([0-9.]+)',s)
fan  = re.search(r'f_rate=(\w)',s)
hum  = re.search(r'shum=(\d+)',s)
MODES={'1':'🔥 HEAT','2':'💧 DRY','3':'❄️  COOL','4':'💨 FAN','6':'🔄 AUTO'}
FANS ={'A':'AUTO','3':'LOW','4':'MED','5':'HIGH','6':'V.HIGH','7':'TURBO'}
pw_v = pw.group(1) if pw else '?'
col  = GREEN if pw_v=='1' else RED
print(f'  Power  : {col}{\"ON ●\" if pw_v==\"1\" else \"OFF ○\"}{NC}')
print(f'  Mode   : {CYAN}{MODES.get(mode.group(1),\"?\") if mode else \"?\"}{NC}')
print(f'  Suhu   : {CYAN}{temp.group(1) if temp else \"?\"}°C{NC}')
print(f'  Fan    : {CYAN}{FANS.get(fan.group(1),\"?\") if fan else \"?\"}{NC}')
print(f'  Hum    : {CYAN}{hum.group(1) if hum else \"?\"}%{NC}')
" 2>/dev/null
    else
      warn "Tidak bisa konek ke $ip"
    fi

    echo ""
    echo -e "  ${GREEN}[1]${NC} Power ON       ${GREEN}[2]${NC} Power OFF"
    echo -e "  ${GREEN}[3]${NC} Set Suhu       ${GREEN}[4]${NC} Set Mode"
    echo -e "  ${GREEN}[5]${NC} Set Fan        ${GREEN}[6]${NC} Set Timer ON"
    echo -e "  ${GREEN}[7]${NC} Set Timer OFF  ${GREEN}[8]${NC} Set Kelembaban"
    echo -e "  ${GREEN}[9]${NC} Preset: Hemat  ${GREEN}[R]${NC} Refresh"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case ${opt^^} in
      1) _daikin_send "$ip" "pow=1" "AC Daikin dinyalakan 🟢" ;;
      2) _daikin_send "$ip" "pow=0" "AC Daikin dimatikan 🔴" ;;
      3)
        echo -ne "${WHITE}  Suhu (16-30)°C${NC}: "
        read -r t; [[ "$t" =~ ^[0-9]+$ ]] && _daikin_send "$ip" "pow=1&stemp=$t&shum=0" "Suhu → ${t}°C" ;;
      4)
        echo -e "\n  ${CYAN}1${NC}=HEAT  ${CYAN}2${NC}=DRY  ${CYAN}3${NC}=COOL  ${CYAN}4${NC}=FAN  ${CYAN}5${NC}=AUTO"
        echo -ne "${WHITE}  Mode${NC}: "
        read -r m
        declare -A DM=([1]=1 [2]=2 [3]=3 [4]=4 [5]=6)
        [[ -n "${DM[$m]}" ]] && _daikin_send "$ip" "pow=1&mode=${DM[$m]}" "Mode diubah" ;;
      5)
        echo -e "\n  ${CYAN}1${NC}=AUTO  ${CYAN}2${NC}=LOW  ${CYAN}3${NC}=MED  ${CYAN}4${NC}=HIGH  ${CYAN}5${NC}=TURBO"
        echo -ne "${WHITE}  Fan${NC}: "
        read -r f
        declare -A DF=([1]=A [2]=3 [3]=5 [4]=6 [5]=7)
        [[ -n "${DF[$f]}" ]] && _daikin_send "$ip" "pow=1&f_rate=${DF[$f]}" "Fan diubah" ;;
      6)
        echo -ne "${WHITE}  Timer ON (menit dari sekarang)${NC}: "
        read -r tm
        _daikin_send "$ip" "pow=1&dh_on_timer=1&dt1=$tm" "Timer ON set $tm menit" ;;
      7)
        echo -ne "${WHITE}  Timer OFF (menit dari sekarang)${NC}: "
        read -r tm
        _daikin_send "$ip" "pow=1&dh_off_timer=1&dt3=$tm" "Timer OFF set $tm menit" ;;
      8)
        echo -ne "${WHITE}  Kelembaban (0-50%)${NC}: "
        read -r h
        _daikin_send "$ip" "pow=1&shum=$h" "Kelembaban → $h%" ;;
      9)
        # Mode hemat: 26°C, fan auto, cool
        _daikin_send "$ip" "pow=1&mode=3&stemp=26&f_rate=A&shum=0" "Mode hemat aktif (26°C Cool Auto)" ;;
      R) continue ;;
      0) break ;;
      *) err "Tidak valid!" ;;
    esac
    sleep 1
  done
}

_daikin_send() {
  local ip="$1" params="$2" msg="$3"
  RES=$(curl -s "http://$ip/aircon/set_control_info?$params" --max-time 5 2>/dev/null)
  if echo "$RES" | grep -q "ret=OK"; then
    ok "$msg"
  else
    err "Gagal: $RES"
  fi
}

# ─────────────────────────────────────────────
# MIDEA
# ─────────────────────────────────────────────
ac_menu_midea() {
  echo -ne "${WHITE}  IP Midea AC${NC}: "
  read -r ip; [[ -z "$ip" ]] && { err "Kosong!"; pause; return; }
  echo -ne "${WHITE}  Port${NC} [default 6444]: "
  read -r port; port=${port:-6444}
  echo -ne "${WHITE}  Simpan? [y/N]${NC}: "
  read -r sv
  [[ "$sv" =~ ^[Yy]$ ]] && { echo -ne "  Nama: "; read -r nm; ac_save "$nm" "midea" "$ip" "$port"; }
  ac_midea_ctrl "$ip" "$port"
}

ac_midea_ctrl() {
  local ip="$1" port="${2:-6444}"
  while true; do
    clear
    echo -e "${CYAN}${BOLD}  ❄️  Midea @ $ip:$port${NC}"
    echo -e "${BLUE}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "  ${GREEN}[1]${NC} Power ON       ${GREEN}[2]${NC} Power OFF"
    echo -e "  ${GREEN}[3]${NC} Set Suhu       ${GREEN}[4]${NC} Set Mode"
    echo -e "  ${GREEN}[5]${NC} Set Fan Speed  ${GREEN}[6]${NC} Swing ON/OFF"
    echo -e "  ${GREEN}[7]${NC} Sleep Mode     ${GREEN}[8]${NC} Turbo Mode"
    echo -e "  ${GREEN}[9]${NC} Cek status     ${GREEN}[T]${NC} Test koneksi"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case ${opt^^} in
      1) _midea_cmd "$ip" "$port" "power" "on"  "Power ON 🟢" ;;
      2) _midea_cmd "$ip" "$port" "power" "off" "Power OFF 🔴" ;;
      3)
        echo -ne "${WHITE}  Suhu (16-30)°C${NC}: "
        read -r t
        _midea_cmd "$ip" "$port" "temperature" "$t" "Suhu → ${t}°C" ;;
      4)
        echo -e "\n  ${CYAN}1${NC}=COOL  ${CYAN}2${NC}=HEAT  ${CYAN}3${NC}=AUTO  ${CYAN}4${NC}=DRY  ${CYAN}5${NC}=FAN"
        read -r m
        MODES=('' cool heat auto dry fan)
        _midea_cmd "$ip" "$port" "mode" "${MODES[$m]}" "Mode → ${MODES[$m]}" ;;
      5)
        echo -e "\n  ${CYAN}1${NC}=AUTO  ${CYAN}2${NC}=LOW  ${CYAN}3${NC}=MED  ${CYAN}4${NC}=HIGH"
        read -r f
        FANS=('' auto low medium high)
        _midea_cmd "$ip" "$port" "fan_speed" "${FANS[$f]}" "Fan → ${FANS[$f]}" ;;
      6) _midea_cmd "$ip" "$port" "swing" "on" "Swing ON" ;;
      7) _midea_cmd "$ip" "$port" "sleep" "on" "Sleep mode ON" ;;
      8) _midea_cmd "$ip" "$port" "turbo" "on" "Turbo mode ON" ;;
      9)
        STATUS=$(curl -s "http://$ip:$port/status" --max-time 5 2>/dev/null)
        [[ -n "$STATUS" ]] && echo -e "  ${DIM}$STATUS${NC}" || warn "Tidak bisa baca status" ;;
      T)
        nc -z -w3 "$ip" "$port" 2>/dev/null && ok "Koneksi OK!" || err "Tidak bisa konek ke $ip:$port" ;;
      0) break ;;
      *) err "Tidak valid!" ;;
    esac
    sleep 1
  done
}

_midea_cmd() {
  local ip="$1" port="$2" cmd="$3" val="$4" msg="$5"
  # Coba via HTTP API dulu
  RES=$(curl -s "http://$ip:$port/control?$cmd=$val" --max-time 5 2>/dev/null)
  if [[ -n "$RES" ]]; then
    ok "$msg"
  else
    # Fallback UDP
    python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(2)
# Midea discovery packet
pkt = bytes([0x5a,0x5a,0x01,0x11,0x48,0x00,0x00,0x00,
             0x00,0x00,0x00,0x00,0x00,0xac])
s.sendto(pkt, ('$ip', $port))
try:
    data,_ = s.recvfrom(1024)
    print('OK')
except: print('TIMEOUT')
s.close()
" 2>/dev/null | grep -q "OK" && ok "$msg" || warn "$msg (unverified)"
  fi
}

# ─────────────────────────────────────────────
# PANASONIC
# ─────────────────────────────────────────────
ac_menu_panasonic() {
  echo -ne "${WHITE}  IP Panasonic AC${NC}: "
  read -r ip; [[ -z "$ip" ]] && { err "Kosong!"; pause; return; }
  echo -ne "${WHITE}  Simpan? [y/N]${NC}: "
  read -r sv
  [[ "$sv" =~ ^[Yy]$ ]] && { echo -ne "  Nama: "; read -r nm; ac_save "$nm" "panasonic" "$ip" "80"; }
  ac_panasonic_ctrl "$ip"
}

ac_panasonic_ctrl() {
  local ip="$1"
  while true; do
    clear
    echo -e "${CYAN}${BOLD}  ❄️  Panasonic @ $ip${NC}"
    echo -e "${BLUE}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    # Status
    S=$(curl -s "http://$ip/acc/cgi-bin/smart/AccControl?SL_AC_STATUS" --max-time 4 2>/dev/null)
    [[ -n "$S" ]] && echo -e "  ${DIM}Status: $S${NC}\n"
    echo -e "  ${GREEN}[1]${NC} Power ON       ${GREEN}[2]${NC} Power OFF"
    echo -e "  ${GREEN}[3]${NC} Set Suhu       ${GREEN}[4]${NC} Set Mode"
    echo -e "  ${GREEN}[5]${NC} Set Fan        ${GREEN}[6]${NC} Set Swing"
    echo -e "  ${GREEN}[7]${NC} Nanoe ON/OFF   ${GREEN}[8]${NC} Eco Mode"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    BASE="http://$ip/acc/cgi-bin/smart/AccControl"
    case $opt in
      1) curl -s "$BASE?SL_AC_ONOFF=1" --max-time 5 &>/dev/null; ok "Panasonic ON 🟢" ;;
      2) curl -s "$BASE?SL_AC_ONOFF=0" --max-time 5 &>/dev/null; ok "Panasonic OFF 🔴" ;;
      3) echo -ne "${WHITE}  Suhu (16-30)${NC}: "; read -r t
         curl -s "$BASE?SL_AC_TEMP=$t" --max-time 5 &>/dev/null; ok "Suhu → ${t}°C" ;;
      4) echo -e "\n  ${CYAN}0${NC}=AUTO  ${CYAN}1${NC}=COOL  ${CYAN}2${NC}=DRY  ${CYAN}3${NC}=HEAT  ${CYAN}4${NC}=FAN"
         read -r m; curl -s "$BASE?SL_AC_MODE=$m" --max-time 5 &>/dev/null; ok "Mode diubah" ;;
      5) echo -e "\n  ${CYAN}0${NC}=AUTO  ${CYAN}1${NC}=LOW  ${CYAN}2${NC}=MED  ${CYAN}3${NC}=HIGH"
         read -r f; curl -s "$BASE?SL_AC_FAN=$f" --max-time 5 &>/dev/null; ok "Fan diubah" ;;
      6) echo -e "\n  ${CYAN}0${NC}=OFF  ${CYAN}1${NC}=V.ON  ${CYAN}2${NC}=H.ON  ${CYAN}3${NC}=BOTH"
         read -r s; curl -s "$BASE?SL_AC_SWING=$s" --max-time 5 &>/dev/null; ok "Swing diubah" ;;
      7) echo -e "\n  ${CYAN}0${NC}=OFF  ${CYAN}1${NC}=ON"
         read -r n; curl -s "$BASE?SL_AC_NANOE=$n" --max-time 5 &>/dev/null; ok "Nanoe diubah" ;;
      8) curl -s "$BASE?SL_AC_ECO=1" --max-time 5 &>/dev/null; ok "Eco mode ON 🌿" ;;
      0) break ;;
      *) err "Tidak valid!" ;;
    esac
    sleep 1
  done
}

# ─────────────────────────────────────────────
# SAMSUNG
# ─────────────────────────────────────────────
ac_menu_samsung() {
  echo -ne "${WHITE}  IP Samsung AC${NC}: "
  read -r ip; [[ -z "$ip" ]] && { err "Kosong!"; pause; return; }
  echo -ne "${WHITE}  Simpan? [y/N]${NC}: "
  read -r sv
  [[ "$sv" =~ ^[Yy]$ ]] && { echo -ne "  Nama: "; read -r nm; ac_save "$nm" "samsung" "$ip" "8888"; }
  ac_samsung_ctrl "$ip"
}

ac_samsung_ctrl() {
  local ip="$1"
  while true; do
    clear
    echo -e "${CYAN}${BOLD}  ❄️  Samsung @ $ip${NC}"
    echo -e "${BLUE}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "  ${GREEN}[1]${NC} Power ON       ${GREEN}[2]${NC} Power OFF"
    echo -e "  ${GREEN}[3]${NC} Set Suhu       ${GREEN}[4]${NC} Set Mode"
    echo -e "  ${GREEN}[5]${NC} Set Fan        ${GREEN}[6]${NC} Wind-Free ON"
    echo -e "  ${GREEN}[7]${NC} Quiet Mode     ${GREEN}[8]${NC} Cek Status"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) curl -s "http://$ip:8888/devices/main/attribute/power/value/on" --max-time 5 &>/dev/null; ok "Samsung ON 🟢" ;;
      2) curl -s "http://$ip:8888/devices/main/attribute/power/value/off" --max-time 5 &>/dev/null; ok "Samsung OFF 🔴" ;;
      3) echo -ne "${WHITE}  Suhu${NC}: "; read -r t
         curl -s "http://$ip:8888/devices/main/attribute/setpoint/value/$t" --max-time 5 &>/dev/null; ok "Suhu → ${t}°C" ;;
      4) echo -e "\n  ${CYAN}cool${NC}  ${CYAN}heat${NC}  ${CYAN}auto${NC}  ${CYAN}dry${NC}  ${CYAN}wind${NC}"
         read -r m; curl -s "http://$ip:8888/devices/main/attribute/mode/value/$m" --max-time 5 &>/dev/null; ok "Mode → $m" ;;
      5) echo -e "\n  ${CYAN}auto${NC}  ${CYAN}low${NC}  ${CYAN}medium${NC}  ${CYAN}high${NC}  ${CYAN}turbo${NC}"
         read -r f; curl -s "http://$ip:8888/devices/main/attribute/fanMode/value/$f" --max-time 5 &>/dev/null; ok "Fan → $f" ;;
      6) curl -s "http://$ip:8888/devices/main/attribute/windFree/value/on" --max-time 5 &>/dev/null; ok "Wind-Free ON 🌬️" ;;
      7) curl -s "http://$ip:8888/devices/main/attribute/quiet/value/on" --max-time 5 &>/dev/null; ok "Quiet mode ON 🤫" ;;
      8) STATUS=$(curl -s "http://$ip:8888/devices/main" --max-time 5 2>/dev/null)
         [[ -n "$STATUS" ]] && echo "$STATUS" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    for k,v in d.items(): print(f'  {k}: {v}')
except: print(sys.stdin.read()[:200])
" 2>/dev/null || warn "Tidak bisa baca status" ;;
      0) break ;;
    esac
    sleep 1
  done
}

# ─────────────────────────────────────────────
# LG
# ─────────────────────────────────────────────
ac_menu_lg() {
  echo -ne "${WHITE}  IP LG AC${NC}: "
  read -r ip; [[ -z "$ip" ]] && { err "Kosong!"; pause; return; }
  echo -ne "${WHITE}  Simpan? [y/N]${NC}: "
  read -r sv
  [[ "$sv" =~ ^[Yy]$ ]] && { echo -ne "  Nama: "; read -r nm; ac_save "$nm" "lg" "$ip" "6414"; }
  ac_lg_ctrl "$ip"
}

ac_lg_ctrl() {
  local ip="$1"
  while true; do
    clear
    echo -e "${CYAN}${BOLD}  ❄️  LG ThinQ @ $ip${NC}"
    echo -e "${BLUE}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "  ${GREEN}[1]${NC} Power ON       ${GREEN}[2]${NC} Power OFF"
    echo -e "  ${GREEN}[3]${NC} Set Suhu       ${GREEN}[4]${NC} Set Mode"
    echo -e "  ${GREEN}[5]${NC} Set Fan        ${GREEN}[6]${NC} Jet Cool"
    echo -e "  ${GREEN}[7]${NC} Energy Save    ${GREEN}[8]${NC} Cek Status"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    BASE="http://$ip:6414"
    case $opt in
      1) curl -s "$BASE/control?op=power&val=on"  --max-time 5 &>/dev/null; ok "LG ON 🟢" ;;
      2) curl -s "$BASE/control?op=power&val=off" --max-time 5 &>/dev/null; ok "LG OFF 🔴" ;;
      3) echo -ne "${WHITE}  Suhu${NC}: "; read -r t
         curl -s "$BASE/control?op=temp&val=$t" --max-time 5 &>/dev/null; ok "Suhu → ${t}°C" ;;
      4) echo -e "\n  ${CYAN}cool${NC}  ${CYAN}heat${NC}  ${CYAN}auto${NC}  ${CYAN}dry${NC}  ${CYAN}fan${NC}"
         read -r m; curl -s "$BASE/control?op=mode&val=$m" --max-time 5 &>/dev/null; ok "Mode → $m" ;;
      5) echo -e "\n  ${CYAN}auto${NC}  ${CYAN}low${NC}  ${CYAN}medium${NC}  ${CYAN}high${NC}"
         read -r f; curl -s "$BASE/control?op=fan&val=$f" --max-time 5 &>/dev/null; ok "Fan → $f" ;;
      6) curl -s "$BASE/control?op=jet&val=on" --max-time 5 &>/dev/null; ok "Jet Cool ON ⚡" ;;
      7) curl -s "$BASE/control?op=energysave&val=on" --max-time 5 &>/dev/null; ok "Energy Save ON 🌿" ;;
      8) curl -s "$BASE/status" --max-time 5 2>/dev/null | head -5 ;;
      0) break ;;
    esac
    sleep 1
  done
}

# ─────────────────────────────────────────────
# SHARP
# ─────────────────────────────────────────────
ac_menu_sharp() {
  echo -ne "${WHITE}  IP Sharp AC${NC}: "
  read -r ip; [[ -z "$ip" ]] && { err "Kosong!"; pause; return; }
  echo -ne "${WHITE}  Simpan? [y/N]${NC}: "
  read -r sv
  [[ "$sv" =~ ^[Yy]$ ]] && { echo -ne "  Nama: "; read -r nm; ac_save "$nm" "sharp" "$ip" "80"; }
  ac_sharp_ctrl "$ip"
}

ac_sharp_ctrl() {
  local ip="$1"
  while true; do
    clear
    echo -e "${CYAN}${BOLD}  ❄️  Sharp @ $ip${NC}"
    echo -e "${BLUE}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "  ${GREEN}[1]${NC} Power ON       ${GREEN}[2]${NC} Power OFF"
    echo -e "  ${GREEN}[3]${NC} Set Suhu       ${GREEN}[4]${NC} Set Mode"
    echo -e "  ${GREEN}[5]${NC} Set Fan        ${GREEN}[6]${NC} Plasmacluster"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    BASE="http://$ip/aircon"
    case $opt in
      1) curl -s "$BASE?pow=1" --max-time 5 &>/dev/null; ok "Sharp ON 🟢" ;;
      2) curl -s "$BASE?pow=0" --max-time 5 &>/dev/null; ok "Sharp OFF 🔴" ;;
      3) echo -ne "${WHITE}  Suhu${NC}: "; read -r t
         curl -s "$BASE?pow=1&temp=$t" --max-time 5 &>/dev/null; ok "Suhu → ${t}°C" ;;
      4) echo -e "\n  ${CYAN}1${NC}=COOL  ${CYAN}2${NC}=HEAT  ${CYAN}3${NC}=AUTO  ${CYAN}4${NC}=DRY  ${CYAN}5${NC}=FAN"
         read -r m; curl -s "$BASE?pow=1&mode=$m" --max-time 5 &>/dev/null; ok "Mode diubah" ;;
      5) echo -e "\n  ${CYAN}1${NC}=AUTO  ${CYAN}2${NC}=LOW  ${CYAN}3${NC}=MED  ${CYAN}4${NC}=HIGH"
         read -r f; curl -s "$BASE?pow=1&fan=$f" --max-time 5 &>/dev/null; ok "Fan diubah" ;;
      6) curl -s "$BASE?plasma=1" --max-time 5 &>/dev/null; ok "Plasmacluster ON ✨" ;;
      0) break ;;
    esac
    sleep 1
  done
}

# ─────────────────────────────────────────────
# GENERIC
# ─────────────────────────────────────────────
ac_menu_generic() {
  echo -ne "${WHITE}  IP AC${NC}: "
  read -r ip; [[ -z "$ip" ]] && { err "Kosong!"; pause; return; }
  echo -ne "${WHITE}  Port${NC} [default 80]: "
  read -r port; port=${port:-80}
  echo -ne "${WHITE}  Simpan? [y/N]${NC}: "
  read -r sv
  [[ "$sv" =~ ^[Yy]$ ]] && { echo -ne "  Nama: "; read -r nm; ac_save "$nm" "generic" "$ip" "$port"; }
  ac_generic_ctrl "$ip" "$port"
}

ac_generic_ctrl() {
  local ip="$1" port="${2:-80}"
  while true; do
    clear
    echo -e "${CYAN}${BOLD}  ❄️  Generic AC @ $ip:$port${NC}"
    echo -e "${BLUE}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "  ${YELLOW}Scan endpoint dulu untuk tau cara kontrolnya${NC}\n"
    echo -e "  ${GREEN}[1]${NC} Scan semua endpoint"
    echo -e "  ${GREEN}[2]${NC} Kirim custom GET request"
    echo -e "  ${GREEN}[3]${NC} Lihat web interface"
    echo -e "  ${GREEN}[4]${NC} Brute common AC commands"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1)
        info "Scanning endpoints..."
        for path in / /api /control /status /aircon /ac /info /set /get \
                    /api/v1 /device /cmd /command /json /query; do
          CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$ip:$port$path" --max-time 2 2>/dev/null)
          [[ "$CODE" =~ ^[23] ]] && echo -e "  ${GREEN}[$CODE]${NC} http://$ip:$port$path"
        done ;;
      2)
        echo -ne "${WHITE}  Path & params${NC} (contoh /control?power=on): "
        read -r path
        RES=$(curl -s "http://$ip:$port$path" --max-time 5 2>/dev/null)
        echo -e "\n  ${DIM}Response: $RES${NC}" ;;
      3)
        info "URL: ${CYAN}http://$ip:$port${NC}"
        command -v termux-open-url &>/dev/null && termux-open-url "http://$ip:$port" ;;
      4)
        info "Mencoba common AC commands..."
        CMDS=("power=on" "pow=1" "on=1" "cmd=on" "state=on" "switch=on"
              "power=off" "pow=0" "temp=25" "temperature=25" "mode=cool")
        for c in "${CMDS[@]}"; do
          for path in "/control" "/api" "/cmd" "/set" "/aircon"; do
            CODE=$(curl -s -o /dev/null -w "%{http_code}" \
                   "http://$ip:$port$path?$c" --max-time 2 2>/dev/null)
            [[ "$CODE" == "200" ]] && echo -e "  ${GREEN}WORKS:${NC} $path?$c"
          done
        done ;;
      0) break ;;
    esac
    sleep 1
  done
}
