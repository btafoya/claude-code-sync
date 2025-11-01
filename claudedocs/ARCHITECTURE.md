# claude-sync: Architecture & Design

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     claude-sync CLI                          │
│  (User Interface - bash commands & interactive prompts)      │
└──────────────┬──────────────────────────────────────────────┘
               │
    ┌──────────┴──────────┐
    │   Core Engine       │
    │  (bash modules)     │
    └──────────┬──────────┘
               │
    ┌──────────┴────────────────────────────────┐
    │                                           │
┌───▼────┐  ┌───────┐  ┌─────────┐  ┌─────────▼─┐
│Backup  │  │Restore│  │  Sync   │  │ Snapshot  │
│Module  │  │Module │  │ Module  │  │  Module   │
└───┬────┘  └───┬───┘  └────┬────┘  └─────┬─────┘
    │           │           │             │
    └───────────┴───────────┴─────────────┘
                    │
         ┌──────────┴──────────┐
         │                     │
    ┌────▼─────┐      ┌───────▼────────┐
    │Encryption│      │   Conflict     │
    │  Engine  │      │   Resolver     │
    └────┬─────┘      └───────┬────────┘
         │                    │
    ┌────▼────────────────────▼────┐
    │     Storage Backends         │
    ├──────────────────────────────┤
    │ • Git Repository             │
    │ • Local Filesystem           │
    │ • SSH/rsync (direct)         │
    └──────────────────────────────┘
```

---

## Component Architecture

### 1. CLI Layer (`bin/claude-sync`)

**Responsibilities**:
- Parse command-line arguments
- Display help and usage information
- Route commands to appropriate modules
- Handle global flags (--verbose, --dry-run, etc.)

**Key Functions**:
```bash
parse_arguments()      # Parse CLI args
show_help()           # Display usage
validate_command()    # Ensure valid command
dispatch_command()    # Route to module
```

---

### 2. Core Modules (`lib/`)

#### `lib/backup.sh`
**Purpose**: Backup operations and file collection

**Functions**:
```bash
backup_full()              # Full backup
backup_selective()         # Category-based backup
backup_files()            # Individual file backup
collect_configs()         # Gather config files
apply_exclusions()        # Filter unwanted files
create_archive()          # Package files
```

**Workflow**:
```
User Request → Collect Files → Filter → Encrypt → Store → Log
```

#### `lib/restore.sh`
**Purpose**: Restore operations and file placement

**Functions**:
```bash
restore_full()            # Full restore
restore_selective()       # Category-based restore
restore_files()          # Individual file restore
verify_backup()          # Check backup integrity
extract_archive()        # Unpack files
apply_overrides()        # Machine-specific configs
```

**Workflow**:
```
User Request → Select Backup → Decrypt → Verify → Extract → Apply → Log
```

#### `lib/sync.sh`
**Purpose**: Bidirectional synchronization

**Functions**:
```bash
sync_git()               # Git-based sync
sync_direct()            # Machine-to-machine sync
detect_changes()         # Identify differences
merge_configs()          # Combine changes
push_changes()           # Upload to remote
pull_changes()           # Download from remote
```

**Workflow**:
```
Local State → Compare Remote → Detect Conflicts → Resolve → Sync
```

#### `lib/snapshot.sh`
**Purpose**: Versioned snapshot management

**Functions**:
```bash
snapshot_create()        # Create named snapshot
snapshot_list()          # List all snapshots
snapshot_restore()       # Restore from snapshot
snapshot_delete()        # Remove snapshot
snapshot_diff()          # Compare snapshots
```

**Data Structure**:
```
snapshots/
├── 2025-01-15-morning/
│   ├── metadata.json    # Timestamp, machine, description
│   ├── files.tar.gz.gpg # Encrypted archive
│   └── manifest.txt     # File listing
└── work-state/
    ├── metadata.json
    ├── files.tar.gz.gpg
    └── manifest.txt
