#!/bin/bash
# lib/backup.sh - Backup operations

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/encryption.sh"

# Load storage module if available
if [ -f "$SCRIPT_DIR/storage.sh" ]; then
    source "$SCRIPT_DIR/storage.sh"
fi

# Directory configuration (only set if not already set)
if [ -z "${CLAUDE_SYNC_DIRS_SET:-}" ]; then
    readonly CLAUDE_DIR="$HOME/.claude"
    readonly SYNC_DIR="$HOME/.claude-sync"
    readonly STORAGE_DIR="$SYNC_DIR/storage"
    readonly CURRENT_DIR="$STORAGE_DIR/current"
    readonly SNAPSHOTS_DIR="$STORAGE_DIR/snapshots"
    readonly TMP_DIR="$SYNC_DIR/tmp"
    readonly CLAUDE_SYNC_DIRS_SET=1
fi

# Initialize backup system
backup_init() {
    log_info "Initializing claude-sync backup system"

    # Create directory structure
    ensure_directory "$SYNC_DIR" 700
    ensure_directory "$STORAGE_DIR" 700
    ensure_directory "$CURRENT_DIR" 700
    ensure_directory "$SNAPSHOTS_DIR" 700
    ensure_directory "$TMP_DIR" 700
    ensure_directory "$SYNC_DIR/logs" 700
    ensure_directory "$SYNC_DIR/config" 700

    # Check Claude directory exists
    if [ ! -d "$CLAUDE_DIR" ]; then
        log_error "Claude Code directory not found: $CLAUDE_DIR\nPlease ensure Claude Code is installed and configured"
    fi

    log_info "✓ Backup system initialized"
    log_info "  Storage location: $SYNC_DIR"
}

# Collect configuration files from ~/.claude
collect_config_files() {
    local target_dir="$1"

    log_info "Collecting configuration files from $CLAUDE_DIR"

    # Ensure target directory exists
    ensure_directory "$target_dir"

    # Copy all files using rsync
    rsync -a --delete \
        --exclude ".git" \
        --exclude "*.log" \
        --exclude "tmp/" \
        --exclude ".DS_Store" \
        "$CLAUDE_DIR/" \
        "$target_dir/" 2>/dev/null

    if [ $? -ne 0 ]; then
        log_error "Failed to collect configuration files"
    fi

    # Count files
    local file_count=$(count_files "$target_dir")
    log_info "✓ Collected $file_count configuration file(s)"

    return 0
}

# Create tar.gz archive
create_archive() {
    local source_dir="$1"
    local archive_file="$2"

    log_debug "Creating archive: $archive_file"

    # Create archive
    tar czf "$archive_file" \
        -C "$(dirname "$source_dir")" \
        "$(basename "$source_dir")" 2>/dev/null

    if [ $? -ne 0 ]; then
        rm -f "$archive_file"
        log_error "Archive creation failed"
    fi

    local size=$(get_file_size "$archive_file")
    log_debug "✓ Archive created ($size)"

    return 0
}

# Log backup transaction
log_backup() {
    local timestamp="$1"
    local checksum="$2"
    local hostname=$(get_hostname)

    local log_file="$SYNC_DIR/logs/backup.log"
    ensure_directory "$(dirname "$log_file")"

    echo "$timestamp | $hostname | $checksum" >> "$log_file"
}

# Perform full backup
backup_full() {
    local dry_run="${1:-false}"

    log_info "═══════════════════════════════════════"
    log_info "  Starting Full Backup"
    log_info "═══════════════════════════════════════"

    # Initialize if needed
    if [ ! -d "$SYNC_DIR" ]; then
        backup_init
    fi

    # Dry run mode
    if [ "$dry_run" = "true" ]; then
        log_info "[DRY RUN] Would backup the following files:"
        find "$CLAUDE_DIR" -type f \
            -not -path "*/.git/*" \
            -not -name "*.log" \
            -not -path "*/tmp/*" 2>/dev/null | while read -r file; do
            echo "  - ${file#$CLAUDE_DIR/}"
        done
        local file_count=$(find "$CLAUDE_DIR" -type f \
            -not -path "*/.git/*" \
            -not -name "*.log" \
            -not -path "*/tmp/*" 2>/dev/null | wc -l)
        log_info "[DRY RUN] Total files: $file_count"
        return 0
    fi

    # Get password for encryption
    log_info "Backup will be encrypted with AES-256"
    local password=$(prompt_password "Enter encryption password")

    # Create temporary staging directory
    local staging_dir="$TMP_DIR/backup-staging-$$"
    ensure_directory "$staging_dir"

    # Setup cleanup trap
    trap "cleanup_temp '$staging_dir'" EXIT

    # Collect configuration files
    collect_config_files "$staging_dir"

    # Create archive
    local timestamp=$(get_timestamp_filename)
    local archive_name="backup-$timestamp.tar.gz"
    local archive_path="$TMP_DIR/$archive_name"

    create_archive "$staging_dir" "$archive_path"

    # Generate checksum
    local checksum=$(generate_checksum "$archive_path")
    log_info "Archive checksum: $checksum"

    # Encrypt archive
    local encrypted_path="${archive_path}.gpg"
    encrypt_archive "$archive_path" "$encrypted_path" "$password"

    # Store in current/
    log_info "Storing encrypted backup..."
    cp "$encrypted_path" "$CURRENT_DIR/latest-backup.tar.gz.gpg"
    echo "$checksum" > "$CURRENT_DIR/latest-backup.checksum"
    echo "$(get_timestamp)" > "$CURRENT_DIR/latest-backup.timestamp"
    echo "$(get_hostname)" > "$CURRENT_DIR/latest-backup.hostname"

    # Update current mirror (unencrypted for easy access)
    log_debug "Updating current mirror"
    rm -rf "$CURRENT_DIR/mirror"
    cp -r "$staging_dir" "$CURRENT_DIR/mirror"

    # Log backup
    log_backup "$(get_timestamp)" "$checksum"

    # Cleanup
    cleanup_temp "$staging_dir"
    rm -f "$archive_path" "$encrypted_path"

    # Git integration (if configured)
    if [ -d "$SYNC_DIR/git-remote/.git" ] && command -v storage_git_save >/dev/null 2>&1; then
        log_info "Syncing with git repository..."
        storage_git_save "$CURRENT_DIR/latest-backup.tar.gz.gpg" "Backup from $(get_hostname) - $(date '+%Y-%m-%d %H:%M')"
    fi

    log_info "═══════════════════════════════════════"
    log_info "  ✓ Backup Complete"
    log_info "═══════════════════════════════════════"
    log_info "Backup location: $CURRENT_DIR/latest-backup.tar.gz.gpg"
    log_info "Backup size:     $(get_file_size "$CURRENT_DIR/latest-backup.tar.gz.gpg")"
}

# Perform selective backup (by category)
backup_selective() {
    local categories="$1"
    local dry_run="${2:-false}"

    log_info "Selective backup: $categories"
    log_warn "Selective backup not yet implemented in Phase 1"
    log_info "Using full backup instead"

    backup_full "$dry_run"
}

# Export functions
export -f backup_init
export -f collect_config_files
export -f create_archive
export -f log_backup
export -f backup_full
export -f backup_selective
