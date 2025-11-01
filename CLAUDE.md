# CLAUDE.md

Project-specific guidance for Claude Code when working on the **claude-code-sync** repository.

---

## Project Overview

**claude-code-sync** is a CLI utility for backing up, restoring, and synchronizing Claude Code configurations across multiple Ubuntu machines. The tool provides encrypted backups, multiple sync strategies (git, manual, SSH direct), and intelligent conflict resolution.

### Key Technologies
- **Language**: Bash (v4.0+)
- **Platform**: Ubuntu (all flavors)
- **Encryption**: GPG (AES-256-GCM)
- **Sync Backends**: Git, SSH/rsync, local filesystem
- **Dependencies**: `gpg`, `tar`, `gzip`, `sha256sum`, `jq`, `rsync`, `git`

---

## Project Structure

```
claude-code-sync/
├── bin/
│   └── claude-code-sync              # Main CLI executable
├── lib/
│   ├── utils.sh                # Logging, utilities, helpers
│   ├── encryption.sh           # Encryption/decryption engine
│   ├── backup.sh               # Backup operations
│   ├── restore.sh              # Restore operations
│   ├── conflict.sh             # Conflict detection/resolution
│   ├── snapshot.sh             # Snapshot management
│   ├── sync.sh                 # Synchronization logic
│   └── storage.sh              # Storage backend abstraction
├── config/
│   └── default.conf            # Default configuration template
├── docs/
│   └── [user documentation]
├── tests/
│   └── [test suite]
└── claudedocs/
    ├── PROJECT_SPECIFICATION.md       # Complete requirements
    ├── ARCHITECTURE.md                # System design
    ├── IMPLEMENTATION_ROADMAP.md      # Implementation guide
    └── QUICK_START.md                # Getting started
```

---

## Development Guidelines

### Code Style

**Bash Best Practices**:
- Use `set -euo pipefail` at the start of all scripts
- Always quote variables: `"$variable"`
- Use `readonly` for constants
- Prefer functions over inline code
- Use descriptive function and variable names

**Naming Conventions**:
- Functions: `snake_case` (e.g., `backup_full`, `encrypt_file`)
- Variables: `snake_case` (e.g., `backup_dir`, `encrypted_file`)
- Constants: `UPPER_SNAKE_CASE` (e.g., `CIPHER_ALGO`, `SYNC_DIR`)
- Private functions: prefix with `_` (e.g., `_internal_helper`)

**Function Structure**:
```bash
function_name() {
    local param1="$1"
    local param2="${2:-default}"

    # Validation
    [ -z "$param1" ] && log_error "param1 required"

    # Implementation
    log_info "Performing action"

    # Return
    return 0
}
```

### Security Considerations

**Critical Rules**:
- ✅ Never store passwords in variables or files
- ✅ Always use `read -s` for password prompts
- ✅ Always pipe passwords directly to GPG stdin
- ✅ Set file permissions to 600/700 for sensitive data
- ✅ Clean up temporary files in error handlers
- ✅ Use trap for cleanup: `trap 'rm -rf "$TMP_DIR"' EXIT`

**Password Handling**:
```bash
# CORRECT
echo "$password" | gpg --batch --passphrase-fd 0 ...

# WRONG - password exposed in process list
gpg --passphrase "$password" ...
```

**File Permissions**:
```bash
chmod 700 ~/.claude-code-sync           # Owner only
chmod 600 ~/.claude-code-sync/config/*  # Owner read/write
```

### Error Handling

