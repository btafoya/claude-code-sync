# Getting Started with claude-sync

## Quick Installation & First Backup

### 1. Install Dependencies

```bash
# Check if dependencies are installed
gpg --version
tar --version
sha256sum --version
jq --version
rsync --version

# If missing, install them
sudo apt update
sudo apt install gnupg tar gzip coreutils jq rsync
```

### 2. Install claude-sync

```bash
# From the project directory
./install.sh

# If ~/.local/bin is not in PATH, add it
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 3. Verify Installation

```bash
claude-sync --version
# Should show: claude-sync v1.0.0-phase1
```

### 4. Initialize Backup System

```bash
claude-sync init
```

This creates `~/.claude-sync/` directory structure.

### 5. Create Your First Backup

```bash
claude-sync backup
```

You'll be prompted to:
1. Enter an encryption password
2. Confirm the password

**Important**: Remember this password! You'll need it to restore.

### 6. Check Status

```bash
claude-sync status
```

Shows:
- Machine name
- Latest backup timestamp
- Backup size
- Number of files

### 7. Test Restore (Dry Run)

```bash
claude-sync restore --dry-run
```

Shows what would be restored without actually doing it.

---

## Multi-Machine Usage

### On Machine 1 (Work Laptop)

```bash
# Create backup
claude-sync backup

# Find the backup file
ls -lh ~/.claude-sync/storage/current/latest-backup.tar.gz.gpg
```

### Transfer to Machine 2

**Option 1: Manual Transfer**
```bash
# Copy the encrypted file to USB or cloud storage
cp ~/.claude-sync/storage/current/latest-backup.tar.gz.gpg /path/to/usb/
```

**Option 2: SCP Transfer**
```bash
# Direct transfer via SSH
scp ~/.claude-sync/storage/current/latest-backup.tar.gz.gpg user@machine2:~/
```

### On Machine 2 (Home Desktop)

```bash
# Initialize on new machine
claude-sync init

# Place the backup file
cp /path/from/transfer/latest-backup.tar.gz.gpg ~/.claude-sync/storage/current/

# Copy metadata files too (optional but recommended)
cp latest-backup.checksum ~/.claude-sync/storage/current/
cp latest-backup.timestamp ~/.claude-sync/storage/current/
cp latest-backup.hostname ~/.claude-sync/storage/current/

# Restore
claude-sync restore
```

Enter the same password you used for encryption.

---

## Common Workflows

### Daily Backup

```bash
# Simple daily backup
claude-sync backup
```

### Before Major Changes

```bash
# Backup before experimenting
claude-sync backup

# Make changes to Claude Code configs
# ...

# If something breaks, restore
claude-sync restore
```

### Conflict Handling

If conflicts are detected during restore:

```
Conflict detected: CLAUDE.md
  Local:  Modified 2025-01-15 14:30
  Remote: Modified 2025-01-15 16:45

Choose action:
  [1] Keep backup version (overwrite current)
  [2] Keep current version (skip restore)
  [3] Show diff
  [4] Keep both (backup saved as .backup)
  [5] Skip this file
  [q] Quit without changes

Your choice:
```

Choose the appropriate action for each conflict.

---

## Troubleshooting

### "No backup found"

Create a backup first:
```bash
claude-sync backup
```

### "Decryption failed"

- Verify you're using the correct password
- Check the backup file isn't corrupted
- Ensure GPG is properly installed

### "Permission denied"

Fix permissions:
```bash
chmod 700 ~/.claude-sync
chmod 600 ~/.claude-sync/config/*
```

### "Missing dependencies"

Install required packages:
```bash
sudo apt install gnupg tar gzip coreutils jq rsync
```

---

## What Gets Backed Up?

From `~/.claude/`:
- ✅ CLAUDE.md
- ✅ RULES.md  
- ✅ PRINCIPLES.md
- ✅ MODE_*.md files
- ✅ MCP server configurations
- ✅ Custom slash commands
- ✅ All other config files

**Not** backed up:
- ❌ .git directories
- ❌ *.log files
- ❌ tmp/ directories
- ❌ Project-specific .claude/ (different scope)

---

## Next Steps

1. **Establish Routine**: Backup before/after major config changes
2. **Test Restore**: Try restoring to verify your workflow
3. **Document Password**: Store encryption password securely
4. **Explore Options**: Try `--dry-run` and `--verbose` flags

For complete documentation, see:
- `README.md` - Full user guide
- `CLAUDE.md` - Development guide
- `claudedocs/` - Detailed specifications

---

**You're all set! Your Claude Code configurations are now safely backed up.** 🎉
