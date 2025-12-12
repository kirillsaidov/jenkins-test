#!/bin/bash
# jenkins-backup.sh
# Run this on your source Jenkins server (Docker Compose deployment)

set -e

echo "============================================"
echo "Jenkins Backup Script (Docker Compose)      "
echo "============================================"

# === CONFIGURATION ===
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/backup"
COMPOSE_DIR="${COMPOSE_DIR:-.}"
TEMP_BACKUP_DIR="/tmp/jenkins-backup-temp"

# === SCRIPT START ===
echo ">> Creating backup directories"
mkdir -p "$BACKUP_DIR"
rm -rf "$TEMP_BACKUP_DIR"
mkdir -p "$TEMP_BACKUP_DIR"

if [ -n "$1" ]; then
    BACKUP_NAME="$1.tar.gz"
else
    BACKUP_NAME="jenkins-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
fi
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

get_jenkins_volume() {
  docker inspect -f '{{range .Mounts}}{{if eq .Destination "/var/jenkins_home"}}{{.Name}}{{end}}{{end}}' jenkins
}

# Get volume name
echo ">> Getting Jenkins volume information..."
VOLUME_NAME=$(get_jenkins_volume)

if [ -z "$VOLUME_NAME" ]; then
    echo "ERROR: jenkins_home volume not found."
    echo "Make sure Jenkins has been started at least once with docker compose."
    exit 1
fi

echo "\tVolume name: $VOLUME_NAME"

# Stop Jenkins for consistent backup
echo ">> Stopping Jenkins..."
cd "$COMPOSE_DIR"
docker compose stop

echo ">> Creating backup using busybox container..."

# Create a temporary tar file inside busybox container
TEMP_TAR="/tmp/jenkins-backup.tar.gz"

# Run busybox container with jenkins volume mounted and create backup
docker run --rm \
    -v "${VOLUME_NAME}:/jenkins_data:ro" \
    -v "${TEMP_BACKUP_DIR}:/backup_output" \
    busybox \
    sh -c "
        cd /jenkins_data && \
        echo 'Creating backup archive...' && \
        tar -czf /backup_output/backup.tar.gz \
            --exclude='workspace/*' \
            --exclude='caches/*' \
            --exclude='.cache/*' \
            --exclude='war/*' \
            --exclude='logs/*' \
            --exclude='plugins/*' \
            --exclude='builds/*' \
            config.xml \
            credentials*.xml \
            secrets/ \
            jobs/ \
            users/ \
            nodes/ \
            *.xml \
            userContent/ \
            .ssh/ 2>/dev/null || true
    "

echo ">> Backup created in busybox container"

# Copy the backup from temporary location to final destination
echo ">> Copying backup to final location..."
cp "${TEMP_BACKUP_DIR}/backup.tar.gz" "$BACKUP_PATH"

# Verify backup was created
if [ -f "$BACKUP_PATH" ]; then
    echo ">> Backup verification successful"
    echo "\tSize: $(du -h "$BACKUP_PATH" | cut -f1)"
else
    echo "ERROR: Backup file was not created!"
    exit 1
fi

# Cleanup temporary directory
echo ">> Cleaning up temporary files..."
rm -rf "$TEMP_BACKUP_DIR"

# Restart Jenkins
echo ">> Restarting Jenkins..."
cd "$COMPOSE_DIR"
docker compose start

echo ""
echo "============================================"
echo "Backup complete!"
echo "============================================"
echo "File: $BACKUP_PATH"
echo "Size: $(du -h "$BACKUP_PATH" | cut -f1)"
echo ""
echo "Next steps:"
echo "1. Transfer to new server:"
echo "   scp $BACKUP_PATH user@new-server:/tmp/"
echo ""
echo "2. On the new server, run the restore script:"
echo "   ./jenkins-restore.sh /tmp/$BACKUP_NAME"



