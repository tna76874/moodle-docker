#!/bin/bash

# 1. Prüfen, ob die .env Datei existiert
if [ ! -f .env ]; then
    echo "Fehler: .env Datei nicht gefunden!"
    exit 1
fi

# 2. Port aus der .env extrahieren
# Wir suchen nach COMPOSE_PORT= und nehmen den Wert danach
PORT=$(grep '^COMPOSE_PORT=' .env | cut -d '=' -f2)

if [ -z "$PORT" ]; then
    echo "Fehler: COMPOSE_PORT konnte in der .env nicht gefunden werden."
    exit 1
fi

echo "Starte temporären Cloudflare-Tunnel für Port: $PORT..."
echo "--------------------------------------------------------"

# 3. Cloudflared ausführen
cloudflared tunnel --url http://localhost:$PORT 2>&1 | grep --color=always -E "https://.*\.trycloudflare\.com|$"