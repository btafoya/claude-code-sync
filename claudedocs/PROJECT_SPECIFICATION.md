# claude-sync: CLI Configuration Management Tool

## Project Overview

A comprehensive CLI utility for backing up, restoring, and synchronizing Claude Code configurations across multiple Ubuntu machines. Supports multiple sync strategies with full encryption and intelligent conflict resolution.

---

## Requirements Summary

### User Context
- **Platform**: Ubuntu (all flavors)
- **Shell**: Bash scripting
- **Use Case**: Multiple computers requiring synchronized Claude Code configurations
- **Security Requirement**: Full encryption for all backups
- **Workflow**: Interactive conflict resolution with safety prompts

### Configuration Scope
The tool manages:
- ✅ Global configs (`~/.claude/` directory)
  - CLAUDE.md, RULES.md, PRINCIPLES.md, MODE_*.md files
  - Custom framework components
- ✅ MCP server configurations
  - Server settings, connections, authentication
  - serena, context7, magic, playwright, etc.
- ✅ Custom slash commands
  - `/sc:*` command definitions from `.claude/commands/`
- ❌ Project-specific `.claude/` directories (separate concern)

---

## Core Architecture

### Sync Strategy (Multi-Method Support)

**1. Git Repository Sync**
- Automatic commit and push workflow
- Remote repository (GitHub/GitLab/private)
- Version history and rollback capability
- **Workflow**: `backup` → auto-commit → auto-push to remote

**2. Manual Export/Import**
- Generate encrypted archive files
- Manual transfer via USB/network/cloud
- Full control over when and where
- **Workflow**: `export` → transfer file → `import` on target machine

**3. Direct Machine-to-Machine**
- SSH/rsync between online machines
- Real-time synchronization
- Requires network connectivity
- **Workflow**: `sync --remote user@hostname` → direct transfer

### Directory Structure

```
~/.claude-sync/                 # Tool's working directory
├── storage/                    # Backup storage
│   ├── current/               # Current mirror of ~/.claude/
│   │   ├── CLAUDE.md
│   │   ├── RULES.md
│   │   ├── MODE_*.md
│   │   ├── commands/
│   │   └── mcp-config/
│   └── snapshots/             # Versioned backups
│       ├── 2025-01-15-morning/
│       ├── 2025-01-15-evening/
│       ├── work-state/        # Named snapshots
│       └── pre-experiment/
│
├── config/
│   ├── machines.conf          # Machine registry
│   ├── sync.conf             # Sync preferences
│   └── encryption.conf       # Encryption settings
│
├── git-remote/               # Git sync backend (if used)
│   └── [git repository]
│
└── logs/
    ├── sync.log
    └── conflicts.log
```

### Machine Identification

**Hostname-Based Detection**
- Automatic detection via `hostname` command
- Machine profiles stored in `machines.conf`
- Format: `[hostname] = { last_sync, preferences }`

**Machine-Specific Overrides**
- Comment-based markers in configuration files
- Syntax: `# @machine:hostname` or `# @machine:work-laptop`
- Example:
```bash
# Global setting for all machines
export CLAUDE_MODE="production"

# @machine:work-laptop
export CLAUDE_DEBUG="true"

# @machine:home-desktop
export CLAUDE_THEME="dark"
```

---

## Encryption Strategy

### Full Encryption Approach
- **What**: All backup content encrypted
- **Algorithm**: AES-256-GCM (via `gpg` or `openssl`)
- **Key Management**: Prompt for password on each operation
- **Rationale**: Maximum security, no key storage risk

### Implementation
```bash
# Encryption
tar czf - ~/.claude | gpg --symmetric --cipher-algo AES256 > backup.tar.gz.gpg

# Decryption
gpg --decrypt backup.tar.gz.gpg | tar xzf -
```

### Password Requirements
- Minimum 12 characters recommended
- Prompted interactively (via `read -s`)
- Not stored anywhere (enter each operation)
- Same password across all machines for sync

---

## Conflict Resolution

### Interactive Resolution Workflow

**1. Conflict Detection**
- Compare file timestamps and checksums
- Identify divergent content
- Present conflicts to user

**2. Resolution Options**
```
Conflict detected: CLAUDE.md
  Local:  Modified 2025-01-15 14:30 (work-laptop)
  Remote: Modified 2025-01-15 16:45 (home-desktop)

Choose action:
  [1] Keep local version
  [2] Keep remote version
  [3] Show diff and decide
  [4] Manual merge (open editor)
  [5] Skip this file
  [q] Quit without changes

Your choice:
```

