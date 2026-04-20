#!/bin/bash
# modules/ai.sh — Multi-provider AI Security Assistant

AI_CONFIG_DIR="$HOME/.cybertool"
mkdir -p "$AI_CONFIG_DIR"

# ─────────────────────────────────────────
ai_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🧠 AI Security Assistant${NC}"
    echo ""

    # tampil provider aktif
    ACTIVE=$(ai_get_active_provider)
    if [[ -n "$ACTIVE" ]]; then
      echo -e "  ${DIM}Provider aktif: ${GREEN}$ACTIVE${NC}"
    else
      echo -e "  ${YELLOW}  ⚠ Belum ada provider. Setup dulu di [5]${NC}"
    fi
    echo ""

    echo -e "  ${GREEN}[1]${NC} Chat — tanya apa aja soal security"
    echo -e "  ${GREEN}[2]${NC} Analisis log / output tools"
    echo -e "  ${GREEN}[3]${NC} Explain exploit / CVE"
    echo -e "  ${GREEN}[4]${NC} Review kode — cari vulnerability"
    echo -e "  ${GREEN}[5]${NC} Setup & ganti provider / API key"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) ai_chat         ;;
      2) ai_analyze_log  ;;
      3) ai_explain_cve  ;;
      4) ai_review_code  ;;
      5) ai_setup_menu   ;;
      0) break           ;;
      *) err "Pilihan tidak valid!"; sleep 1 ;;
    esac
  done
}

# ─────────────────────────────────────────
ai_get_active_provider() {
  [[ -f "$AI_CONFIG_DIR/active" ]] && cat "$AI_CONFIG_DIR/active"
}

ai_get_key() {
  local provider="$1"
  local file="$AI_CONFIG_DIR/${provider}.key"
  [[ -f "$file" ]] && cat "$file"
}

ai_save_key() {
  local provider="$1"
  local key="$2"
  echo "$key" > "$AI_CONFIG_DIR/${provider}.key"
  chmod 600 "$AI_CONFIG_DIR/${provider}.key"
  echo "$provider" > "$AI_CONFIG_DIR/active"
}

# ─────────────────────────────────────────
ai_setup_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  ⚙️  Setup AI Provider${NC}\n"

    # status tiap provider
    for p in anthropic openai gemini groq; do
      KEY=$(ai_get_key "$p")
      ACTIVE=$(ai_get_active_provider)
      if [[ -n "$KEY" ]]; then
        STAR=""
        [[ "$ACTIVE" == "$p" ]] && STAR=" ${GREEN}← aktif${NC}"
        echo -e "  ${GREEN}✓${NC} $p${STAR}"
      else
        echo -e "  ${DIM}✗ $p — belum setup${NC}"
      fi
    done

    echo ""
    echo -e "  ${GREEN}[1]${NC} 🤖 Anthropic (Claude)     — console.anthropic.com"
    echo -e "  ${GREEN}[2]${NC} 🟢 OpenAI (GPT-4o)        — platform.openai.com"
    echo -e "  ${GREEN}[3]${NC} 💎 Google Gemini           — aistudio.google.com"
    echo -e "  ${GREEN}[4]${NC} ⚡ Groq (gratis & cepet)  — console.groq.com"
    echo -e "  ${GREEN}[5]${NC} 🔄 Ganti provider aktif"
    echo -e "  ${GREEN}[6]${NC} 🗑️  Hapus key provider"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) ai_setup_key "anthropic" "sk-ant-"       "console.anthropic.com"   ;;
      2) ai_setup_key_prompt "openai"   "sk-"     "platform.openai.com/api-keys" ;;
      3) ai_setup_key_prompt "gemini"   "AIza"    "aistudio.google.com/app/apikey" ;;
      4) ai_setup_key_prompt "groq"     "gsk_"    "console.groq.com/keys"   ;;
      5) ai_switch_provider ;;
      6) ai_delete_key      ;;
      0) break ;;
      *) err "Pilihan tidak valid!"; sleep 1 ;;
    esac
  done
}