```

#### `lib/conflict.sh`
**Purpose**: Conflict detection and resolution

**Functions**:
```bash
detect_conflicts()       # Find divergent files
show_conflict()          # Display conflict details
prompt_resolution()      # Interactive choice
apply_resolution()       # Execute user choice
merge_file()            # Attempt automatic merge
show_diff()             # Display differences
```

**Resolution Flow**:
```
Detect → Present Options → User Choice → Apply → Verify → Log
```

#### `lib/encryption.sh`
**Purpose**: Encryption and decryption operations

**Functions**:
```bash
encrypt_file()           # Encrypt single file
decrypt_file()           # Decrypt single file
encrypt_archive()        # Encrypt backup archive
decrypt_archive()        # Decrypt backup archive
prompt_password()        # Securely get password
verify_encryption()      # Test encryption worked
```

**Implementation**:
```bash
# Using GPG
encrypt_file() {
    local file=$1
    local output=$2

    # Prompt for password
    read -s -p "Enter encryption password: " password
    echo

    # Encrypt with AES256
    echo "$password" | gpg --batch --yes --passphrase-fd 0 \
        --symmetric --cipher-algo AES256 \
        --output "$output" "$file"
}
```

#### `lib/utils.sh`
**Purpose**: Shared utility functions

**Functions**:
```bash
log_info()               # Info logging
log_warn()               # Warning logging
log_error()              # Error logging
confirm_action()         # Interactive confirmation
get_hostname()           # Machine identification
get_timestamp()          # Timestamp generation
colorize()               # Terminal colors
validate_path()          # Path validation
check_dependencies()     # Verify required tools
```

---

### 3. Storage Backend Abstraction

```bash
# lib/storage.sh - Storage backend interface

# Generic storage operations
storage_init()           # Initialize storage backend
storage_save()           # Save to storage
storage_load()           # Load from storage
storage_list()           # List stored backups
storage_delete()         # Remove backup

# Backend-specific implementations
storage_git_*()          # Git operations
storage_local_*()        # Local filesystem
storage_ssh_*()          # SSH/rsync
```

**Backend: Git**
```bash
storage_git_init() {
    git clone "$repo_url" ~/.claude-sync/git-remote
}

storage_git_save() {
    cd ~/.claude-sync/git-remote
    cp "$backup_file" .
    git add .
    git commit -m "Backup from $(hostname) - $(date)"
    git push origin main
}

storage_git_load() {
    cd ~/.claude-sync/git-remote
    git pull origin main
}
```

**Backend: Local**
```bash
storage_local_save() {
    cp "$backup_file" ~/.claude-sync/storage/current/
}

storage_local_load() {
    cp ~/.claude-sync/storage/current/"$backup_file" .
}
```

**Backend: SSH/Direct**
```bash
storage_ssh_save() {
    local remote=$1
    rsync -avz --progress "$backup_file" "$remote:~/.claude-sync/incoming/"
}