**3. Machine Override Application**
- After base merge, apply `# @machine:hostname` overrides
- Preserve machine-specific customizations
- Log override applications

---

## Granularity Options

### 1. Full Backup/Restore
```bash
claude-sync backup --full
claude-sync restore --full
```
All-or-nothing operation, simplest workflow.

### 2. Selective by Category
```bash
claude-sync backup --include mcp,commands
claude-sync restore --only global-configs
```
Choose: `global-configs`, `mcp`, `commands`, or combinations.

### 3. Individual File Selection
```bash
claude-sync backup --files CLAUDE.md,MODE_Brainstorming.md
claude-sync restore --select
```
Interactive file picker or explicit file list.

### 4. Versioned Snapshots
```bash
claude-sync snapshot create "pre-experiment"
claude-sync snapshot list
claude-sync snapshot restore "2025-01-15-morning"
```
Named or timestamped restore points, like git tags.

---

## Command-Line Interface

### Core Commands

#### `claude-sync init`
Initialize the tool with sync backend setup.

```bash
claude-sync init [--git <repo-url>] [--local] [--remote <user@host>]

Options:
  --git <url>         Initialize git repository sync
  --local            Local-only backups (manual export)
  --remote <ssh>     Configure direct machine sync
  --all              Enable all sync methods

Examples:
  claude-sync init --git git@github.com:user/claude-configs.git
  claude-sync init --local
  claude-sync init --all
```

#### `claude-sync backup`
Create encrypted backup of configurations.

```bash
claude-sync backup [options]

Options:
  --full                    Backup everything (default)
  --include <categories>    mcp,commands,global-configs
  --files <file-list>       Specific files to backup
  --snapshot <name>         Create named snapshot
  -n, --dry-run            Show what would be backed up
  -v, --verbose            Detailed output
  -q, --quiet              Minimal output

Examples:
  claude-sync backup
  claude-sync backup --include mcp,commands
  claude-sync backup --snapshot "before-update" --verbose
  claude-sync backup --files CLAUDE.md,RULES.md --dry-run
```

#### `claude-sync restore`
Restore configurations from backup.

```bash
claude-sync restore [options]

Options:
  --full                    Restore everything
  --only <categories>       Restore specific categories
  --files <file-list>       Restore specific files
  --snapshot <name>         Restore from named snapshot
  --machine <hostname>      Restore from specific machine's backup
  -n, --dry-run            Preview restore without applying
  -i, --interactive        Interactive conflict resolution
  -f, --force              Overwrite without prompts
  -v, --verbose            Detailed output

Examples:
  claude-sync restore --dry-run
  claude-sync restore --only mcp --interactive
  claude-sync restore --snapshot "2025-01-15-morning"
  claude-sync restore --machine work-laptop --verbose
```

#### `claude-sync sync`
Bidirectional synchronization.

```bash
claude-sync sync [options]

Options:
  --remote <user@host>     Direct machine-to-machine sync
  --git                    Sync via git repository
  --strategy <method>      merge|interactive (default: interactive)
  -n, --dry-run           Show what would change
  -v, --verbose           Detailed output

Examples:
  claude-sync sync --git
  claude-sync sync --remote user@work-laptop
  claude-sync sync --strategy merge --dry-run
```

#### `claude-sync export / import`
Manual file-based transfer.

```bash
claude-sync export [options] <output-file>
claude-sync import [options] <input-file>

Export Options:
  --include <categories>   What to export
  -v, --verbose           Show export process

Import Options:
  --preview               Show contents before importing
  -i, --interactive       Interactive conflict resolution
  -v, --verbose           Show import process

Examples:
  claude-sync export --include all claude-backup.enc
  claude-sync import --preview claude-backup.enc
  claude-sync import --interactive claude-backup.enc
```

#### `claude-sync snapshot`
Manage versioned snapshots.

```bash
claude-sync snapshot <command> [options]

Commands:
  create <name>          Create named snapshot
  list                   List all snapshots
  restore <name>         Restore from snapshot
  delete <name>          Delete snapshot
  diff <name1> <name2>   Compare two snapshots

Examples:
  claude-sync snapshot create "before-major-change"
  claude-sync snapshot list
  claude-sync snapshot restore "2025-01-15-morning"
  claude-sync snapshot diff "morning" "evening"
```

