# claude-code-sync: Quick Start Guide

Get your CLI configuration management tool up and running in minutes.

---

## What You're Building

**claude-code-sync** is a comprehensive CLI utility that will:
- 🔐 **Backup** your Claude Code configs with full encryption
- 🔄 **Sync** across multiple Ubuntu machines (git, manual, or direct)
- 📦 **Restore** with intelligent conflict resolution
- 📸 **Snapshot** for versioned restore points
- 🛡️ **Secure** everything with AES-256 encryption

---

## Your Answers Summary

From our interactive brainstorming session, here's what you want:

### Sync Methods
- ✅ **Git repository** (auto-commit/push workflow)
- ✅ **Manual export/import** (encrypted file transfer)
- ✅ **Direct machine-to-machine** (SSH/rsync)

### Configuration Scope
- ✅ Global configs (`~/.claude/` - CLAUDE.md, RULES.md, MODE_*.md)
- ✅ MCP server configurations
- ✅ Custom slash commands (`/sc:*`)

### Security & UX
- 🔐 **Full encryption** with password prompt each time
- 🤝 **Interactive conflict resolution**
- 🏷️ **Hostname-based** machine identification
- 📝 **Comment-based overrides** (`# @machine:hostname`)

### Features & Flexibility
- All granularity levels (full, selective, files, snapshots)
- Simple CLI verbs + interactive prompts + dry-run + verbosity
- Hybrid storage (current mirror + versioned snapshots)
- Build all sync methods equally (no MVP limitations)

---

## Project Structure Overview

```
claude-code-sync/
├── bin/claude-code-sync              # Main CLI executable
├── lib/                        # Core modules
│   ├── backup.sh              # Backup operations
│   ├── restore.sh             # Restore operations
│   ├── sync.sh                # Synchronization
│   ├── snapshot.sh            # Snapshot management
│   ├── conflict.sh            # Conflict resolution
│   ├── encryption.sh          # Encryption engine
│   ├── storage.sh             # Storage backends
│   └── utils.sh               # Utilities
├── config/                     # Configuration templates
├── docs/                       # User documentation
├── tests/                      # Test suite
└── claudedocs/                # Development docs
    ├── PROJECT_SPECIFICATION.md      # Full spec
    ├── ARCHITECTURE.md               # System design
    ├── IMPLEMENTATION_ROADMAP.md     # Step-by-step guide
    └── QUICK_START.md               # This file
```

---

## First Steps (Start Here!)

### Step 1: Set Up Project Structure (5 minutes)

```bash
# You're already in the project directory
cd ~/projects/claude-code-sync

# Create directory structure
mkdir -p bin lib config docs tests

# Create main files
touch bin/claude-code-sync
chmod +x bin/claude-code-sync

# Create library modules
touch lib/{utils,encryption,backup,restore,conflict,snapshot,sync,storage}.sh

# Create config templates
touch config/default.conf

# Initialize git
git init
git add .
git commit -m "Initial project structure"
```

### Step 2: Implement Core Utilities (Day 1)

**File**: `lib/utils.sh`

Start with essential logging and utility functions:
- `log_info()`, `log_warn()`, `log_error()`
- `confirm_action()` - interactive Y/n prompts
- `get_hostname()` - machine identification
- `check_dependencies()` - verify gpg, tar, etc.

**See**: `claudedocs/IMPLEMENTATION_ROADMAP.md` Step 1.2 for complete code

### Step 3: Implement Encryption (Day 1-2)

**File**: `lib/encryption.sh`

Core security functions:
- `prompt_password()` - secure password input
- `encrypt_file()`, `decrypt_file()` - AES-256-GCM via GPG
- `generate_checksum()`, `verify_checksum()` - integrity validation

**See**: `claudedocs/IMPLEMENTATION_ROADMAP.md` Step 1.3 for complete code

### Step 4: Implement Backup (Day 2-3)

