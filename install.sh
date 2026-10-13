#!/bin/bash
# ==============================================================================
# Hetzner Dynamic DNS Installer
# One-liner installation script for UniFi OS, EdgeOS, and Generic Linux
# ==============================================================================

set -e

REPO_URL="https://raw.githubusercontent.com/DEIN_USERNAME/DEIN_REPO/main"

# Farben für Terminal-Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Hetzner DynDNS Installer ===${NC}\n"

# 1. System und Pfad ermitteln
if [ -d "/data" ] && [ -f "/usr/bin/ubnt-device-info" -o -d "/data/unifi" ]; then
    SYS_TYPE="unifi"
    INSTALL_DIR="/data/.hetzner.sh"
    echo -e "Erkanntes System: ${YELLOW}UniFi OS Gateway${NC}"
elif [ -d "/config/scripts" ]; then
    SYS_TYPE="edgeos"
    INSTALL_DIR="/config/scripts/hetzner"
    echo -e "Erkanntes System: ${YELLOW}EdgeRouter / EdgeOS${NC}"
else
    SYS_TYPE="linux"
    INSTALL_DIR="/opt/hetzner-dyndns"
    echo -e "Erkanntes System: ${YELLOW}Generisches Linux${NC}"
fi

# 2. Abhängigkeiten prüfen / installieren
if ! command -v curl >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] 'curl' wird benötigt, ist aber nicht installiert.${NC}"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo -e "${YELLOW}'jq' ist nicht installiert. Versuche Installation...${NC}"
    if [ "$SYS_TYPE" == "edgeos" ] || command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y jq
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache jq
    else
        echo -e "${RED}[ERROR] 'jq' konnte nicht automatisch installiert werden. Bitte manuell installieren.${NC}"
        exit 1
    fi
fi

# 3. Verzeichnis anlegen
mkdir -p "$INSTALL_DIR"

# 4. Parameter abfangen (aus Argumenten ODER interaktiver Abfrage)
read_input() {
    local prompt="$1"
    local var_name="$2"
    local val=""
    if [ -t 0 ]; then
        read -p "$prompt: " val
    elif [ -c /dev/tty ]; then
        read -p "$prompt: " val < /dev/tty
    fi
    eval "$var_name=\"$val\""
}

echo ""
read_input "Hetzner Cloud API Token" TOKEN
read_input "Zone Name (z. B. example.com)" ZONE
read_input "Record Name (z. B. router oder @)" RECORD

if [ -z "$TOKEN" ] || [ -z "$ZONE" ] || [ -z "$RECORD" ]; then
    echo -e "${RED}[ERROR] Token, Zone Name und Record Name dürfen nicht leer sein.${NC}"
    exit 1
fi

# 5. Skripte & Example-Dateien herunterladen
echo -e "\nLade Skripte und Konfigurationsvorlage herunter..."
curl -fsSL "${REPO_URL}/hetzner.sh" -o "${INSTALL_DIR}/hetzner.sh"
curl -fsSL "${REPO_URL}/hetzner.sh.env.example" -o "${INSTALL_DIR}/hetzner.sh.env.example"

# 6. Example-Datei umbenennen/kopieren & Werte eintragen
echo "Erstelle Konfigurationsdatei hetzner.sh.env aus hetzner.sh.env.example..."
cp "${INSTALL_DIR}/hetzner.sh.env.example" "${INSTALL_DIR}/hetzner.sh.env"

# Werte per sed in der .env-Datei ersetzen
sed -i "s|HETZNER_API_TOKEN=.*|HETZNER_API_TOKEN=\"${TOKEN}\"|" "${INSTALL_DIR}/hetzner.sh.env"
sed -i "s|ZONE_NAME=.*|ZONE_NAME=\"${ZONE}\"|" "${INSTALL_DIR}/hetzner.sh.env"
sed -i "s|RECORD_NAME=.*|RECORD_NAME=\"${RECORD}\"|" "${INSTALL_DIR}/hetzner.sh.env"

# 7. Rechte setzen
chmod 700 "${INSTALL_DIR}/hetzner.sh"
chmod 600 "${INSTALL_DIR}/hetzner.sh.env"
chmod 600 "${INSTALL_DIR}/hetzner.sh.env.example"

# Symlink unter UniFi OS für Komfort
if [ "$SYS_TYPE" == "unifi" ]; then
    ln -sf /data/.hetzner.sh /root/.hetzner.sh
fi

# 8. Cronjob automatisch einrichten
CRON_CMD="*/5 * * * * ${INSTALL_DIR}/hetzner.sh >/dev/null 2>&1"
(crontab -l 2>/dev/null | grep -v "${INSTALL_DIR}/hetzner.sh"; echo "$CRON_CMD") | crontab -

echo -e "${GREEN}✓ Installation erfolgreich abgeschlossen!${NC}"
echo -e "Installationsverzeichnis: ${YELLOW}${INSTALL_DIR}${NC}"
echo -e "Cronjob wurde eingerichtet (Ausführung alle 5 Minuten).\n"

# 9. Ersten Testlauf durchführen
echo "Starte Erstprüfung..."
"${INSTALL_DIR}/hetzner.sh"
