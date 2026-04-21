#!/bin/bash
# modules/surfacemap.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

surfacemap_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🗺️  Attack Surface Mapper${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Map target lengkap"
    echo -e "  ${GREEN}[2]${NC} Export map ke file"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Visualisasi ASCII semua asset: IP, port, subdomain, tech${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) surface_map    ;;
      2) surface_export ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

surface_map() {
  banner
  echo -e "${CYAN}${BOLD}  🗺️  Attack Surface Mapper${NC}\n"
  echo -ne "${WHITE}  Target domain${NC}: "
  read -r TARGET
  [[ -z "$TARGET" ]] && { err "Kosong!"; pause; return; }

  echo ""
  info "Collecting data untuk $TARGET...\n"

  # collect data
  spinner_start "DNS lookup"
  IP=$(dig +short A "$TARGET" 2>/dev/null | head -3)
  MX=$(dig +short MX "$TARGET" 2>/dev/null | head -3)
  NS=$(dig +short NS "$TARGET" 2>/dev/null | head -3)
  spinner_stop "DNS"

  spinner_start "Port scan"
  if command -v nmap &>/dev/null; then
    PORTS=$(nmap -T4 --top-ports 50 "$TARGET" 2>/dev/null | grep "open" | grep "^[0-9]")
  else
    PORTS=""
    for p in 21 22 25 53 80 443 3306 8080; do
      nc -z -w2 "$TARGET" "$p" 2>/dev/null && PORTS+="${p}/tcp  open"$'\n'
    done
  fi
  spinner_stop "Ports"

  spinner_start "Subdomain enum"
  SUBS=$(python3 -c "
import urllib.request, json, ssl, re
ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=0
try:
    req=urllib.request.Request(f'https://crt.sh/?q=%.${TARGET}&output=json',
        headers={'User-Agent':'Mozilla/5.0'})
    data=json.loads(urllib.request.urlopen(req,timeout=10,context=ctx).read())
    subs=sorted(set(n.strip().lstrip('*.') for e in data
                    for n in e.get('name_value','').split('\n')
                    if n.endswith('.${TARGET}') and n!='.${TARGET}'))[:20]
    print('\n'.join(subs))
except: pass
" 2>/dev/null)
  spinner_stop "Subdomains"

  spinner_start "Tech fingerprint"
  SERVER=$(curl -sI "https://$TARGET" --max-time 6 2>/dev/null | grep -i "^server:" | cut -d: -f2 | xargs)
  POWERED=$(curl -sI "https://$TARGET" --max-time 6 2>/dev/null | grep -i "x-powered-by" | cut -d: -f2 | xargs)
  spinner_stop "Tech"

  # ── Render ASCII Map ──────────────────────────
  clear
  echo -e "${CYAN}${BOLD}"
  echo "  ╔══════════════════════════════════════════════════╗"
  echo "  ║     ATTACK SURFACE MAP                           ║"
  printf "  ║     Target: %-37s║\n" "$TARGET"
  printf "  ║     Generated: %-33s║\n" "$(date '+%Y-%m-%d %H:%M')"
  echo "  ╚══════════════════════════════════════════════════╝"
  echo -e "${NC}"

  # Domain node
  echo -e "  ${WHITE}${BOLD}[$TARGET]${NC}"
  echo -e "  │"

  # IPs
  if [[ -n "$IP" ]]; then
    echo -e "  ├── ${CYAN}IP Addresses${NC}"
    while IFS= read -r ip; do
      [[ -z "$ip" ]] && continue
      GEO=$(curl -s "http://ip-api.com/json/$ip?fields=country,city,isp" --max-time 4 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(f'{d.get(\"city\",\"\")}, {d.get(\"country\",\"\")}')" 2>/dev/null)
      echo -e "  │   ├── ${GREEN}$ip${NC}  ${DIM}$GEO${NC}"
    done <<< "$IP"
    echo -e "  │"
  fi

  # Open ports
  if [[ -n "$PORTS" ]]; then
    echo -e "  ├── ${YELLOW}Open Ports${NC}"
    while IFS= read -r port; do
      [[ -z "$port" ]] && continue
      PORT_NUM=$(echo "$port" | awk '{print $1}')
      SERVICE=$(echo "$port" | awk '{print $3}')
      echo -e "  │   ├── ${YELLOW}$PORT_NUM${NC}  ${DIM}$SERVICE${NC}"
    done <<< "$PORTS"
    echo -e "  │"
  fi

  # Tech stack
  if [[ -n "$SERVER" || -n "$POWERED" ]]; then
    echo -e "  ├── ${MAGENTA}Tech Stack${NC}"
    [[ -n "$SERVER" ]]  && echo -e "  │   ├── ${MAGENTA}Server:${NC} $SERVER"
    [[ -n "$POWERED" ]] && echo -e "  │   ├── ${MAGENTA}Framework:${NC} $POWERED"
    echo -e "  │"
  fi

  # Subdomains
  if [[ -n "$SUBS" ]]; then
    SUB_COUNT=$(echo "$SUBS" | wc -l)
    echo -e "  ├── ${RED}Subdomains ($SUB_COUNT)${NC}"
    while IFS= read -r sub; do
      [[ -z "$sub" ]] && continue
      SUB_IP=$(dig +short A "$sub" 2>/dev/null | head -1)
      echo -e "  │   ├── ${RED}$sub${NC}  ${DIM}$SUB_IP${NC}"
    done <<< "$(echo "$SUBS" | head -10)"
    [[ $SUB_COUNT -gt 10 ]] && echo -e "  │   └── ${DIM}... dan $((SUB_COUNT-10)) lainnya${NC}"
    echo -e "  │"
  fi

  # DNS
  if [[ -n "$MX" || -n "$NS" ]]; then
    echo -e "  └── ${BLUE}DNS Records${NC}"
    [[ -n "$NS" ]] && while IFS= read -r ns; do
      [[ -n "$ns" ]] && echo -e "      ├── ${BLUE}NS:${NC} $ns"
    done <<< "$NS"
    [[ -n "$MX" ]] && while IFS= read -r mx; do
      [[ -n "$mx" ]] && echo -e "      ├── ${BLUE}MX:${NC} $mx"
    done <<< "$MX"
  fi

  # save untuk export
  mkdir -p "$SCRIPT_ROOT/data/surfacemap"
  echo "$TARGET|$IP|$PORTS|$SUBS|$SERVER|$(date)" > "$SCRIPT_ROOT/data/surfacemap/last.dat"

  echo ""
  pause
}

surface_export() {
  section "Export Map"
  DAT="$SCRIPT_ROOT/data/surfacemap/last.dat"
  [[ ! -f "$DAT" ]] && { warn "Belum ada map. Jalankan menu [1] dulu."; pause; return; }
  OUTFILE="/sdcard/Download/surface_map_$(date +%Y%m%d).txt"
  cp "$DAT" "$OUTFILE" 2>/dev/null && ok "Tersimpan di $OUTFILE" || err "Gagal export"
  pause
}
