#!/bin/bash
# jenkins-restore.sh
# Run this on your destination server (Docker Compose deployment)

set -e

# === CONFIGURATION ===
BACKUP_FILE="${1:-}"
COMPOSE_DIR="${COMPOSE_DIR:-.}"

# === SCRIPT START ===
echo "============================================"
echo "Jenkins Restore Script (Docker Compose)"
echo "============================================"

# Check for backup file argument
if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup-file.tar.gz>"
    echo ""
    echo "Example: $0 /tmp/jenkins-backup-20241201-120000.tar.gz"
    exit 1
fi

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "Backup file: $BACKUP_FILE"
echo "Compose dir: $COMPOSE_DIR"
echo ""

# Check for docker-compose file
cd "$COMPOSE_DIR"
if [ ! -f "docker-compose.yaml" ] && [ ! -f "docker-compose.yml" ]; then
    echo "ERROR: docker-compose.yaml not found in: $COMPOSE_DIR"
    echo "Set COMPOSE_DIR environment variable or run from docker-compose directory."
    exit 1
fi

# Step 1: Stop Jenkins if running
echo "[1/5] Stopping Jenkins..."
docker compose down 2>/dev/null || true

# Step 2: Ensure volume exists
echo "[2/5] Ensuring Jenkins volume exists..."
if ! docker volume inspect jenkins_home >/dev/null 2>&1; then
    echo "      Volume doesn't exist. Creating..."
    docker compose up -d
    echo "      Waiting for initialization..."
    sleep 30
    docker compose down
fi

# Step 3: Get volume path
echo "[3/5] Locating Jenkins volume..."
VOLUME_PATH=$(docker volume inspect jenkins_home --format '{{ .Mountpoint }}')

if [ -z "$VOLUME_PATH" ]; then
    echo "ERROR: Could not find jenkins_home volume"
    exit 1
fi
echo "      Volume path: $VOLUME_PATH"

# Step 4: Restore backup
echo "[4/5] Restoring backup..."
echo "      Clearing old configurations..."
sudo rm -rf "${VOLUME_PATH}/jobs/"
sudo rm -rf "${VOLUME_PATH}/users/"
sudo rm -rf "${VOLUME_PATH}/nodes/"
sudo rm -rf "${VOLUME_PATH}/secrets/"
sudo rm -rf "${VOLUME_PATH}/userContent/"
sudo rm -rf "${VOLUME_PATH}/.ssh/"
sudo rm -f "${VOLUME_PATH}/config.xml"
sudo rm -f "${VOLUME_PATH}"/credentials*.xml

echo "      Extracting backup..."
sudo tar -xzvf "$BACKUP_FILE" -C "$VOLUME_PATH"

echo "      Setting permissions..."
sudo chown -R 1000:1000 "$VOLUME_PATH"

# Step 5: Start Jenkins
echo "[5/5] Starting Jenkins..."
docker compose up -d

echo ""
echo "============================================"
echo "Restore complete!"
echo "============================================"
echo ""
echo "Monitor startup: docker logs -f jenkins"
echo "Access Jenkins:  http://localhost:8080"
echo ""
echo "Post-restore checklist:"
echo "  [ ] Verify jobs appear"
echo "  [ ] Check credentials (Manage Jenkins → Credentials)"
echo "  [ ] Test SSH connections"
echo "  [ ] Update Jenkins URL if needed"