#### `claude-sync diff`
Compare configurations.

```bash
claude-sync diff [options]

Options:
  --machine <hostname>     Compare with another machine
  --snapshot <name>        Compare with snapshot
  --local                  Compare current vs last backup
  --files <pattern>        Only specific files

Examples:
  claude-sync diff --local
  claude-sync diff --machine work-laptop
  claude-sync diff --snapshot "yesterday" --files "MODE_*"
```

#### `claude-sync status`
Show synchronization status.

```bash
claude-sync status [options]

Options:
  -v, --verbose          Detailed status information

Output:
  - Last sync timestamp
  - Current machine hostname
  - Configured sync methods
  - Pending changes
  - Conflict warnings
```

### Global Options

All commands support:
- `-h, --help`: Show command help
- `-v, --verbose`: Detailed output
- `-q, --quiet`: Minimal output
- `-n, --dry-run`: Preview without executing
- `--no-color`: Disable colored output

---

## Security Considerations

### Encryption
- ✅ All backups encrypted with AES-256
- ✅ Password prompted interactively (not stored)
- ✅ Encryption validation before/after operations
- ⚠️ User responsible for password management
- ⚠️ Lost password = unrecoverable backups

### Sensitive Data Handling
- API keys in MCP configurations are encrypted
- Git repositories should be private
- SSH keys for direct sync should use key-based auth
- Never commit unencrypted configs to public repos

### Git Security
- Use private repositories
- SSH key authentication (not HTTPS passwords)
- Optional: GPG signing of commits
- `.gitignore` for local-only files

---

## Implementation Phases

### Phase 1: Core Backup/Restore (MVP)
**Goal**: Basic local backup and restore with encryption

- [x] Requirements gathered
- [ ] Directory structure setup
- [ ] Encryption/decryption functions
- [ ] `init` command for local-only mode
- [ ] `backup --full` command
- [ ] `restore --full` command with interactive prompts
- [ ] Basic conflict detection
- [ ] Testing on single machine

**Deliverables**:
- Working `claude-sync backup` and `restore`
- Encrypted backups in `~/.claude-sync/storage/`
- Interactive password prompts
- Basic documentation

### Phase 2: Git Integration
**Goal**: Automatic git sync workflow

- [ ] Git repository initialization
- [ ] Auto-commit on backup
- [ ] Auto-push to remote
- [ ] Pull and merge workflow
- [ ] Conflict resolution with git
- [ ] Testing with remote repository

**Deliverables**:
- Working `claude-sync init --git <repo>`
- Automatic git sync on backup
- Remote repository synchronization

### Phase 3: Selective & Snapshot Features
**Goal**: Fine-grained control over backups

- [ ] Category-based backup/restore
- [ ] Individual file selection
- [ ] Snapshot creation and management
- [ ] `snapshot` command suite
- [ ] Snapshot diff functionality
- [ ] Testing all granularity options

**Deliverables**:
- `--include`, `--only`, `--files` options working
- `snapshot` command fully functional
- Version history and rollback capability

### Phase 4: Direct Machine Sync
**Goal**: Real-time machine-to-machine synchronization

- [ ] SSH/rsync integration
- [ ] Machine registry and discovery
- [ ] Direct sync protocol
- [ ] Bidirectional sync logic
- [ ] Testing between two machines

**Deliverables**:
- Working `claude-sync sync --remote user@host`
- Machine-to-machine synchronization
- Network-based config sharing

### Phase 5: Machine Overrides & Polish
**Goal**: Production-ready tool with all features

- [ ] Comment-based override parsing
- [ ] Override application logic
- [ ] Comprehensive error handling
- [ ] Logging and diagnostics
- [ ] User documentation
- [ ] Installation script
- [ ] Testing across multiple Ubuntu flavors

**Deliverables**:
- Machine-specific overrides working
- Complete documentation
- Installation guide
- Production-ready tool

---

## Technical Stack

### Required Dependencies
- **Core**: `bash` (v4.0+)
- **Encryption**: `gpg` or `openssl`
- **Compression**: `tar`, `gzip`
- **Git**: `git` (for git sync method)
- **Network**: `ssh`, `rsync` (for direct sync)
- **Utilities**: `jq` (JSON parsing), `diff`, `sha256sum`

