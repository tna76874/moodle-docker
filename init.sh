#!/bin/bash

# Dateinamen
EXAMPLE_FILE="env.example"
TARGET_FILE=".env"

# Prüfen, ob env.example existiert
if [ ! -f "$EXAMPLE_FILE" ]; then
    echo "Fehler: $EXAMPLE_FILE nicht gefunden!"
    exit 1
fi

# Prüfen, ob .env bereits existiert (Sicherheitsschutz)
if [ -f "$TARGET_FILE" ]; then
    echo "Warnung: $TARGET_FILE existiert bereits. Überspringen, um bestehende Passwörter nicht zu löschen."
    exit 0
fi

echo "Initialisiere .env Datei..."

# Kopiere die Beispiel-Datei
cp "$EXAMPLE_FILE" "$TARGET_FILE"

# Funktion zur Generierung eines sicheren Passworts (32 Zeichen, Alphanumerisch)
generate_password() {
    # Nutzt /dev/urandom für echte Zufälligkeit
    LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32
}

# Neue Passwörter generieren
NEW_DB_PASSWORD=$(generate_password)
NEW_ADMIN_PASSWORD=$(generate_password)

# Platzhalter in der neuen .env ersetzen
# Wir nutzen | als Trenner in sed, falls Passwörter Sonderzeichen enthalten würden
sed -i "s|SetzeHierEinSicheresPasswort|$NEW_DB_PASSWORD|g" "$TARGET_FILE"
sed -i "s|SetzeHierEinAdminPasswort|$NEW_ADMIN_PASSWORD|g" "$TARGET_FILE"

echo "Erfolg: .env wurde erstellt und mit Zufallspasswörtern konfiguriert."
echo "----------------------------------------------------------------"
echo "DB Passwort:    $NEW_DB_PASSWORD"
echo "Admin Passwort: $NEW_ADMIN_PASSWORD"
echo "----------------------------------------------------------------"
echo "WICHTIG: Ändere MOODLE_URL in der .env, falls du nicht auf localhost arbeitest."
