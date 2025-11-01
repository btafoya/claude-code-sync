# claude-code-sync

> CLI utility for backing up, restoring, and synchronizing Claude Code configurations across multiple machines.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Ubuntu](https://img.shields.io/badge/Platform-Ubuntu-E95420.svg)](https://ubuntu.com/)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)

---

## Overview

**claude-code-sync** is a comprehensive CLI tool designed to manage your Claude Code configurations across multiple Ubuntu machines. It provides encrypted backups, multiple synchronization strategies, intelligent conflict resolution, and versioned snapshots—all wrapped in a simple, intuitive command-line interface.

### Key Features

- 🔐 **Full Encryption** - AES-256 encryption for all backups
- 🔄 **Multiple Sync Methods** - Git repository, manual export/import, or direct SSH sync
- 🤝 **Smart Conflicts** - Interactive conflict resolution with machine-specific overrides
- 📸 **Snapshots** - Named, versioned restore points
- 🎯 **Flexible Granularity** - Backup everything or select specific configs
- 🛡️ **Secure by Default** - Password prompts, no stored credentials
- 🚀 **Simple CLI** - Intuitive commands with dry-run and verbose modes

---

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/btafoya/claude-code-sync.git
cd claude-code-sync

# Run installation script
./install.sh

# Verify installation
claude-code-sync --version
```

**Note**: Dependencies will be automatically detected and installed when you first run claude-code-sync.

### First Backup

```bash
# Initialize the backup system (will check and install dependencies)
claude-code-sync init

# Create your first encrypted backup
claude-code-sync backup

# View status
claude-code-sync status
```

### Restore on Another Machine

```bash
# Initialize on the new machine
claude-code-sync init

# Restore from backup (interactive mode)
claude-code-sync restore --interactive
```

---

## What Gets Backed Up?

claude-code-sync manages configurations from your `~/.claude/` directory:

- ✅ **Global Configs** - CLAUDE.md, RULES.md, PRINCIPLES.md, MODE_*.md
- ✅ **MCP Servers** - All MCP server configurations and connections
- ✅ **Custom Commands** - Your `/sc:*` slash command definitions
- ❌ **Project Configs** - Project-specific `.claude/` directories (handled separately)

---

## Usage

### Basic Commands

```bash
# Initialize backup system
claude-code-sync init [--git <repo>] [--local] [--all]

# Create encrypted backup
claude-code-sync backup [--dry-run] [--verbose]

# Restore from backup
claude-code-sync restore [--dry-run] [--interactive]

# View synchronization status
claude-code-sync status

# Show help
claude-code-sync help
```

### Advanced Usage

#### Named Snapshots

```bash
# Create a named snapshot before making changes
claude-code-sync snapshot create "before-experiment"

# List all snapshots
claude-code-sync snapshot list

# Restore from a specific snapshot
claude-code-sync snapshot restore "before-experiment"

# Compare two snapshots
claude-code-sync snapshot diff "morning" "evening"
```

#### Selective Backup/Restore

```bash
# Backup only MCP configurations
claude-code-sync backup --include mcp

# Restore only slash commands
claude-code-sync restore --only commands

# Backup specific files
claude-code-sync backup --files CLAUDE.md,RULES.md
```

#### Git Repository Sync

```bash
# Initialize with git repository
claude-code-sync init --git git@github.com:user/claude-configs.git

# Backup (automatically commits and pushes)
claude-code-sync backup

# Sync bidirectionally
claude-code-sync sync --git
```

#### Direct Machine Sync

```bash
# Sync directly to another machine
claude-code-sync sync --remote user@work-laptop

# Compare configurations with remote
claude-code-sync diff --machine work-laptop
```

### Global Options

All commands support these flags:

- `-n, --dry-run` - Preview without executing
- `-v, --verbose` - Detailed output
- `-q, --quiet` - Minimal output
- `-h, --help` - Show help

---

## Synchronization Methods

claude-code-sync supports three sync strategies:

### 1. Git Repository Sync (Recommended)

Perfect for version control and cloud backup:

```bash
claude-code-sync init --git git@github.com:user/claude-configs.git
claude-code-sync backup  # Auto-commits and pushes
```

**Pros**: Version history, cloud backup, easy rollback
**Cons**: Requires git repository setup

### 2. Manual Export/Import

For air-gapped machines or manual control:

```bash
claude-code-sync export ~/backup.enc
# Transfer file manually
claude-code-sync import ~/backup.enc
```

**Pros**: Full control, works offline, no cloud dependency
**Cons**: Manual file transfer required

### 3. Direct SSH Sync

For real-time synchronization between online machines:

```bash
claude-code-sync sync --remote user@work-laptop
```

**Pros**: Fast, real-time sync, direct transfer
**Cons**: Requires both machines online simultaneously

---

## Security

### Encryption

All backups are encrypted using **AES-256-GCM** via GPG:

- Strong encryption algorithm (AES-256)
- Password-based encryption (prompted interactively)
- No stored passwords or keys
- Integrity checking with SHA-256 checksums

### Best Practices

1. **Use strong passwords** - Minimum 12 characters recommended
2. **Keep same password** - Use the same password across all machines
3. **Private repositories** - If using git sync, use private repos only
4. **SSH keys** - Use key-based authentication for direct sync
5. **Secure password storage** - Consider using a password manager

---

## Configuration

### Configuration Files

claude-code-sync stores its configuration in `~/.claude-code-sync/`:

```
~/.claude-code-sync/
├── config/
│   ├── sync.conf           # Sync preferences
│   └── machines.conf       # Machine registry
├── storage/
│   ├── current/            # Latest backup
│   └── snapshots/          # Versioned snapshots
└── logs/
    ├── sync.log            # Sync operations
    └── errors.log          # Error tracking
```

### Machine-Specific Overrides

Use comment-based markers for machine-specific configurations:

```bash
# Global setting
export CLAUDE_MODE="production"

# @machine:work-laptop
export CLAUDE_DEBUG="true"

# @machine:home-desktop
export CLAUDE_THEME="dark"
```

---

## Conflict Resolution

When restoring, claude-code-sync detects conflicts and offers options:

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

---

## Examples

### Daily Workflow

```bash
# Morning: Start work
claude-code-sync sync --git

# Make changes to Claude Code configs
# ...

# Evening: Backup before leaving
claude-code-sync backup
```

### Before Major Changes

```bash
# Create snapshot
claude-code-sync snapshot create "before-mcp-update"

# Make changes
# ...

# If something breaks, rollback
claude-code-sync snapshot restore "before-mcp-update"
```

### Multi-Machine Setup

```bash
# On work laptop
claude-code-sync init --git git@github.com:user/claude-configs.git
claude-code-sync backup

# On home desktop
claude-code-sync init --git git@github.com:user/claude-configs.git
claude-code-sync restore --interactive

# Keep in sync
claude-code-sync sync --git
```

---

## Troubleshooting

### Common Issues

**Issue**: Missing dependencies (gpg, tar, etc.)

claude-code-sync will automatically detect and offer to install missing dependencies:
```bash
claude-code-sync init
# Prompts: "Install missing packages using apt? (gnupg tar gzip coreutils rsync)"
# Answer 'y' to automatically install
```

Manual installation (if automatic fails):
```bash
sudo apt update
sudo apt install gnupg tar gzip coreutils rsync jq git
```

**Issue**: `Permission denied` on backup
```bash
chmod 700 ~/.claude-code-sync
chmod 600 ~/.claude-code-sync/config/*
```

**Issue**: Decryption fails with "bad password"
- Verify you're using the same password
- Check for typos (no visual feedback during input)
- Try re-entering password carefully

**Issue**: Git sync fails
- Verify SSH key is added to GitHub/GitLab
- Check repository URL is correct
- Ensure repository is private

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
claude-code-sync backup --verbose
claude-code-sync restore --dry-run --verbose
```

Check logs for detailed error information:

```bash
tail -f ~/.claude-code-sync/logs/sync.log
tail -f ~/.claude-code-sync/logs/errors.log
```

---

## Requirements

### System Requirements

- **Platform**: Ubuntu (all flavors: Ubuntu, Kubuntu, Xubuntu, etc.)
- **Shell**: Bash 4.0+
- **Disk Space**: Minimal (configs are typically < 10 MB)

### Dependencies

**Automatic Installation**: claude-code-sync will automatically detect missing dependencies and offer to install them when you first run any command.

**Required packages**:
- `gpg` (gnupg) - Encryption/decryption
- `tar` - Archive creation
- `gzip` - Archive compression
- `sha256sum` (coreutils) - Integrity checking
- `rsync` - File synchronization

**Optional packages**:
- `jq` - JSON parsing (for snapshot metadata)
- `git` - Git repository sync

**Manual installation** (if needed):

```bash
sudo apt update
sudo apt install gnupg tar gzip coreutils rsync jq git
```

**Automatic installation** (recommended):

Just run any claude-code-sync command, and it will prompt you to install missing packages:

```bash
claude-code-sync init
# Will detect missing dependencies and offer to install them
```

---

## Documentation

### Available Documentation

- **README.md** (this file) - User guide and quick reference
- **claudedocs/PROJECT_SPECIFICATION.md** - Complete requirements and features
- **claudedocs/ARCHITECTURE.md** - System design and technical details
- **claudedocs/IMPLEMENTATION_ROADMAP.md** - Development guide
- **claudedocs/QUICK_START.md** - Getting started for developers
- **CLAUDE.md** - Instructions for Claude Code when working on this project

### Getting Help

- Check the [documentation](#documentation)
- Review [troubleshooting](#troubleshooting)
- Search [existing issues](https://github.com/yourusername/claude-code-sync/issues)
- Open a [new issue](https://github.com/yourusername/claude-code-sync/issues/new)

---

## Development

### Current Status

**Phase 1: Core Backup/Restore** - In Progress

- [x] Project structure and documentation
- [ ] Core backup functionality
- [ ] Restore with conflict detection
- [ ] Encryption/decryption
- [ ] Testing suite

### Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

See `CLAUDE.md` for development guidelines and code style.

### Roadmap

- **Phase 1** (Current) - Core backup/restore with encryption
- **Phase 2** - Git repository integration
- **Phase 3** - Snapshots and versioning
- **Phase 4** - Direct SSH sync
- **Phase 5** - Production polish and hardening

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- Built for use with [Claude Code](https://claude.com/code)
- Inspired by dotfiles management tools
- Designed with security and privacy in mind

---

## Support

If you find this tool useful, please:

- ⭐ Star the repository
- 🐛 Report bugs via [issues](https://github.com/yourusername/claude-code-sync/issues)
- 💡 Suggest features
- 📖 Improve documentation
- 🤝 Contribute code

---

**Happy syncing!** 🚀

---

*Last updated: 2025-01-15*
