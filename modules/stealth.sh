#!/bin/bash
# modules/stealth.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

stealth_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🔏 Stealth Scanner${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Stealth port scan (slow & silent)"
    echo -e "  ${GREEN}[2]${NC} Fragmented scan (bypass firewall)"
    echo -e "  ${GREEN}[3]${NC} Decoy scan (pake IP palsu)"
    echo -e "  ${GREEN}[4]${NC} Idle scan (completely invisible)"
    echo -e "  ${GREEN}[5]${NC} OS detection stealth"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Scan pelan & tersembunyi, sulit dideteksi IDS${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) stealth_slow     ;;
      2) stealth_frag     ;;
      3) stealth_decoy    ;;
      4) stealth_idle     ;;
      5) stealth_os       ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

stealth_slow() {
  section "Stealth Slow Scan"
  check_tool nmap || return
  echo -ne "${WHITE}  Target${NC}: "; read -r target
  [[ -z "$target" ]] && { err "Kosong!"; pause; return; }
  echo -ne "${WHITE}  Delay antar probe (ms, default 500)${NC}: "
  read -r delay; delay=${delay:-500}
  info "Scanning $target dengan stealth mode...\n"
  warn "Scan lambat & pelan — sulit terdeteksi IDS\n"
  # -sS SYN scan, -T1 paranoid timing, --scan-delay delay antar probe
  nmap -sS -T1 --scan-delay "${delay}ms" \
       --max-retries 1 \
       -p 21,22,23,25,53,80,110,143,443,445,3306,3389,8080,8443 \
       "$target" 2>/dev/null
  pause
}

stealth_frag() {
  section "Fragmented Scan (Bypass Firewall)"
  check_tool nmap || return
  echo -ne "${WHITE}  Target${NC}: "; read -r target
  [[ -z "$target" ]] && { err "Kosong!"; pause; return; }
  info "Mengirim fragmented packets ke $target...\n"
  warn "Fragment membingungkan firewall yang ga bisa reassemble\n"
  # -f fragmen packet, -D decoy
  nmap -sS -f -T2 \
       -p 22,80,443,8080,8443,3306 \
       "$target" 2>/dev/null
  pause
}

stealth_decoy() {
  section "Decoy Scan"
  check_tool nmap || return
  echo -ne "${WHITE}  Target${NC}: "; read -r target
  [[ -z "$target" ]] && { err "Kosong!"; pause; return; }
  info "Scan dengan IP decoy — target lihat banyak sumber sekaligus\n"
  warn "IP asli lo tersembunyi di antara decoy IPs\n"
  # Generate random decoy IPs
  DECOYS=$(python3 -c "
import random
ips = [f'{random.randint(1,254)}.{random.randint(1,254)}.{random.randint(1,254)}.{random.randint(1,254)}'
       for _ in range(5)]
print(','.join(ips) + ',ME')
" 2>/dev/null)
  info "Decoy IPs: ${DIM}$DECOYS${NC}\n"
  nmap -sS -D "$DECOYS" -T2 \
       -p 22,80,443,8080,3306 \
       "$target" 2>/dev/null
  pause
}

stealth_idle() {
  section "Idle / Zombie Scan"
  check_tool nmap || return
  info "Idle scan menggunakan 'zombie' host sebagai perantara"
  info "IP asli lo TIDAK muncul sama sekali di target\n"
  echo -ne "${WHITE}  Target${NC}: "; read -r target
  [[ -z "$target" ]] && { err "Kosong!"; pause; return; }
  echo -ne "${WHITE}  Zombie host IP${NC} (idle host di jaringan): "; read -r zombie
  [[ -z "$zombie" ]] && { err "Kosong!"; pause; return; }
  info "Scanning $target via zombie $zombie...\n"
  nmap -sI "$zombie" -p 22,80,443 "$target" 2>/dev/null
  pause
}

stealth_os() {
  section "Stealth OS Detection"
  check_tool nmap || return
  echo -ne "${WHITE}  Target${NC}: "; read -r target
  [[ -z "$target" ]] && { err "Kosong!"; pause; return; }
  info "Detect OS tanpa full port scan...\n"
  nmap -O --osscan-limit --osscan-guess -T2 "$target" 2>/dev/null | \
    grep -E "OS:|Running:|OS CPE:|Aggressive OS"
  pause
}