**File**: `lib/backup.sh`

Core backup workflow:
- `backup_init()` - create `~/.claude-code-sync/` structure
- `collect_config_files()` - gather from `~/.claude/`
- `backup_full()` - complete backup → encrypt → store workflow

**See**: `claudedocs/IMPLEMENTATION_ROADMAP.md` Step 1.4 for complete code

### Step 5: Implement Restore (Day 3-4)

**File**: `lib/restore.sh`

Restore workflow:
- `restore_full()` - decrypt → verify → restore → apply workflow
- `detect_conflicts()` - find divergent files
- `verify_backup()` - integrity checking

**See**: `claudedocs/IMPLEMENTATION_ROADMAP.md` Step 1.5 for complete code

### Step 6: Build Main CLI (Day 4-5)

**File**: `bin/claude-code-sync`

CLI interface:
- Command parsing and routing
- Global flags (`--dry-run`, `--verbose`, etc.)
- Help and usage information
- Command dispatcher

**See**: `claudedocs/IMPLEMENTATION_ROADMAP.md` Step 1.7 for complete code

---

## Testing Your Work

### Manual Testing Workflow

```bash
# 1. Initialize backup system
./bin/claude-code-sync init

# 2. Test dry-run backup
./bin/claude-code-sync backup --dry-run

# 3. Test actual backup (will prompt for password)
./bin/claude-code-sync backup

# 4. Verify backup created
ls -lh ~/.claude-code-sync/storage/current/

# 5. Test dry-run restore
./bin/claude-code-sync restore --dry-run

# 6. Test actual restore (in safe test environment!)
./bin/claude-code-sync restore

# 7. Check status
./bin/claude-code-sync status
```

### Unit Testing

```bash
# Run individual test suites
./tests/test_utils.sh
./tests/test_encryption.sh
./tests/test_backup.sh
./tests/test_restore.sh

# Run all tests
./tests/run_all_tests.sh
```

---

## Phase 1 Deliverables (MVP - Week 1-2)

By the end of Phase 1, you'll have:

✅ Working CLI tool (`claude-code-sync backup/restore/status`)
✅ Full encrypted backup of `~/.claude/`
✅ Restore with conflict detection
✅ Interactive password prompts
✅ Local storage in `~/.claude-code-sync/`
✅ Dry-run mode for safety
✅ Basic documentation

**This is a fully functional local backup tool!**

---

## After Phase 1

### Phase 2: Git Integration (Week 3)
Add automatic git repository sync:
- `claude-code-sync init --git <repo-url>`
- Auto-commit and push on backup
- Pull and merge on restore
- Remote repository synchronization

### Phase 3: Snapshots (Week 4)
Add versioned restore points:
- `claude-code-sync snapshot create "pre-experiment"`
- `claude-code-sync snapshot list`
- `claude-code-sync snapshot restore "2025-01-15"`
- Named and timestamped snapshots

### Phase 4: Direct Sync (Week 5)
Add machine-to-machine sync:
- `claude-code-sync sync --remote user@work-laptop`
- Real-time SSH/rsync synchronization
- Bidirectional sync with conflict resolution

### Phase 5: Polish (Week 6-7)
Production-ready hardening:
- Machine-specific overrides (`# @machine:hostname`)
- Comprehensive error handling
- Complete documentation
- Installation script

---

## Key Commands Reference

### Once Implemented

```bash
# Initialization
claude-code-sync init [--git <repo>] [--local] [--all]

# Backup
claude-code-sync backup [--dry-run] [--verbose]
claude-code-sync backup --snapshot "before-experiment"

# Restore
claude-code-sync restore [--dry-run] [--interactive]
claude-code-sync restore --snapshot "2025-01-15"

# Sync (Phase 2+)
claude-code-sync sync [--git] [--remote user@host]

# Snapshots (Phase 3+)
claude-code-sync snapshot create <name>
claude-code-sync snapshot list
claude-code-sync snapshot restore <name>

# Status
claude-code-sync status
```