**Global Error Trap**:
```bash
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

**Validation Pattern**:
```bash
validate_inputs() {
    [ ! -f "$file" ] && log_error "File not found: $file"
    [ ! -d "$dir" ] && log_error "Directory not found: $dir"
    command -v gpg &>/dev/null || log_error "gpg not installed"
}
```

---

## Module Responsibilities

### `lib/utils.sh`
**Purpose**: Shared utilities and logging

**Key Functions**:
- `log_info()`, `log_warn()`, `log_error()` - Logging with colors
- `confirm_action()` - Interactive Y/n prompts
- `get_hostname()` - Machine identification
- `get_timestamp()` - ISO 8601 timestamps
- `check_dependencies()` - Verify required tools
- `ensure_directory()` - Create dir with proper permissions

**Never Modify**: Logging format (other modules depend on it)

### `lib/encryption.sh`
**Purpose**: Encryption/decryption engine

**Key Functions**:
- `prompt_password()` - Secure password input with confirmation
- `encrypt_file()`, `decrypt_file()` - Single file encryption
- `encrypt_archive()`, `decrypt_archive()` - Archive encryption
- `generate_checksum()`, `verify_checksum()` - Integrity validation

**Security Critical**: All password handling must be secure

### `lib/backup.sh`
**Purpose**: Backup operations

**Key Functions**:
- `backup_init()` - Initialize `~/.claude-code-sync/` structure
- `backup_full()` - Full backup workflow
- `collect_config_files()` - Gather from `~/.claude/`
- `create_archive()` - Package files into tar.gz

**Target Directory**: `~/.claude/` (Claude Code configuration)

### `lib/restore.sh`
**Purpose**: Restore operations

**Key Functions**:
- `restore_full()` - Full restore workflow
- `verify_backup()` - Integrity checking
- `detect_conflicts()` - Find divergent files
- `apply_restore()` - Copy files to `~/.claude/`

**Safety**: Always detect conflicts before overwriting

### `lib/conflict.sh`
**Purpose**: Conflict detection and resolution

**Key Functions**:
- `detect_conflicts()` - Compare backup vs current
- `show_conflict()` - Display conflict details
- `prompt_resolution()` - Interactive choice
- `apply_resolution()` - Execute user choice

**UX Critical**: Clear, helpful conflict prompts

### `lib/snapshot.sh`
**Purpose**: Versioned snapshot management

**Key Functions**:
- `snapshot_create()` - Create named snapshot
- `snapshot_list()` - List all snapshots
- `snapshot_restore()` - Restore from snapshot
- `snapshot_delete()` - Remove snapshot

**Metadata**: JSON format in `metadata.json`

### `lib/sync.sh`
**Purpose**: Synchronization logic

**Key Functions**:
- `sync_git()` - Git-based sync
- `sync_direct()` - SSH/rsync sync
- `detect_changes()` - Find differences
- `merge_configs()` - Combine changes

**Phase**: Implemented in Phase 2+

### `lib/storage.sh`
**Purpose**: Storage backend abstraction

**Key Functions**:
- `storage_init()` - Initialize backend
- `storage_save()` - Save to storage
- `storage_load()` - Load from storage
- Backend-specific: `storage_git_*()`, `storage_ssh_*()`

**Phase**: Implemented in Phase 2+

---

## Testing Strategy

### Unit Tests
Each module has corresponding test file in `tests/`:
- `tests/test_utils.sh` → `lib/utils.sh`
- `tests/test_encryption.sh` → `lib/encryption.sh`
- `tests/test_backup.sh` → `lib/backup.sh`
- `tests/test_restore.sh` → `lib/restore.sh`

### Test Structure
```bash
#!/bin/bash
source lib/module.sh

test_function_name() {
    # Setup
    local test_file="/tmp/test-$$"

    # Execute
    function_name "$test_file"

    # Assert
    [ -f "$test_file" ] && echo "✓ Test passed"

    # Cleanup
    rm -f "$test_file"
}

# Run tests
test_function_name
```

### Manual Testing Workflow
```bash
# 1. Test initialization
./bin/claude-code-sync init

# 2. Test dry-run
./bin/claude-code-sync backup --dry-run

# 3. Test actual backup
./bin/claude-code-sync backup

# 4. Verify files created
ls -lh ~/.claude-code-sync/storage/current/

# 5. Test restore dry-run
./bin/claude-code-sync restore --dry-run

# 6. Test status
./bin/claude-code-sync status
```

---

## Implementation Phases

### Phase 1: Core Backup/Restore (Current)
**Status**: In Progress
**Timeline**: Week 1-2

**Deliverables**:
- [x] Project structure created
- [x] Documentation complete
- [ ] `lib/utils.sh` implemented
- [ ] `lib/encryption.sh` implemented
- [ ] `lib/backup.sh` implemented
- [ ] `lib/restore.sh` implemented
- [ ] `lib/conflict.sh` implemented
- [ ] `bin/claude-code-sync` CLI working
- [ ] Tests passing
- [ ] Manual testing complete

**Success Criteria**:
- `claude-code-sync backup` creates encrypted backup
- `claude-code-sync restore` restores files
- Conflicts detected correctly
- All tests pass

### Phase 2: Git Integration
**Status**: Not Started
**Timeline**: Week 3

**Scope**:
- Git repository initialization
- Auto-commit/push on backup
- Pull/merge on restore
- Remote synchronization

### Phase 3: Snapshots
**Status**: Not Started
**Timeline**: Week 4

**Scope**:
- Named snapshots
- Snapshot listing
- Snapshot restore
- Snapshot comparison

### Phase 4: Direct Sync
**Status**: Not Started
**Timeline**: Week 5

**Scope**:
- SSH/rsync integration
- Machine-to-machine sync
- Bidirectional synchronization

### Phase 5: Polish
**Status**: Not Started
**Timeline**: Week 6-7

**Scope**:
- Machine-specific overrides
- Production hardening
- Complete documentation
- Installation script

---

## Common Tasks

### Adding a New Function

1. **Add to appropriate module**:
```bash
# lib/backup.sh
new_backup_feature() {
    local param="$1"
    log_info "Performing new feature"
    # Implementation
}
```

2. **Add test**:
```bash
# tests/test_backup.sh
test_new_backup_feature() {
    new_backup_feature "test"
    [ $? -eq 0 ] && echo "✓ Test passed"
}
```

3. **Update documentation**:
- Update function list in this file
- Add usage example to README.md
- Update ARCHITECTURE.md if significant

### Adding a New Command

1. **Add command handler**:
```bash
# bin/claude-code-sync
cmd_newcommand() {
    parse_global_flags "$@"
    # Implementation
}
```

2. **Add to dispatcher**:
```bash
case $command in
    # ... existing commands ...
    newcommand)
        cmd_newcommand "$@"
        ;;