### Optional Dependencies
- **UI**: `dialog` or `whiptail` (interactive menus)
- **Colors**: `tput` (terminal formatting)
- **Notifications**: `notify-send` (desktop notifications)

---

## Testing Strategy

### Unit Tests
- Encryption/decryption round-trip
- File comparison and diff logic
- Machine override parsing
- Configuration validation

### Integration Tests
- Full backup → restore workflow
- Git sync across machines (simulated)
- Conflict resolution scenarios
- Snapshot creation and restoration

### Real-World Testing
- Test on multiple Ubuntu flavors (Ubuntu, Kubuntu, Xubuntu, etc.)
- Multiple machine synchronization
- Large configuration directories
- Network interruption handling
- Password entry error handling

---

## Success Criteria

### Functional Requirements
- ✅ Backup and restore all Claude Code configurations
- ✅ Full encryption of all backups
- ✅ Support for git, manual, and direct sync methods
- ✅ Interactive conflict resolution
- ✅ Hostname-based machine identification
- ✅ Machine-specific overrides with `# @machine:hostname`
- ✅ Multiple granularity levels (full, selective, files, snapshots)
- ✅ Dry-run mode for all operations
- ✅ Verbose and quiet output modes

### Non-Functional Requirements
- ⚡ Fast: Backup/restore < 5 seconds for typical configs
- 🛡️ Secure: AES-256 encryption, no key storage
- 🎯 Reliable: No data loss, atomic operations
- 📝 Clear: Helpful error messages and prompts
- 🔧 Maintainable: Well-documented bash code
- 🚀 Portable: Works on all Ubuntu flavors

---

## Future Enhancements (Post-MVP)

### Advanced Features
- **Cloud Backend**: Dropbox/Google Drive sync option
- **Auto-Sync Daemon**: Background synchronization service
- **Web UI**: Browser-based configuration management
- **Conflict Visualization**: Graphical diff viewer
- **Backup Compression**: Optimize backup size
- **Incremental Backups**: Only sync changed files
- **Multi-User Support**: Team configuration sharing

### Integrations
- **Claude Code Plugin**: Native integration with Claude Code
- **GitHub Actions**: Automated backup workflows
- **Ansible/Chef**: Configuration management integration
- **Systemd Timers**: Scheduled automatic backups

---

## Getting Started (After Implementation)

### Installation
```bash
git clone https://github.com/user/claude-sync.git
cd claude-sync
./install.sh
```

### Quick Start
```bash
# Initialize local backups
claude-sync init --local

# Create first backup
claude-sync backup

# On another machine: restore
claude-sync restore --interactive

# Set up git sync
claude-sync init --git git@github.com:user/claude-configs.git

# Future backups auto-sync
claude-sync backup
```

---

## Project Timeline Estimate

**Phase 1 (Core)**: 1-2 weeks
**Phase 2 (Git)**: 1 week
**Phase 3 (Snapshots)**: 1 week
**Phase 4 (Direct Sync)**: 1-2 weeks
**Phase 5 (Polish)**: 1 week

**Total**: 5-7 weeks for complete implementation

---

## Questions & Decisions Log

### Answered
1. ✅ Sync methods: Git, Manual, Direct (all three)
2. ✅ Config scope: Global, MCP, Commands
3. ✅ Security: Full encryption, prompt-based
4. ✅ Conflicts: Interactive resolution
5. ✅ Granularity: All levels (full, selective, files, snapshots)
6. ✅ Machine ID: Hostname-based
7. ✅ UX: Simple verbs + prompts + dry-run + verbosity
8. ✅ Git strategy: Auto-commit and push
9. ✅ Structure: Hybrid (current + snapshots)
10. ✅ Overrides: Comment-based markers
11. ✅ MVP focus: Build all sync methods equally

### Open Questions
- What should happen if encryption fails mid-operation?
- Maximum snapshot retention (auto-cleanup old snapshots)?
- Compression level preferences (speed vs size)?
- Desktop notification preferences?
- Automatic backup scheduling preferences?

---

## Next Steps

1. **Review Specification**: Confirm this matches your vision
2. **Start Phase 1**: Build core backup/restore functionality
3. **Set Up Git Repository**: Create project structure
4. **Begin Implementation**: Start with basic bash framework
5. **Iterative Development**: Build, test, refine each phase

---

**Document Version**: 1.0
**Created**: 2025-01-15
**Last Updated**: 2025-01-15
**Status**: Specification Complete - Ready for Implementation