storage_ssh_load() {
    local remote=$1
    rsync -avz --progress "$remote:~/.claude-sync/storage/current/" .
}
```

---

## Data Flow

### Backup Flow

```
┌─────────────┐
│ User Input  │
│ $ backup    │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│ Collect Config Files│
│ ~/.claude/*         │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Filter & Organize   │
│ Apply exclusions    │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Create Archive      │
│ tar czf backup.tgz  │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Encrypt Archive     │
│ gpg --symmetric     │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Store to Backend    │
│ git/local/ssh       │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Update Metadata     │
│ Log transaction     │
└─────────────────────┘
```

### Restore Flow

```
┌─────────────┐
│ User Input  │
│ $ restore   │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│ Fetch from Backend  │
│ git/local/ssh       │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Decrypt Archive     │
│ gpg --decrypt       │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Verify Integrity    │
│ Check checksums     │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Detect Conflicts    │
│ Compare with local  │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Resolve Conflicts   │
│ Interactive/Auto    │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Apply Overrides     │
│ @machine: markers   │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Extract to ~/.claude│
│ Update files        │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Log Transaction     │
└─────────────────────┘
```

### Sync Flow

```
┌─────────────┐
│ User Input  │
│ $ sync      │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│ Fetch Remote State  │
│ Pull from backend   │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Compare Local/Remote│
│ Detect differences  │
└──────┬──────────────┘
       │
       ├──── No Changes ────┐
       │                    │
       ▼                    ▼
┌─────────────────────┐   Exit
│ Detect Conflicts?   │
└──────┬──────────────┘
       │
       ├── Yes ──┐
       │         ▼
       │    ┌─────────────────────┐
       │    │ Resolve Conflicts   │
       │    │ Interactive prompts │
       │    └──────┬──────────────┘
       │           │
       ◄───────────┘
       │
       ▼
┌─────────────────────┐
│ Merge Changes       │
│ Apply resolutions   │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Push to Backend     │
│ Update remote       │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Update Local        │
│ Apply remote changes│
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Log Sync Complete   │
└─────────────────────┘
```

---

## File Organization

### Project Structure

```
claude-sync/
├── bin/
│   └── claude-sync              # Main CLI entry point
│
├── lib/
│   ├── backup.sh               # Backup operations
│   ├── restore.sh              # Restore operations
│   ├── sync.sh                 # Synchronization
│   ├── snapshot.sh             # Snapshot management
│   ├── conflict.sh             # Conflict resolution
│   ├── encryption.sh           # Encryption/decryption
│   ├── storage.sh              # Storage backend abstraction
│   └── utils.sh                # Shared utilities
│
├── config/
│   ├── default.conf            # Default configuration
│   └── machines.conf.example   # Machine registry example
│
├── docs/
│   ├── README.md               # User documentation
│   ├── INSTALL.md              # Installation guide
│   ├── USAGE.md                # Usage examples
│   └── TROUBLESHOOTING.md      # Common issues
│
├── tests/
│   ├── test_backup.sh          # Backup tests
│   ├── test_restore.sh         # Restore tests
│   ├── test_encryption.sh      # Encryption tests
│   └── test_conflict.sh        # Conflict tests
│
├── install.sh                   # Installation script
├── uninstall.sh                # Uninstallation script
├── LICENSE                     # License file
└── README.md                   # Project overview
```

### User Data Structure

```
~/.claude-sync/
├── config/
│   ├── sync.conf              # User preferences
│   ├── machines.conf          # Registered machines
│   └── encryption.conf        # Encryption settings
│
├── storage/
│   ├── current/               # Latest backup mirror
│   │   ├── CLAUDE.md
│   │   ├── RULES.md
│   │   ├── MODE_*.md
│   │   ├── commands/
│   │   │   └── *.md
│   │   └── mcp-config/
│   │       └── *.json
│   │
│   └── snapshots/             # Versioned backups
│       ├── 2025-01-15-0830/
│       │   ├── metadata.json
│       │   ├── backup.tar.gz.gpg
│       │   └── manifest.txt
│       └── pre-experiment/
│           ├── metadata.json
│           ├── backup.tar.gz.gpg
│           └── manifest.txt
│
├── git-remote/                # Git sync backend (if enabled)
│   └── [git repository]
│
├── logs/
│   ├── sync.log              # Sync operations
│   ├── conflicts.log         # Conflict resolutions
│   └── errors.log            # Error tracking
│
└── tmp/                      # Temporary files
    └── [transient data]
```

---

## Configuration File Formats

### `~/.claude-sync/config/sync.conf`

```bash
# claude-sync configuration

# Storage backend (git|local|ssh)
SYNC_BACKEND="git"

# Git repository URL (if using git backend)
GIT_REPO_URL="git@github.com:user/claude-configs.git"

# SSH remote (if using ssh backend)
SSH_REMOTE="user@remote-host"

# Encryption cipher
ENCRYPTION_CIPHER="AES256"

# Default backup mode (full|selective)
DEFAULT_BACKUP_MODE="full"

# Auto-push on backup (true|false)
AUTO_PUSH="true"

# Conflict resolution strategy (interactive|auto)
CONFLICT_STRATEGY="interactive"

# Verbose output by default (true|false)
VERBOSE="false"

# Color output (true|false)
COLOR_OUTPUT="true"

# Log level (debug|info|warn|error)
LOG_LEVEL="info"
```

### `~/.claude-sync/config/machines.conf`

```bash
# Registered machines

[work-laptop]
hostname=work-laptop
last_sync=2025-01-15T14:30:00Z
sync_backend=git
preferences=auto_push:true,verbose:false

[home-desktop]
hostname=home-desktop
last_sync=2025-01-15T16:45:00Z
sync_backend=git
preferences=auto_push:true,verbose:true

[server]
hostname=server
last_sync=2025-01-14T10:00:00Z
sync_backend=ssh
ssh_host=server.example.com
preferences=auto_push:false,verbose:false
```

### `snapshots/[name]/metadata.json`

```json
{
  "name": "pre-experiment",
  "timestamp": "2025-01-15T14:30:00Z",
  "machine": "work-laptop",
  "description": "Before trying new MCP configuration",
  "files_count": 15,
  "size_bytes": 45678,
  "checksum": "sha256:abc123...",
  "encryption": "AES256",
  "categories": ["global-configs", "mcp", "commands"]
}
```

---

## Security Model

### Threat Model

**Protected Against**:
- ✅ Unauthorized access to backups (encryption)
- ✅ Backup tampering (checksums)
- ✅ Accidental data loss (snapshots)
- ✅ Network interception (SSH/HTTPS)
- ✅ Credential exposure (no stored passwords)

**Not Protected Against**:
- ❌ Physical access to unlocked machine
- ❌ Compromised SSH keys
- ❌ Password guessing (user responsibility)
- ❌ Malicious code in configs (manual review needed)

### Encryption Details

```bash
# Encryption: AES-256-GCM via GPG
gpg --symmetric --cipher-algo AES256 \
    --s2k-mode 3 \               # Iterated/salted S2K
    --s2k-count 65011712 \       # Maximum iterations
    --s2k-digest-algo SHA512 \   # Strong hash
    --compress-algo ZLIB \       # Compression
    --output backup.gpg \
    backup.tar.gz

# Decryption
gpg --decrypt backup.gpg > backup.tar.gz
```

### Access Control

```bash
# File permissions
chmod 700 ~/.claude-sync          # Owner only
chmod 600 ~/.claude-sync/config/* # Owner read/write only
chmod 600 ~/.claude-sync/logs/*   # Owner read/write only

# Git repository
# Must be private repository
# SSH key authentication required
# No public access allowed
```

---

## Performance Considerations

### Optimization Strategies

1. **Incremental Backups** (future enhancement)
   - Only backup changed files
   - Reduce backup size and time
   - Track file modification times

2. **Compression**
   - Use `gzip` for archives (fast)
   - Level 6 compression (balance speed/size)
   - Exclude already-compressed files

3. **Parallel Operations**
   - Encrypt files in parallel
   - Use `xargs -P` for batch operations
   - Background git operations

4. **Caching**
   - Cache conflict resolution decisions
   - Store checksums for quick comparison
   - Cache machine states

### Performance Targets

| Operation | Target Time | Notes |
|-----------|-------------|-------|
| Full backup | < 5 seconds | Typical ~/.claude size |
| Full restore | < 10 seconds | Includes conflict check |
| Sync | < 15 seconds | Network dependent |
| Snapshot create | < 3 seconds | Copy operation |
| Conflict detection | < 2 seconds | File comparison |

---

## Error Handling

### Error Handling Strategy

```bash
# Global error trap
set -euo pipefail
trap 'error_handler $? $LINENO' ERR

error_handler() {
    local exit_code=$1
    local line_num=$2

    log_error "Error $exit_code at line $line_num"
    cleanup_temp_files
    exit $exit_code
}
```

### Failure Scenarios

| Scenario | Detection | Recovery |
|----------|-----------|----------|
| Encryption fails | Exit code check | Retry, log error |
| Network timeout | SSH timeout | Retry with backoff |
| Disk full | `df` check before write | Warn user, abort |
| Corrupt backup | Checksum mismatch | Restore from snapshot |
| Git conflict | Merge failure | Interactive resolution |
| Missing dependencies | Command existence | Install prompt |

---

## Testing Architecture

### Test Structure

```bash
tests/
├── test_backup.sh              # Backup functionality
├── test_restore.sh             # Restore functionality
├── test_sync.sh                # Sync operations
├── test_encryption.sh          # Encryption/decryption
├── test_conflict.sh            # Conflict resolution
├── test_snapshot.sh            # Snapshot management
├── test_integration.sh         # End-to-end workflows
└── helpers/
    ├── setup_test_env.sh       # Test environment setup
    ├── cleanup_test_env.sh     # Cleanup after tests
    └── assertions.sh           # Test assertions
```

### Test Coverage Goals

- **Unit Tests**: 80%+ coverage of functions
- **Integration Tests**: All major workflows
- **Edge Cases**: Conflict scenarios, failures
- **Performance Tests**: Timing benchmarks

---

## Extension Points

### Custom Backends

```bash
# lib/storage_custom.sh

storage_custom_init() {
    # Initialize custom backend
}

storage_custom_save() {
    # Save to custom backend
}

storage_custom_load() {
    # Load from custom backend
}

# Register backend
register_backend "custom" "storage_custom"
```

### Custom Filters

```bash
# lib/filters/exclude_patterns.sh

apply_custom_filter() {
    local file=$1

    # Custom filtering logic
    if [[ "$file" == *"secret"* ]]; then
        return 1  # Exclude
    fi

    return 0  # Include
}
```

### Hooks

```bash
# Pre/post backup hooks
~/.claude-sync/hooks/pre-backup.sh
~/.claude-sync/hooks/post-backup.sh

# Pre/post restore hooks
~/.claude-sync/hooks/pre-restore.sh
~/.claude-sync/hooks/post-restore.sh
```

---

**Document Version**: 1.0
**Last Updated**: 2025-01-15