esac
```

3. **Update help**:
```bash
show_help() {
    cat <<EOF
Commands:
    ...
    newcommand          Description of new command
EOF
}
```

### Debugging

**Enable verbose logging**:
```bash
# Temporarily add to script
set -x  # Print each command
```

**Check logs**:
```bash
tail -f ~/.claude-code-sync/logs/sync.log
tail -f ~/.claude-code-sync/logs/errors.log
```

**Test encryption manually**:
```bash
echo "test" > test.txt
echo "password" | gpg --batch --passphrase-fd 0 --symmetric test.txt
echo "password" | gpg --batch --passphrase-fd 0 --decrypt test.txt.gpg
```

---

## Key Architecture Patterns

### Storage Backend Abstraction
```bash
# Generic interface
storage_save "$file"

# Dispatches to:
storage_git_save "$file"      # Git backend
storage_local_save "$file"    # Local backend
storage_ssh_save "$file"      # SSH backend
```

### Error Handling
```bash
# Always validate inputs
validate_inputs() {
    [ -z "$required_param" ] && log_error "Missing parameter"
}

# Use trap for cleanup
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT
```

### Configuration Management
```bash
# Load config
source "$HOME/.claude-code-sync/config/sync.conf"

# Use defaults
BACKUP_MODE="${BACKUP_MODE:-full}"
```

---

## Documentation References

**For detailed information, see**:
- `claudedocs/PROJECT_SPECIFICATION.md` - Complete requirements
- `claudedocs/ARCHITECTURE.md` - System design and data flows
- `claudedocs/IMPLEMENTATION_ROADMAP.md` - Step-by-step implementation
- `claudedocs/QUICK_START.md` - Getting started guide

---

## Working with This Project

### When Starting Work
1. Review current phase status in IMPLEMENTATION_ROADMAP.md
2. Check recent commits: `git log --oneline -5`
3. Run tests to ensure working state: `./tests/run_all_tests.sh`

### When Implementing Features
1. Read specification in PROJECT_SPECIFICATION.md
2. Review architecture in ARCHITECTURE.md
3. Follow implementation steps in IMPLEMENTATION_ROADMAP.md
4. Write tests alongside implementation
5. Update documentation as needed

### When Debugging Issues
1. Check logs in `~/.claude-code-sync/logs/`
2. Enable verbose mode: `--verbose`
3. Use dry-run mode: `--dry-run`
4. Review error handling in code
5. Verify dependencies installed

### Before Committing
1. Run all tests: `./tests/run_all_tests.sh`
2. Test manually: basic backup and restore workflow
3. Update documentation if APIs changed
4. Write descriptive commit message
5. Review security implications

---

## Git Workflow

**Branch Naming**:
- `feature/phase-1-backup` - Feature branches
- `fix/encryption-password` - Bug fixes
- `docs/update-readme` - Documentation

**Commit Messages**:
```
feat(backup): implement collect_config_files()
fix(encryption): handle password with special chars
docs(readme): add installation instructions
test(restore): add conflict detection tests
```

---

## Questions & Help

**When stuck on implementation**:
1. Check IMPLEMENTATION_ROADMAP.md for code examples
2. Review ARCHITECTURE.md for design patterns
3. Look at existing module implementations
4. Ask: "Help me implement [specific function]"

**When encountering errors**:
1. Check error logs
2. Verify dependencies installed
3. Test encryption/decryption manually
4. Review security best practices

**When planning new features**:
1. Review PROJECT_SPECIFICATION.md for requirements
2. Check if feature belongs to current phase
3. Consider backward compatibility
4. Plan testing strategy first

---

**Last Updated**: 2025-01-15
**Current Phase**: Phase 1 - Core Backup/Restore
**Status**: In Progress
