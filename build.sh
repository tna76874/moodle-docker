#!/bin/bash
set -e

# --- Konfiguration ---
DEFAULT_MAJOR_MOODLE="4"
PHP_VERSION_TAG="8.0"

# --- Dynamische Abfrage der Moodle Version (Ansible Migration) ---
echo "Frage Moodle Tags von GitHub API ab..."
# 1. Holt alle Tags
# 2. Filtert Tags ohne Bindestrich (keine Betas/RCs)
# 3. Filtert Tags, die mit 'v' + Hauptversion beginnen (z.B. v4)
# 4. Nimmt den obersten (neuesten) Tag
TAG_DATA=$(curl -s "https://api.github.com/repos/moodle/moodle/tags?per_page=100")

MOODLE_TAG=$(echo "$TAG_DATA" | jq -r "[.[] | select(.name | contains(\"-\") | not) | select(.name | startswith(\"v$DEFAULT_MAJOR_MOODLE\"))][0].name")
MOODLE_TARBALL_URL=$(echo "$TAG_DATA" | jq -r ".[] | select(.name == \"$MOODLE_TAG\") | .tarball_url")

if [ "$MOODLE_TAG" == "null" ] || [ -z "$MOODLE_TAG" ]; then
  echo "Fehler: Konnte keinen passenden Moodle-Tag finden!"
  exit 1
fi

echo "Gefundener Tag: $MOODLE_TAG"
echo "Tarball URL: $MOODLE_TARBALL_URL"

# --- Repository Namen ermitteln ---
if [ -z "$GITHUB_REPOSITORY" ]; then
  REMOTE_URL=$(git config --get remote.origin.url)
  GITHUB_REPOSITORY=$(echo "$REMOTE_URL" | sed -E 's/.*github.com[:\/](.*)\.git$/\1/')
  : "${GITHUB_REPOSITORY:=moodle-custom}"
fi

IMAGE_NAME="ghcr.io/${GITHUB_REPOSITORY}"
COMMIT_HASH=$(git rev-parse --short HEAD || echo "local")

# Kanal/Tag Logik
CHANNEL="latest"
if [[ "$GITHUB_REF" == *"stable"* ]]; then
  CHANNEL="stable"
fi

echo "--- Vorbereitung: Build Repo klonen & patchen ---"
rm -rf build_base
git clone https://github.com/ellakcy/docker-moodle.git build_base
cd build_base

DOCKERFILE="dockerfiles/apache/Dockerfile"

# Patchen wie in Ansible 'lineinfile'
sed -i "s|ARG PHP_VERSION=.*|ARG PHP_VERSION=\"${PHP_VERSION_TAG}\"|g" $DOCKERFILE
sed -i "s|curl -s -N.*|curl -L ${MOODLE_TARBALL_URL} \| tar -xvz \&\& mv moodle* moodle \&\& \\\|g" $DOCKERFILE

cd ..

echo "--- Build & Push ---"
docker build \
  --no-cache \
  --pull \
  --build-arg PHP_VERSION="${PHP_VERSION_TAG}" \
  -t "${IMAGE_NAME}:${COMMIT_HASH}" \
  -f build_base/dockerfiles/apache/Dockerfile \
  build_base/

# Push & Tagging Funktion
tag_and_push() {
  local TAG=$1
  docker tag "${IMAGE_NAME}:${COMMIT_HASH}" "${IMAGE_NAME}:${TAG}"
  if [ "$CI" == "true" ]; then
    docker push "${IMAGE_NAME}:${TAG}"
  fi
}

if [ "$CI" == "true" ]; then
  docker push "${IMAGE_NAME}:${COMMIT_HASH}"
  tag_and_push "latest"
  # Erzeugt einen Tag wie: ghcr.io/user/repo:v4.3.2-php8.0
  tag_and_push "${MOODLE_TAG}-php${PHP_VERSION_TAG}"
fi