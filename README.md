# claude-sync

> CLI utility for backing up, restoring, and synchronizing Claude Code configurations across multiple machines.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Ubuntu](https://img.shields.io/badge/Platform-Ubuntu-E95420.svg)](https://ubuntu.com/)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)

---

## Overview

**claude-sync** is a comprehensive CLI tool designed to manage your Claude Code configurations across multiple Ubuntu machines. It provides encrypted backups, multiple synchronization strategies, intelligent conflict resolution, and versioned snapshots—all wrapped in a simple, intuitive command-line interface.

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
git clone https://github.com/yourusername/claude-sync.git
cd claude-sync

# Run installation script
./install.sh

# Verify installation
claude-sync --version
```

### First Backup

```bash
# Initialize the backup system
claude-sync init

# Create your first encrypted backup
claude-sync backup

# View status
claude-sync status
```

### Restore on Another Machine

```bash
# Initialize on the new machine
claude-sync init

# Restore from backup (interactive mode)
claude-sync restore --interactive
```

---

## What Gets Backed Up?

claude-sync manages configurations from your `~/.claude/` directory:

- ✅ **Global Configs** - CLAUDE.md, RULES.md, PRINCIPLES.md, MODE_*.md
- ✅ **MCP Servers** - All MCP server configurations and connections
- ✅ **Custom Commands** - Your `/sc:*` slash command definitions
- ❌ **Project Configs** - Project-specific `.claude/` directories (handled separately)

---

## Usage

### Basic Commands

```bash
# Initialize backup system
claude-sync init [--git <repo>] [--local] [--all]

# Create encrypted backup
claude-sync backup [--dry-run] [--verbose]

# Restore from backup
claude-sync restore [--dry-run] [--interactive]

# View synchronization status
claude-sync status

# Show help
claude-sync help
```

### Advanced Usage

#### Named Snapshots

```bash
# Create a named snapshot before making changes
claude-sync snapshot create "before-experiment"

# List all snapshots
claude-sync snapshot list

# Restore from a specific snapshot
claude-sync snapshot restore "before-experiment"

# Compare two snapshots
claude-sync snapshot diff "morning" "evening"
```

#### Selective Backup/Restore

```bash
# Backup only MCP configurations
claude-sync backup --include mcp

# Restore only slash commands
claude-sync restore --only commands

# Backup specific files
claude-sync backup --files CLAUDE.md,RULES.md
```

#### Git Repository Sync

```bash
# Initialize with git repository
claude-sync init --git git@github.com:user/claude-configs.git

# Backup (automatically commits and pushes)
claude-sync backup

# Sync bidirectionally
claude-sync sync --git
```

#### Direct Machine Sync

```bash
# Sync directly to another machine
claude-sync sync --remote user@work-laptop

# Compare configurations with remote
claude-sync diff --machine work-laptop
```

### Global Options

All commands support these flags:

- `-n, --dry-run` - Preview without executing
- `-v, --verbose` - Detailed output
- `-q, --quiet` - Minimal output
- `-h, --help` - Show help

---

## Synchronization Methods

claude-sync supports three sync strategies:

### 1. Git Repository Sync (Recommended)

Perfect for version control and cloud backup:

```bash
claude-sync init --git git@github.com:user/claude-configs.git
claude-sync backup  # Auto-commits and pushes
```

**Pros**: Version history, cloud backup, easy rollback
**Cons**: Requires git repository setup

### 2. Manual Export/Import

For air-gapped machines or manual control:

```bash
claude-sync export ~/backup.enc
# Transfer file manually
claude-sync import ~/backup.enc
```

**Pros**: Full control, works offline, no cloud dependency
**Cons**: Manual file transfer required

### 3. Direct SSH Sync

For real-time synchronization between online machines:

```bash
claude-sync sync --remote user@work-laptop
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

claude-sync stores its configuration in `~/.claude-sync/`:

```
~/.claude-sync/
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

When restoring, claude-sync detects conflicts and offers options:

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
claude-sync sync --git

# Make changes to Claude Code configs
# ...

# Evening: Backup before leaving
claude-sync backup
```

### Before Major Changes

```bash
# Create snapshot
claude-sync snapshot create "before-mcp-update"

# Make changes
# ...

# If something breaks, rollback
claude-sync snapshot restore "before-mcp-update"
```

### Multi-Machine Setup

```bash
# On work laptop
claude-sync init --git git@github.com:user/claude-configs.git
claude-sync backup

# On home desktop
claude-sync init --git git@github.com:user/claude-configs.git
claude-sync restore --interactive

# Keep in sync
claude-sync sync --git
```

---

## Troubleshooting

### Common Issues

**Issue**: `gpg: command not found`
```bash
sudo apt install gnupg
```

**Issue**: `Permission denied` on backup
```bash
chmod 700 ~/.claude-sync
chmod 600 ~/.claude-sync/config/*
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
claude-sync backup --verbose
claude-sync restore --dry-run --verbose
```

Check logs for detailed error information:

```bash
tail -f ~/.claude-sync/logs/sync.log
tail -f ~/.claude-sync/logs/errors.log
```

---

## Requirements

### System Requirements

- **Platform**: Ubuntu (all flavors: Ubuntu, Kubuntu, Xubuntu, etc.)
- **Shell**: Bash 4.0+
- **Disk Space**: Minimal (configs are typically < 10 MB)

### Dependencies

Required packages (automatically checked):

- `gpg` - Encryption/decryption
- `tar`, `gzip` - Archive creation
- `sha256sum` - Integrity checking
- `jq` - JSON parsing
- `rsync` - File synchronization
- `git` - Git sync (optional)

Install all dependencies:

```bash
sudo apt update
sudo apt install gnupg tar gzip coreutils jq rsync git
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
- Search [existing issues](https://github.com/yourusername/claude-sync/issues)
- Open a [new issue](https://github.com/yourusername/claude-sync/issues/new)

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
- 🐛 Report bugs via [issues](https://github.com/yourusername/claude-sync/issues)
- 💡 Suggest features
- 📖 Improve documentation
- 🤝 Contribute code

---

**Happy syncing!** 🚀

---

*Last updated: 2025-01-15*
