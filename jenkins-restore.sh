#!/bin/bash
# jenkins-restore.sh
# Run this on your destination server (Docker Compose deployment)

set -e

echo "============================================"
echo "Jenkins Restore Script (Docker Compose)     "
echo "============================================"
echo ""

# === CONFIGURATION ===
BACKUP_FILE="${1:-}"
COMPOSE_DIR="${COMPOSE_DIR:-.}"
TEMP_RESTORE_DIR="/tmp/jenkins-restore-temp"
CONTAINER_NAME="jenkins"

get_jenkins_volume() {
  docker inspect -f '{{range .Mounts}}{{if eq .Destination "/var/jenkins_home"}}{{.Name}}{{end}}{{end}}' jenkins
}

# === SCRIPT START ===
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

echo ">> Backup file: $BACKUP_FILE"

# Check if container exists
if ! docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo "ERROR: container $CONTAINER_NAME does not exist."
    echo "Make sure Jenkins has been started at least once with docker compose."
	exit 1
fi

# Stop Jenkins if running
echo ">> Stopping Jenkins..."
docker compose stop

# Get volume name (not path)
echo ">> Getting Jenkins volume name..."
VOLUME_NAME=$(get_jenkins_volume)

if [ -z "$VOLUME_NAME" ]; then
    echo "ERROR: jenkins_home volume not found."
    echo "Make sure Jenkins has been started at least once with docker compose."
    exit 1
fi

echo "Volume name: $VOLUME_NAME"

# Extract backup to temporary directory
echo ">> Preparing backup for restore..."
echo "   Creating temporary directory..."
rm -rf "$TEMP_RESTORE_DIR"
mkdir -p "$TEMP_RESTORE_DIR"

echo "   Extracting backup to temporary location..."
tar -xzvf "$BACKUP_FILE" -C "$TEMP_RESTORE_DIR"

# Clear existing configuration files from the volume
echo ">> Clearing old configurations from volume..."
docker run --rm \
    -v "${VOLUME_NAME}:/jenkins_data" \
    busybox \
    sh -c "
        echo 'Removing old configuration files...' && \
        rm -rf /jenkins_data/jobs/ \
               /jenkins_data/users/ \
               /jenkins_data/nodes/ \
               /jenkins_data/secrets/ \
               /jenkins_data/userContent/ \
               /jenkins_data/.ssh/ \
               /jenkins_data/config.xml \
               /jenkins_data/credentials*.xml 2>/dev/null || true
    "

# Copy restored files from temp directory to volume
echo ">> Copying restored files to Jenkins volume..."
docker run --rm \
    -v "${TEMP_RESTORE_DIR}:/backup_source:ro" \
    -v "${VOLUME_NAME}:/jenkins_data" \
    busybox \
    sh -c "
        echo 'Copying backup files to Jenkins volume...' && \
        cp -a /backup_source/* /jenkins_data/ 2>/dev/null && \
        echo 'Setting correct permissions...' && \
        chown -R 1000:1000 /jenkins_data
    "

# Cleanup
echo ">> Cleanup and removing temporary files..."
sudo rm -rf "$TEMP_RESTORE_DIR"

# Start Jenkins
echo ">> Starting Jenkins..."
docker compose start

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
echo ""
echo "Note: Plugins will need to be installed separately as they are not included in the backup."



