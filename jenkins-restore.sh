#!/bin/bash
# jenkins-restore.sh
# Run this on your destination server (Docker Compose deployment)

set -e

# === CONFIGURATION ===
BACKUP_FILE="${1:-}"
COMPOSE_DIR="${COMPOSE_DIR:-.}"
TEMP_RESTORE_DIR="/tmp/jenkins-restore-temp"

# === SCRIPT START ===
echo "============================================"
echo "Jenkins Restore Script (Docker Compose)     "
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
echo "[1/6] Stopping Jenkins..."
docker compose stop

# Step 2: Get volume name (not path)
echo "[2/6] Getting Jenkins volume name..."
get_jenkins_volume() {
  docker inspect -f '{{range .Mounts}}{{if eq .Destination "/var/jenkins_home"}}{{.Name}}{{end}}{{end}}' jenkins
}
VOLUME_NAME=$(get_jenkins_volume)

if [ -z "$VOLUME_NAME" ]; then
    echo "ERROR: jenkins_home volume not found."
    echo "Make sure Jenkins has been started at least once with docker compose."
    exit 1
fi
echo "      Volume name: $VOLUME_NAME"

# Step 3: Extract backup to temporary directory
echo "[3/6] Preparing backup for restore..."
echo "      Creating temporary directory..."
rm -rf "$TEMP_RESTORE_DIR"
mkdir -p "$TEMP_RESTORE_DIR"

echo "      Extracting backup to temporary location..."
tar -xzvf "$BACKUP_FILE" -C "$TEMP_RESTORE_DIR"

# Step 4: Restore using busybox container
echo "[4/6] Restoring files using busybox container..."

# Clear existing configuration files from the volume
echo "      Clearing old configurations from volume..."
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
echo "      Copying restored files to Jenkins volume..."
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

# Step 5: Cleanup and start Jenkins
echo "[5/6] Cleaning up and starting Jenkins..."
echo "      Removing temporary files..."
sudo rm -rf "$TEMP_RESTORE_DIR"

echo "      Starting Jenkins..."
docker compose start

echo "[6/6] Done."

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