ai_setup_key_prompt() {
  local provider="$1"
  local prefix="$2"
  local url="$3"

  section "Setup $provider"
  echo -e "  Daftar / login di: ${CYAN}$url${NC}\n"

  echo -ne "${WHITE}  Paste API key${NC}: "
  read -r key

  [[ -z "$key" ]] && { err "Key kosong!"; pause; return; }

  if [[ "$key" != ${prefix}* ]]; then
    warn "Format key sepertinya tidak sesuai (biasanya mulai '${prefix}...')"
    echo -ne "${WHITE}  Tetap simpan? [y/N]${NC}: "
    read -r yn
    [[ ! "$yn" =~ ^[Yy]$ ]] && { pause; return; }
  fi

  ai_save_key "$provider" "$key"
  info "Testing koneksi ke $provider..."

  RESPONSE=$(ai_call_provider "$provider" "$key" "Reply with exactly: OK" "You are a test." 10)
  if [[ -n "$RESPONSE" ]]; then
    ok "${BOLD}$provider berhasil!${NC} Sekarang jadi provider aktif."
  else
    err "Gagal konek ke $provider. Cek key & internet."
    rm -f "$AI_CONFIG_DIR/${provider}.key"
  fi
  pause
}

ai_switch_provider() {
  section "Ganti Provider Aktif"
  PROVIDERS=()
  for p in anthropic openai gemini groq; do
    [[ -n "$(ai_get_key "$p")" ]] && PROVIDERS+=("$p")
  done

  if [[ ${#PROVIDERS[@]} -eq 0 ]]; then
    warn "Belum ada provider yang disetup."
    pause; return
  fi

  echo -e "  Provider tersedia:\n"
  for i in "${!PROVIDERS[@]}"; do
    echo -e "  ${GREEN}[$((i+1))]${NC} ${PROVIDERS[$i]}"
  done
  echo ""
  echo -ne "${WHITE}  Pilih${NC}: "
  read -r idx
  idx=$((idx-1))
  if [[ $idx -ge 0 && $idx -lt ${#PROVIDERS[@]} ]]; then
    echo "${PROVIDERS[$idx]}" > "$AI_CONFIG_DIR/active"
    ok "Provider aktif: ${GREEN}${PROVIDERS[$idx]}${NC}"
  else
    err "Pilihan tidak valid!"
  fi
  pause
}

ai_delete_key() {
  section "Hapus API Key"
  for i in "${!arr[@]}"; do unset "arr[$i]"; done
  PROVIDERS=()
  for p in anthropic openai gemini groq; do
    [[ -n "$(ai_get_key "$p")" ]] && PROVIDERS+=("$p")
  done

  [[ ${#PROVIDERS[@]} -eq 0 ]] && { warn "Tidak ada key tersimpan."; pause; return; }

  for i in "${!PROVIDERS[@]}"; do
    echo -e "  ${GREEN}[$((i+1))]${NC} ${PROVIDERS[$i]}"
  done
  echo ""
  echo -ne "${WHITE}  Hapus provider${NC}: "
  read -r idx
  idx=$((idx-1))
  if [[ $idx -ge 0 && $idx -lt ${#PROVIDERS[@]} ]]; then
    local p="${PROVIDERS[$idx]}"
    rm -f "$AI_CONFIG_DIR/${p}.key"
    # kalau ini yang aktif, reset
    [[ "$(ai_get_active_provider)" == "$p" ]] && rm -f "$AI_CONFIG_DIR/active"
    ok "Key $p dihapus."
  else
    err "Pilihan tidak valid!"
  fi
  pause
}

# ─────────────────────────────────────────
# CORE: panggil API sesuai provider
ai_call_provider() {
  local provider="$1"
  local key="$2"
  local prompt="$3"
  local system="$4"
  local max_tokens="${5:-1024}"

  local escaped_prompt escaped_system
  escaped_prompt=$(python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" <<< "$prompt")
  escaped_system=$(python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" <<< "$system")

  case "$provider" in

    # ── Anthropic (Claude) ──────────────────
    anthropic)
      curl -s https://api.anthropic.com/v1/messages \
        -H "Content-Type: application/json" \
        -H "x-api-key: $key" \
        -H "anthropic-version: 2023-06-01" \
        -d "{
          \"model\": \"claude-haiku-4-5-20251001\",
          \"max_tokens\": $max_tokens,
          \"system\": $escaped_system,
          \"messages\": [{\"role\":\"user\",\"content\":$escaped_prompt}]
        }" 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
if 'content' in d: print(d['content'][0]['text'])
elif 'error' in d: print('ERROR:',d['error']['message'],file=sys.stderr); exit(1)
" 2>/dev/null ;;

    # ── OpenAI (GPT-4o) ────────────────────
    openai)
      curl -s https://api.openai.com/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $key" \
        -d "{
          \"model\": \"gpt-4o-mini\",
          \"max_tokens\": $max_tokens,
          \"messages\": [
            {\"role\":\"system\",\"content\":$escaped_system},
            {\"role\":\"user\",\"content\":$escaped_prompt}
          ]
        }" 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
if 'choices' in d: print(d['choices'][0]['message']['content'])
elif 'error' in d: print('ERROR:',d['error']['message'],file=sys.stderr); exit(1)
" 2>/dev/null ;;

    # ── Google Gemini ───────────────────────
    gemini)
      curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$key" \
        -H "Content-Type: application/json" \
        -d "{
          \"system_instruction\": {\"parts\":[{\"text\":$escaped_system}]},
          \"contents\": [{\"parts\":[{\"text\":$escaped_prompt}]}],
          \"generationConfig\": {\"maxOutputTokens\": $max_tokens}
        }" 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
try: print(d['candidates'][0]['content']['parts'][0]['text'])
except:
  if 'error' in d: print('ERROR:',d['error']['message'],file=sys.stderr); exit(1)
" 2>/dev/null ;;

    # ── Groq ────────────────────────────────
    groq)
      curl -s https://api.groq.com/openai/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $key" \
        -d "{
          \"model\": \"llama-3.3-70b-versatile\",
          \"max_tokens\": $max_tokens,
          \"messages\": [
            {\"role\":\"system\",\"content\":$escaped_system},
            {\"role\":\"user\",\"content\":$escaped_prompt}
          ]
        }" 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
if 'choices' in d: print(d['choices'][0]['message']['content'])
elif 'error' in d: print('ERROR:',d['error']['message'],file=sys.stderr); exit(1)
" 2>/dev/null ;;

  esac
}

# wrapper: pakai provider aktif
ai_call() {
  local prompt="$1"
  local system="$2"
  local max_tokens="${3:-1024}"

  local provider key
  provider=$(ai_get_active_provider)
  key=$(ai_get_key "$provider")

  if [[ -z "$provider" || -z "$key" ]]; then
    err "Belum ada provider aktif. Setup dulu di menu [5]."
    return 1
  fi

  ai_call_provider "$provider" "$key" "$prompt" "$system" "$max_tokens"
}

ai_check_ready() {
  local provider
  provider=$(ai_get_active_provider)
  if [[ -z "$provider" || -z "$(ai_get_key "$provider")" ]]; then
    warn "Belum ada AI provider aktif."
    info "Masuk menu ${CYAN}[5] Setup & ganti provider${NC} dulu."
    pause
    return 1
  fi
  return 0
}

# ─────────────────────────────────────────
ai_print_response() {
  local response="$1"
  local provider
  provider=$(ai_get_active_provider)
  echo ""
  echo -e "${CYAN}${BOLD}  ┌─ AI ($provider) ──────────────────────────${NC}"
  echo "$response" | while IFS= read -r line; do
    echo -e "  ${CYAN}│${NC} $line"
  done
  echo -e "${CYAN}  └─────────────────────────────────────────${NC}"
  echo ""
}

# ─────────────────────────────────────────
ai_chat() {
  ai_check_ready || return
  section "Chat — AI Security Assistant"

  SYSTEM="Kamu adalah AI security assistant expert di cybersecurity, penetration testing, CTF, dan ethical hacking. Jawab dalam Bahasa Indonesia. Berikan jawaban praktis, teknikal, dan to the point. Format command dan code dengan jelas."

  echo -e "  ${DIM}Ketik 'exit' untuk keluar${NC}\n"

  HISTORY=""
  while true; do
    echo -ne "${WHITE}  Lo${NC}: "
    read -r userInput
    [[ "$userInput" == "exit" || "$userInput" == "quit" || -z "$userInput" ]] && break

    info "Thinking..."

    FULL_PROMPT="${HISTORY:+Riwayat:\n$HISTORY\n\n}User: $userInput"
    RESPONSE=$(ai_call "$FULL_PROMPT" "$SYSTEM" 1024)

    if [[ -z "$RESPONSE" ]]; then
      err "Tidak ada response. Cek koneksi atau API key."
      continue
    fi

    ai_print_response "$RESPONSE"
    HISTORY=$(printf '%s\nUser: %s\nAI: %s' "$HISTORY" "$userInput" "$(echo "$RESPONSE" | head -2)" | tail -15)
  done
}

# ─────────────────────────────────────────
ai_analyze_log() {
  ai_check_ready || return
  section "Analisis Log / Output Tools"
  echo -e "  ${DIM}Paste log/output, ketik END di baris baru setelah selesai${NC}\n"

  LOG=""
  while IFS= read -r line; do
    [[ "$line" == "END" ]] && break
    LOG+="$line"$'\n'
  done
  [[ -z "$LOG" ]] && { err "Log kosong!"; pause; return; }

  echo -ne "${WHITE}  Konteks${NC} (opsional): "
  read -r context

  info "Menganalisis..."
  PROMPT="Analisis output/log berikut dari sisi keamanan. Temukan hal mencurigakan, menarik, atau perlu diperhatikan. Berikan temuan dan rekomendasi.

Konteks: ${context:-tidak ada}

Log:
\`\`\`
$LOG
\`\`\`"

  RESPONSE=$(ai_call "$PROMPT" "Kamu adalah security analyst expert. Analisis log keamanan dengan detail. Jawab Bahasa Indonesia." 1500)
  [[ -z "$RESPONSE" ]] && { err "Gagal dapat response."; pause; return; }
  ai_print_response "$RESPONSE"
  pause
}

# ─────────────────────────────────────────
ai_explain_cve() {
  ai_check_ready || return
  section "Explain CVE / Exploit"

  echo -ne "${WHITE}  CVE / nama exploit${NC}: "
  read -r cve
  [[ -z "$cve" ]] && { err "Kosong!"; pause; return; }

  info "Fetching info tentang $cve..."
  PROMPT="Jelaskan $cve:
1. Apa & cara kerjanya (teknikal tapi mudah dipahami)
2. Sistem yang terdampak
3. CVSS score & severity
4. Cara exploit (high level, untuk edukasi)
5. Cara mitigasi / patch
6. Masih relevan / aktif dipakai attacker?"

  RESPONSE=$(ai_call "$PROMPT" "Kamu adalah vulnerability researcher expert. Jawab Bahasa Indonesia. Tujuan edukasi dan defensive." 1500)
  [[ -z "$RESPONSE" ]] && { err "Gagal dapat response."; pause; return; }
  ai_print_response "$RESPONSE"
  pause
}

# ─────────────────────────────────────────
ai_review_code() {
  ai_check_ready || return
  section "Review Kode — Cari Vulnerability"

  echo -ne "${WHITE}  Bahasa${NC} (python/php/js/bash/dll): "
  read -r lang
  lang=${lang:-unknown}

  echo -e "  ${DIM}Paste kode, ketik END di baris baru setelah selesai${NC}\n"

  CODE=""
  while IFS= read -r line; do
    [[ "$line" == "END" ]] && break
    CODE+="$line"$'\n'
  done
  [[ -z "$CODE" ]] && { err "Kode kosong!"; pause; return; }

  info "Reviewing..."
  PROMPT="Security review kode $lang ini. Temukan vulnerability, bug keamanan, atau praktek buruk.

\`\`\`$lang
$CODE
\`\`\`

Berikan:
1. Daftar vulnerability (dengan baris kalau bisa)
2. Kenapa berbahaya & cara exploit-nya
3. Kode yang sudah diperbaiki"

  RESPONSE=$(ai_call "$PROMPT" "Kamu adalah code security reviewer (SAST) expert. Jawab Bahasa Indonesia. Detail dan actionable." 2000)
  [[ -z "$RESPONSE" ]] && { err "Gagal dapat response."; pause; return; }
  ai_print_response "$RESPONSE"
  pause
}
