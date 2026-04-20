#!/bin/bash
# modules/webapp.sh

webapp_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🕸️  Web App Testing${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Nikto — Web vulnerability scanner"
    echo -e "  ${GREEN}[2]${NC} SQLMap — SQL injection (basic)"
    echo -e "  ${GREEN}[3]${NC} SQLMap — SQL injection (aggressive)"
    echo -e "  ${GREEN}[4]${NC} Gobuster — Directory bruteforce"
    echo -e "  ${GREEN}[5]${NC} Gobuster — Subdomain enumeration"
    echo -e "  ${GREEN}[6]${NC} Curl — HTTP header inspect"
    echo -e "  ${GREEN}[7]${NC} Curl — Manual GET/POST request"
    echo -e "  ${GREEN}[8]${NC} Web tech fingerprint (curl-based)"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1)
        check_tool nikto || continue
        echo -ne "${WHITE}  Target URL${NC} (contoh http://site.com): "
        read -r url
        [[ -z "$url" ]] && { err "URL kosong!"; continue; }
        section "Nikto → $url"
        nikto -h "$url"
        pause ;;
      2)
        check_tool sqlmap || continue
        echo -ne "${WHITE}  Target URL${NC} (contoh http://site.com/page?id=1): "
        read -r url
        [[ -z "$url" ]] && { err "URL kosong!"; continue; }
        section "SQLMap Basic → $url"
        sqlmap -u "$url" --batch --level=1 --risk=1
        pause ;;
      3)
        check_tool sqlmap || continue
        echo -ne "${WHITE}  Target URL${NC}: "
        read -r url
        [[ -z "$url" ]] && { err "URL kosong!"; continue; }
        warn "Mode aggressive — lebih lama & noisy"
        section "SQLMap Aggressive → $url"
        sqlmap -u "$url" --batch --level=3 --risk=2 --dbs
        pause ;;
      4)
        check_tool gobuster || continue
        echo -ne "${WHITE}  Target URL${NC} (contoh http://site.com): "
        read -r url
        [[ -z "$url" ]] && { err "URL kosong!"; continue; }
        # cek wordlist umum
        WORDLIST=""
        for w in \
          "$HOME/../usr/share/wordlists/dirb/common.txt" \
          "/usr/share/wordlists/dirb/common.txt" \
          "$HOME/wordlists/common.txt"; do
          [[ -f "$w" ]] && WORDLIST="$w" && break
        done
        if [[ -z "$WORDLIST" ]]; then
          warn "Wordlist default tidak ditemukan."
          echo -ne "${WHITE}  Path wordlist${NC}: "
          read -r WORDLIST
          [[ ! -f "$WORDLIST" ]] && { err "File tidak ada!"; continue; }
        fi
        section "Gobuster Dir → $url"
        gobuster dir -u "$url" -w "$WORDLIST" -t 20 --no-error
        pause ;;
      5)
        check_tool gobuster || continue
        echo -ne "${WHITE}  Domain${NC} (contoh example.com): "
        read -r domain
        [[ -z "$domain" ]] && { err "Domain kosong!"; continue; }
        WORDLIST=""
        for w in \
          "$HOME/../usr/share/wordlists/dns/subdomains-top1million-5000.txt" \
          "$HOME/wordlists/subdomains.txt"; do
          [[ -f "$w" ]] && WORDLIST="$w" && break
        done
        if [[ -z "$WORDLIST" ]]; then
          warn "Wordlist subdomain tidak ditemukan."
          echo -ne "${WHITE}  Path wordlist${NC}: "
          read -r WORDLIST
          [[ ! -f "$WORDLIST" ]] && { err "File tidak ada!"; continue; }
        fi
        section "Gobuster DNS → $domain"
        gobuster dns -d "$domain" -w "$WORDLIST" -t 20
        pause ;;
      6)
        echo -ne "${WHITE}  URL${NC}: "
        read -r url
        [[ -z "$url" ]] && { err "URL kosong!"; continue; }
        section "HTTP Headers → $url"
        curl -sI "$url" | while IFS=: read -r key val; do
          [[ -n "$key" ]] && echo -e "  ${CYAN}${key}${NC}:${val}"
        done
        pause ;;
      7)
        echo -ne "${WHITE}  Method${NC} [GET/POST]: "
        read -r method
        method=${method^^}
        echo -ne "${WHITE}  URL${NC}: "
        read -r url
        [[ -z "$url" ]] && { err "URL kosong!"; continue; }
        if [[ "$method" == "POST" ]]; then
          echo -ne "${WHITE}  Data${NC} (key=val&key2=val2): "
          read -r data
          section "POST → $url"
          curl -s -X POST -d "$data" "$url" -v 2>&1 | head -80
        else
          section "GET → $url"
          curl -s -X GET "$url" -v 2>&1 | head -80
        fi
        pause ;;
      8)
        echo -ne "${WHITE}  URL${NC}: "
        read -r url
        [[ -z "$url" ]] && { err "URL kosong!"; continue; }
        section "Tech Fingerprint → $url"
        HEADERS=$(curl -sI "$url" 2>/dev/null)
        echo -e "${CYAN}  Server:${NC}      $(echo "$HEADERS" | grep -i "^server:" | cut -d: -f2-)"
        echo -e "${CYAN}  Powered-By:${NC}  $(echo "$HEADERS" | grep -i "x-powered-by" | cut -d: -f2-)"
        echo -e "${CYAN}  Content-Type:${NC}$(echo "$HEADERS" | grep -i "content-type" | cut -d: -f2-)"
        echo -e "${CYAN}  Cookies:${NC}     $(echo "$HEADERS" | grep -i "set-cookie" | cut -d: -f2- | head -3)"
        echo ""
        info "Mengecek teknologi umum dari konten..."
        BODY=$(curl -sL "$url" --max-time 10 2>/dev/null | head -200)
        grep -qi "wordpress" <<< "$BODY"   && ok "WordPress terdeteksi"
        grep -qi "joomla"    <<< "$BODY"   && ok "Joomla terdeteksi"
        grep -qi "drupal"    <<< "$BODY"   && ok "Drupal terdeteksi"
        grep -qi "react"     <<< "$BODY"   && ok "React.js terdeteksi"
        grep -qi "angular"   <<< "$BODY"   && ok "Angular terdeteksi"
        grep -qi "vue"       <<< "$BODY"   && ok "Vue.js terdeteksi"
        grep -qi "bootstrap" <<< "$BODY"   && ok "Bootstrap terdeteksi"
        grep -qi "jquery"    <<< "$BODY"   && ok "jQuery terdeteksi"
        grep -qi "laravel"   <<< "$BODY"   && ok "Laravel terdeteksi"
        grep -qi "django"    <<< "$BODY"   && ok "Django terdeteksi"
        pause ;;
      0) break ;;
      *) err "Pilihan tidak valid!"; sleep 1 ;;
    esac
  done
}
