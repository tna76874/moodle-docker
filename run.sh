#!/bin/bash

# --- TEIL 1: INITIALISIERUNG (ersetzt die init.sh) ---
EXAMPLE_FILE="env.example"
TARGET_FILE=".env"

if [ ! -f "$TARGET_FILE" ]; then
    echo "Keine .env gefunden. Initialisiere mit Zufallspasswörtern..."
    
    if [ ! -f "$EXAMPLE_FILE" ]; then
        echo "Fehler: $EXAMPLE_FILE nicht gefunden!"
        exit 1
    fi

    cp "$EXAMPLE_FILE" "$TARGET_FILE"

    # Funktion zur Generierung eines sicheren Passworts
    generate_password() {
        LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32
    }

    NEW_DB_PASSWORD=$(generate_password)
    NEW_ADMIN_PASSWORD=$(generate_password)

    # Platzhalter ersetzen
    sed -i "s|SetzeHierEinSicheresPasswort|$NEW_DB_PASSWORD|g" "$TARGET_FILE"
    sed -i "s|SetzeHierEinAdminPasswort|$NEW_ADMIN_PASSWORD|g" "$TARGET_FILE"
    
    echo "Erfolg: .env wurde neu erstellt."
else
    echo ".env existiert bereits. Überspringe Passwort-Generierung."
fi

# --- TEIL 2: TUNNEL STARTEN & URL ABGREIFEN ---
echo "Starte Cloudflare Quick Tunnel..."
docker compose up -d tunnel

echo "Warte auf Generierung der Tunnel-URL..."
MAX_RETRIES=12
COUNT=0
TUNNEL_URL=""

while [ $COUNT -lt $MAX_RETRIES ]; do
    sleep 5
    # Extrahiere die URL aus den Logs des 'tunnel' Services
    TUNNEL_URL=$(docker compose --profile optional-tunnel logs tunnel 2>&1 | grep -Po 'https://[a-z0-9-]+\.trycloudflare\.com' | head -n 1)

    if [ ! -z "$TUNNEL_URL" ]; then
        break
    fi
    
    COUNT=$((COUNT+1))
    echo "Versuch $COUNT/$MAX_RETRIES: Suche URL..."
done

if [ -z "$TUNNEL_URL" ]; then
    echo "Fehler: Cloudflare URL konnte nicht ermittelt werden."
    exit 1
fi

echo "Tunnel-URL gefunden: $TUNNEL_URL"

# --- TEIL 3: URL SETZEN & MOODLE STARTEN ---
# Aktualisiere MOODLE_URL in der .env für den Docker-Start
sed -i "s|^MOODLE_URL=.*|MOODLE_URL=$TUNNEL_URL|" "$TARGET_FILE"

echo "Starte restliche Moodle-Dienste..."
docker compose up -d

echo "----------------------------------------------------------------"
echo "Moodle ist jetzt bereit!"
echo "URL:          $TUNNEL_URL"
echo "Admin-User:   admin (oder wie in .env gesetzt)"
# Falls die Passwörter gerade erst erstellt wurden, zeigen wir sie an:
if [ ! -z "$NEW_ADMIN_PASSWORD" ]; then
    echo "Admin-Pass:   $NEW_ADMIN_PASSWORD"
fi
echo "----------------------------------------------------------------"

# --- TEIL 4: BEREINIGUNG BEI BEENDEN ---
echo ""
echo "----------------------------------------------------------------"
read -n 1 -s -r -p "Drücke eine beliebige Taste, um Moodle & Tunnel zu beenden..."
echo -e "\n"

echo "Stoppe alle Dienste (inkl. Tunnel-Profil)..."

docker compose down
docker compose --profile optional-tunnel down

echo "----------------------------------------------------------------"
echo "Alles gestoppt. Das Terminal kann nun geschlossen werden."