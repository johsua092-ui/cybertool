#!/bin/bash
# modules/network.sh

network_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🌐 Network Scanning & Recon${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Nmap — Quick Scan (top 1000 port)"
    echo -e "  ${GREEN}[2]${NC} Nmap — Service & Version Detection"
    echo -e "  ${GREEN}[3]${NC} Nmap — Full Scan (semua 65535 port)"
    echo -e "  ${GREEN}[4]${NC} Nmap — Vuln Script Scan"
    echo -e "  ${GREEN}[5]${NC} Whois Lookup"
    echo -e "  ${GREEN}[6]${NC} DNS Lookup lengkap (A/MX/NS/TXT)"
    echo -e "  ${GREEN}[7]${NC} Traceroute"
    echo -e "  ${GREEN}[8]${NC} Ping Sweep — Host discovery di subnet"
    echo -e "  ${GREEN}[9]${NC} Netcat — Port check manual"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1)
        check_tool nmap || continue
        get_target || continue
        section "Nmap Quick Scan → $TARGET"
        nmap -T4 "$TARGET"
        pause ;;
      2)
        check_tool nmap || continue
        get_target || continue
        section "Service Detection → $TARGET"
        nmap -sV -T4 "$TARGET"
        pause ;;
      3)
        check_tool nmap || continue
        get_target || continue
        warn "Full scan butuh waktu lama..."
        section "Full Port Scan → $TARGET"
        nmap -p- -T4 --open "$TARGET"
        pause ;;
      4)
        check_tool nmap || continue
        get_target || continue
        warn "Vuln scan butuh waktu lebih lama..."
        section "Vuln Script Scan → $TARGET"
        nmap -sV --script vuln "$TARGET"
        pause ;;
      5)
        check_tool whois || continue
        get_target || continue
        section "Whois → $TARGET"
        whois "$TARGET" | grep -Ev "^#|^%" | grep -v "^$" | head -60
        pause ;;
      6)
        check_tool dig || continue
        echo -ne "${WHITE}  Domain${NC}: "
        read -r domain
        [[ -z "$domain" ]] && { err "Domain kosong!"; continue; }
        section "DNS Lookup → $domain"
        echo -e "${CYAN}  A Record:${NC}"
        dig +short A "$domain"
        echo -e "${CYAN}  AAAA Record:${NC}"
        dig +short AAAA "$domain"
        echo -e "${CYAN}  MX Record:${NC}"
        dig +short MX "$domain"
        echo -e "${CYAN}  NS Record:${NC}"
        dig +short NS "$domain"
        echo -e "${CYAN}  TXT Record:${NC}"
        dig +short TXT "$domain"
        echo -e "${CYAN}  CNAME Record:${NC}"
        dig +short CNAME "$domain"
        pause ;;
      7)
        check_tool traceroute || continue
        get_target || continue
        section "Traceroute → $TARGET"
        traceroute "$TARGET"
        pause ;;
      8)
        check_tool nmap || continue
        echo -ne "${WHITE}  Subnet${NC} (contoh 192.168.1.0/24): "
        read -r subnet
        [[ -z "$subnet" ]] && { err "Subnet kosong!"; continue; }
        section "Ping Sweep → $subnet"
        nmap -sn "$subnet" | grep -E "report|latency"
        pause ;;
      9)
        check_tool nc || continue
        get_target || continue
        echo -ne "${WHITE}  Port${NC}: "
        read -r port
        info "Testing $TARGET:$port ..."
        if nc -z -w3 "$TARGET" "$port" 2>/dev/null; then
          ok "Port $port OPEN di $TARGET"
        else
          err "Port $port CLOSED / filtered"
        fi
        pause ;;
      0) break ;;
      *) err "Pilihan tidak valid!"; sleep 1 ;;
    esac
  done
}
