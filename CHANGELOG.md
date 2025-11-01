# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2025-11-01

### Changed
- **Project Renamed**: Renamed from `claude-sync` to `claude-code-sync`
  - CLI command: `claude-sync` → `claude-code-sync`
  - User data directory: `~/.claude-sync` → `~/.claude-code-sync`
  - All internal references, documentation, and code updated
  - Install location: `~/.local/lib/claude-sync` → `~/.local/lib/claude-code-sync`

### Added
- **Automatic Migration**: Added migration logic to automatically detect and migrate existing `~/.claude-sync` directories
  - Prompts user before migrating data to new directory structure
  - Preserves all existing backups, snapshots, and configuration
  - One-time migration on first run after upgrade

### Updated
- Updated all documentation to reflect new project name
- Updated install.sh to use new command and directory names
- Updated all test files for new naming convention
- Bumped version to 1.3.0

## [1.2.0] - 2025-11-01

### Added
- **Automatic Dependency Installation**: Enhanced `check_dependencies()` function to automatically detect and install missing packages
  - Prompts user to install missing required packages (gnupg, tar, gzip, coreutils, rsync)
  - Separately handles optional packages (jq, git) with user confirmation
  - Verifies successful installation after package installation
  - Maps command names to correct apt package names
  - Provides clear installation instructions if automatic installation fails
  - Respects `--force` flag to skip optional package prompts

### Changed
- Updated README.md with automatic dependency installation information
- Enhanced troubleshooting section with dependency installation guidance
- Improved Quick Start section to mention automatic dependency handling

### Fixed
- Package name mapping for correct apt installation (e.g., `gpg` → `gnupg`, `sha256sum` → `coreutils`)

## [1.1.0] - 2025-11-01

### Added
- **Git Integration** (Phase 2)
  - Git repository initialization with `--git` flag
  - Automatic backup commit and push to remote repository
  - Bidirectional synchronization with `sync` command
  - Git backend abstraction in `lib/storage.sh`

- **Snapshot Management** (Phase 3)
  - Named snapshot creation and management
  - Auto-generated timestamp-based snapshot names
  - Snapshot listing with metadata display
  - Snapshot restoration workflow
  - Snapshot deletion with confirmation
  - Snapshot comparison (diff) functionality
  - JSON metadata generation for each snapshot
  - Special character sanitization in snapshot names

### Changed
- Updated CLI version to v1.1.0
- Enhanced help documentation with new commands
- Improved test coverage (16 total tests)

### Fixed
- Readonly variable protection in all modules
- Snapshot directory structure consistency
- SNAPSHOTS_DIR declaration in storage.sh

## [1.0.0] - 2025-01-15

### Added
- **Core Backup/Restore** (Phase 1)
  - Full encrypted backup system with AES-256-GCM
  - GPG-based encryption with secure password prompts
  - SHA-256 integrity checksums
  - Interactive conflict resolution
  - Dry-run mode for safe previews
  - Verbose logging for debugging
  - Secure file permissions (700/600)

- **Core Modules**
  - `lib/utils.sh` - Logging and utility functions
  - `lib/encryption.sh` - AES-256 encryption operations
  - `lib/backup.sh` - Backup workflow
  - `lib/restore.sh` - Restore workflow
  - `lib/conflict.sh` - Conflict detection and resolution
  - `bin/claude-code-sync` - Main CLI executable

- **Testing**
  - Unit test suite (test_utils.sh)
  - Integration test suite
  - Complete syntax validation

- **Documentation**
  - Comprehensive README.md
  - PROJECT_SPECIFICATION.md
  - ARCHITECTURE.md
  - IMPLEMENTATION_ROADMAP.md
  - QUICK_START.md
  - GETTING_STARTED.md

### Security
- AES-256-GCM encryption with PBKDF2
- 65M+ iteration key derivation
- SHA-512 hash function
- No stored credentials
- Secure password prompts

---

## Version History

- **v1.3.0** - Project renamed to claude-code-sync with automatic migration
- **v1.2.0** - Automatic dependency installation
- **v1.1.0** - Git integration and snapshot management
- **v1.0.0** - Initial release with core backup/restore