---

## Development Workflow

### Daily Routine

**Morning**:
1. Review yesterday's commits: `git log --oneline -5`
2. Check roadmap: `cat claudedocs/IMPLEMENTATION_ROADMAP.md`
3. Pick 1-2 functions to implement

**During Work**:
1. Write function in `lib/*.sh`
2. Write test in `tests/test_*.sh`
3. Run test: `./tests/test_*.sh`
4. Commit when working: `git commit -m "feat(module): description"`

**Evening**:
1. Review progress: `git diff main..HEAD --stat`
2. Push changes: `git push origin feature/current-work`
3. Update roadmap with completed checkboxes

---

## Resources

### Documentation

1. **PROJECT_SPECIFICATION.md** - Complete requirements and features
2. **ARCHITECTURE.md** - System design and data flows
3. **IMPLEMENTATION_ROADMAP.md** - Detailed step-by-step implementation guide
4. **QUICK_START.md** - This file (getting started)

### Code Examples

See `IMPLEMENTATION_ROADMAP.md` for:
- Complete function implementations
- Testing strategies
- Error handling patterns
- Security best practices

---

## Troubleshooting

### Common Issues

**Issue**: `gpg: command not found`
**Solution**: Install GPG: `sudo apt install gnupg`

**Issue**: Permission denied on `bin/claude-code-sync`
**Solution**: Make executable: `chmod +x bin/claude-code-sync`

**Issue**: `~/.claude` not found
**Solution**: Ensure Claude Code is installed and configured

**Issue**: Encryption fails with "bad password"
**Solution**: Verify password typing, consider longer password

---

## Next Action

**Right now, start with**:

```bash
# Create project structure
mkdir -p bin lib config docs tests

# Open implementation roadmap
cat claudedocs/IMPLEMENTATION_ROADMAP.md

# Start with Step 1.1: Project Setup
# Then proceed to Step 1.2: Utilities Module

# OR get help with implementation:
# "Help me implement lib/utils.sh from the roadmap"
```

---

## Questions to Consider

Before you start coding, think about:

1. **Development Environment**: Do you have all dependencies installed?
   - `gpg`, `tar`, `gzip`, `sha256sum`, `jq`, `rsync`

2. **Testing Strategy**: Will you test on a spare machine first?
   - Recommended: Test in VM or separate user account

3. **Git Repository**: Where will you host the remote git backend?
   - GitHub private repo? Self-hosted GitLab? Gitea?

4. **Password Management**: Have you chosen a strong master password?
   - Minimum 12 characters, memorable but secure

5. **Backup Frequency**: How often will you backup?
   - Manual? Scheduled with cron? On each major change?

---

## Success Criteria

You'll know Phase 1 is complete when:

- ✅ You can run `claude-code-sync backup` and see encrypted file created
- ✅ You can run `claude-code-sync restore` and configs are restored
- ✅ Password prompts work securely (no echo)
- ✅ Conflicts are detected and reported
- ✅ All tests pass without errors
- ✅ Documentation is clear enough for future you

---

## Get Started Now!

Pick one:

1. **Dive into coding**:
   ```bash
   # Start implementing from roadmap
   cat claudedocs/IMPLEMENTATION_ROADMAP.md
   vim lib/utils.sh
   ```

2. **Ask for help**:
   - "Help me implement the utils module"
   - "Walk me through encryption.sh implementation"
   - "How do I test the backup functionality?"

3. **Review specifications**:
   - Read `PROJECT_SPECIFICATION.md` for detailed requirements
   - Study `ARCHITECTURE.md` for system design
   - Follow `IMPLEMENTATION_ROADMAP.md` step-by-step

---

**Ready to build? Start with Step 1.1 in IMPLEMENTATION_ROADMAP.md!**

Good luck! 🚀
