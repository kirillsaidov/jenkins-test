#!/bin/bash
# jenkins-backup.sh
# Run this on your source Jenkins server (Docker Compose deployment)

set -e

# === CONFIGURATION ===
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/backup"
COMPOSE_DIR="${COMPOSE_DIR:-.}"

# === SCRIPT START ===
mkdir -p "$BACKUP_DIR"

if [ -n "$1" ]; then
    BACKUP_NAME="$1.tar.gz"
else
    BACKUP_NAME="jenkins-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
fi
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

echo "============================================"
echo "Jenkins Backup Script (Docker Compose)"
echo "============================================"

get_jenkins_volume() {
  docker inspect -f '{{range .Mounts}}{{if eq .Destination "/var/jenkins_home"}}{{.Name}}{{end}}{{end}}' jenkins
}

# Get volume path
VOLUME_NAME=$(get_jenkins_volume)

if [ -z "$VOLUME_PATH" ]; then
    echo "ERROR: jenkins_home volume not found."
    echo "Make sure Jenkins has been started at least once with docker compose."
    exit 1
fi

echo "Volume path: $VOLUME_PATH"
echo "Backup destination: $BACKUP_PATH"
echo ""

# Stop Jenkins for consistent backup
echo "Stopping Jenkins..."
cd "$COMPOSE_DIR"
docker compose down 2>/dev/null || true

cd "$VOLUME_PATH"

# Build exclude list
EXCLUDES=(
    "--exclude=workspace"
    "--exclude=caches"
    "--exclude=.cache"
    "--exclude=war"
    "--exclude=logs"
    "--exclude=plugins"
    "--exclude=builds"
)

echo "Creating backup..."

# Create backup
sudo tar -czvf "$BACKUP_PATH" \
    "${EXCLUDES[@]}" \
    config.xml \
    credentials*.xml \
    secrets/ \
    jobs/ \
    users/ \
    nodes/ \
    *.xml \
    userContent/ \
    .ssh/ 2>/dev/null || true

# Restart Jenkins
echo "Restarting Jenkins..."
cd "$COMPOSE_DIR"
docker compose up -d

echo ""
echo "============================================"
echo "Backup complete!"
echo "============================================"
echo "File: $BACKUP_PATH"
echo "Size: $(du -h $BACKUP_PATH | cut -f1)"
echo ""
echo "Next steps:"
echo "1. Transfer to new server:"
echo "   scp $BACKUP_PATH user@new-server:/tmp/"
echo ""
echo "2. On the new server, run the restore script:"
echo "   ./jenkins-restore.sh /tmp/$BACKUP_NAME"



