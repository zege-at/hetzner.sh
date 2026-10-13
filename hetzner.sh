#!/bin/bash
# ==============================================================================
# Dynamic Hetzner DNS Updater
# Works on UniFi OS, EdgeOS, Debian, Ubuntu, Alpine, etc.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/hetzner.sh.env"
CACHE_FILE="${SCRIPT_DIR}/hetzner_last_ip.txt"
LOG_FILE="${SCRIPT_DIR}/hetzner.log"

log_msg() {
    local TIMESTAMP
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    local MSG="$TIMESTAMP $1"
    echo "$MSG" >> "$LOG_FILE"
    if [ -t 1 ]; then
        echo "$MSG"
    fi
}

# Prüfen, ob benötigte CLI-Tools installiert sind
for cmd in curl jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_msg "[ERROR] Benötigtes Tool '$cmd' ist nicht installiert."
        exit 1
    fi
done

# Environment-Datei laden
if [ -f "$ENV_FILE" ]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
else
    log_msg "[ERROR] Konfigurationsdatei '$ENV_FILE' fehlt. Bitte erstelle sie aus hetzner.sh.env.example."
    exit 1
fi

# Öffentliche WAN-IP abfragen
get_public_ip() {
    ip=$(curl -s -4 --connect-timeout 5 https://api.ipify.org) || \
    ip=$(curl -s -4 --connect-timeout 5 https://checkip.amazonaws.com) || \
    ip=$(curl -s -4 --connect-timeout 5 https://ifconfig.me)
    echo "$ip" | tr -d '\r\n '
}

CURRENT_IP=$(get_public_ip)

if [[ ! "$CURRENT_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    log_msg "[ERROR] Keine gültige WAN-IP ermittelt: '$CURRENT_IP'"
    exit 1
fi

LAST_IP=""
if [ -f "$CACHE_FILE" ]; then
    LAST_IP=$(cat "$CACHE_FILE")
fi

if [ "$CURRENT_IP" == "$LAST_IP" ]; then
    if [ -t 1 ]; then
        echo "[INFO] IP unverändert ($CURRENT_IP). Kein Update erforderlich."
    fi
    exit 0
fi

ZONES_RESPONSE=$(curl -s -H "Authorization: Bearer ${HETZNER_API_TOKEN}" "https://api.hetzner.cloud/v1/zones")
ZONE_ID=$(echo "$ZONES_RESPONSE" | jq -r ".zones[]? | select(.name == \"${ZONE_NAME}\") | .id")

if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" == "null" ]; then
    log_msg "[ERROR] Zone '${ZONE_NAME}' konnte nicht ermittelt werden."
    exit 1
fi

RRSET_RESPONSE=$(curl -s -H "Authorization: Bearer ${HETZNER_API_TOKEN}" "https://api.hetzner.cloud/v1/zones/${ZONE_ID}/rrsets/${RECORD_NAME}/A")
REMOTE_IP=$(echo "$RRSET_RESPONSE" | jq -r '.rrset.records[0].value // empty')

if [ "$REMOTE_IP" == "$CURRENT_IP" ]; then
    echo "$CURRENT_IP" > "$CACHE_FILE"
    if [ -t 1 ]; then
        echo "[INFO] IP bei Hetzner bereits aktuell ($CURRENT_IP). Cache aktualisiert."
    fi
    exit 0
fi

UPDATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "https://api.hetzner.cloud/v1/zones/${ZONE_ID}/rrsets/${RECORD_NAME}/A/actions/set_records" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${HETZNER_API_TOKEN}" \
  -d '{
    "records": [
      {
        "value": "'"${CURRENT_IP}"'"
      }
    ]
  }')

HTTP_CODE=$(echo "$UPDATE_RESPONSE" | tail -n1)
BODY=$(echo "$UPDATE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
    echo "$CURRENT_IP" > "$CACHE_FILE"
    log_msg "[SUCCESS] IP für ${RECORD_NAME}.${ZONE_NAME} aktualisiert: '${LAST_IP:-keine}' -> '$CURRENT_IP'"
else
    log_msg "[ERROR] API-Update fehlgeschlagen (HTTP $HTTP_CODE): $BODY"
    exit 1
fi
