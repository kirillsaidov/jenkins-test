# Jenkins migration

## Requirements

- Ensure `docker compose` is available on your server.
- Scripts must be run from the directory containing `docker-compose.yaml`
 Backup (Source Server)

## Backup

```bash
chmod +x jenkins-backup.sh

# Custom name (creates ./backup/my-backup.tar.gz)
./jenkins-backup.sh my-backup

# Default name (creates ./backup/jenkins-backup-.tar.gz)
./jenkins-backup.sh
```

This will:
1. Stop Jenkins
2. Create backup in `backup/` folder (alongside script)
3. Restart Jenkins

## Restore

```bash
chmod +x jenkins-restore.sh
./jenkins-restore.sh ./backup/my-backup.tar.gz
```

This will:
1. Stop Jenkins
2. Restore all configs, jobs, credentials
3. Start Jenkins

## What Gets Backed Up

- Jobs
- Credentials (SSH keys, passwords, tokens)
- User accounts
- Global configuration

**NOTE:** Plugins and build history are **not** backed up.



