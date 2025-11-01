#!/bin/bash
# lib/restore.sh - Restore operations

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/encryption.sh"
source "$SCRIPT_DIR/conflict.sh"

# Use same directory configuration as backup.sh (only set if not already set)
if [ -z "${CLAUDE_SYNC_DIRS_SET:-}" ]; then
    readonly CLAUDE_DIR="$HOME/.claude"
    readonly SYNC_DIR="$HOME/.claude-sync"
    readonly STORAGE_DIR="$SYNC_DIR/storage"
    readonly CURRENT_DIR="$STORAGE_DIR/current"
    readonly TMP_DIR="$SYNC_DIR/tmp"
    readonly CLAUDE_SYNC_DIRS_SET=1
fi

# Verify backup file exists and is valid
verify_backup() {
    local backup_file="$1"

    log_debug "Verifying backup: $backup_file"

    validate_file "$backup_file" "Backup file"

    # Check if it's a valid GPG file
    if ! gpg --list-packets "$backup_file" &>/dev/null; then
        log_error "Invalid encrypted file: $backup_file"
    fi

    log_debug "✓ Backup file appears valid"
    return 0
}

# Log restore transaction
log_restore() {
    local timestamp=$(get_timestamp)
    local hostname=$(get_hostname)

    local log_file="$SYNC_DIR/logs/restore.log"
    ensure_directory "$(dirname "$log_file")"

    echo "$timestamp | $hostname | restored" >> "$log_file"
}

# Perform full restore
restore_full() {
    local dry_run="${1:-false}"
    local interactive="${2:-true}"

    log_info "═══════════════════════════════════════"
    log_info "  Starting Full Restore"
    log_info "═══════════════════════════════════════"

    # Check backup exists
    local backup_file="$CURRENT_DIR/latest-backup.tar.gz.gpg"
    if [ ! -f "$backup_file" ]; then
        log_error "No backup found at: $backup_file\nPlease create a backup first with: claude-sync backup"
    fi

    # Show backup info
    if [ -f "$CURRENT_DIR/latest-backup.timestamp" ]; then
        local backup_time=$(cat "$CURRENT_DIR/latest-backup.timestamp")
        log_info "Backup timestamp: $backup_time"
    fi
    if [ -f "$CURRENT_DIR/latest-backup.hostname" ]; then
        local backup_host=$(cat "$CURRENT_DIR/latest-backup.hostname")
        log_info "Backup from: $backup_host"
    fi

    # Dry run mode
    if [ "$dry_run" = "true" ]; then
        log_info "[DRY RUN] Would restore from: $backup_file"
        log_info "[DRY RUN] Target directory: $CLAUDE_DIR"

        if [ -d "$CURRENT_DIR/mirror" ]; then
            log_info "[DRY RUN] Would restore the following files:"
            find "$CURRENT_DIR/mirror" -type f 2>/dev/null | while read -r file; do
                local rel_path="${file#$CURRENT_DIR/mirror/}"
                echo "  - $rel_path"
            done
        fi

        return 0
    fi

    # Create backup of current state (safety)
    if [ -d "$CLAUDE_DIR" ]; then
        log_info "Creating safety backup of current state..."
        local safety_backup="$TMP_DIR/pre-restore-backup-$$.tar.gz"
        tar czf "$safety_backup" -C "$HOME" ".claude" 2>/dev/null
        log_info "Safety backup: $safety_backup"
        log_info "(This will be automatically deleted after successful restore)"
    fi

    # Get password for decryption
    local password=$(prompt_password_decrypt "Enter decryption password")

    # Create temporary directory
    local restore_dir="$TMP_DIR/restore-staging-$$"
    ensure_directory "$restore_dir"

    # Setup cleanup trap
    trap "cleanup_temp '$restore_dir'" EXIT

    # Decrypt archive
    local archive_path="$TMP_DIR/restore-archive-$$.tar.gz"
    decrypt_archive "$backup_file" "$archive_path" "$password"

    # Verify checksum if available
    if [ -f "$CURRENT_DIR/latest-backup.checksum" ]; then
        local expected_checksum=$(cat "$CURRENT_DIR/latest-backup.checksum")
        log_info "Verifying archive integrity..."
        verify_checksum "$archive_path" "$expected_checksum"
    else
        log_warn "No checksum file found, skipping integrity check"
    fi

    # Extract archive
    log_info "Extracting archive..."
    tar xzf "$archive_path" -C "$restore_dir" 2>/dev/null

    if [ $? -ne 0 ]; then
        cleanup_temp "$restore_dir"
        rm -f "$archive_path"
        log_error "Archive extraction failed"
    fi

    # Get the extracted directory name
    local extracted_dir=$(find "$restore_dir" -mindepth 1 -maxdepth 1 -type d | head -1)

    if [ -z "$extracted_dir" ]; then
        cleanup_temp "$restore_dir"
        rm -f "$archive_path"
        log_error "No directory found in extracted archive"
    fi

    # Detect conflicts
    if [ -d "$CLAUDE_DIR" ]; then
        detect_conflicts "$extracted_dir" "$CLAUDE_DIR"
        local has_conflicts=$?

        if [ $has_conflicts -eq 1 ]; then
            if [ "$interactive" = "true" ]; then
                log_info "Conflicts detected - starting interactive resolution"
                resolve_conflicts_interactive "$extracted_dir" "$CLAUDE_DIR"
            else
                log_warn "Conflicts detected - auto-resolving (using backup version)"
                resolve_conflicts_auto "$extracted_dir" "$CLAUDE_DIR"
            fi
        fi
    fi

    # Apply restore
    log_info "Restoring files to $CLAUDE_DIR..."

    # Ensure target directory exists
    ensure_directory "$CLAUDE_DIR"

    # Copy files
    rsync -a --delete "$extracted_dir/" "$CLAUDE_DIR/" 2>/dev/null

    if [ $? -ne 0 ]; then
        log_error "Restore failed during file copy"
    fi

    # Log restore
    log_restore

    # Cleanup
    cleanup_temp "$restore_dir"
    rm -f "$archive_path"

    # Remove safety backup (restore was successful)
    if [ -f "$safety_backup" ]; then
        rm -f "$safety_backup"
    fi

    log_info "═══════════════════════════════════════"
    log_info "  ✓ Restore Complete"
    log_info "═══════════════════════════════════════"
    log_info "Restored to: $CLAUDE_DIR"
    log_info "Files restored: $(count_files "$CLAUDE_DIR")"
}

# Perform selective restore (by category)
restore_selective() {
    local categories="$1"
    local dry_run="${2:-false}"
    local interactive="${3:-true}"

    log_info "Selective restore: $categories"
    log_warn "Selective restore not yet implemented in Phase 1"
    log_info "Using full restore instead"

    restore_full "$dry_run" "$interactive"
}

# Export functions
export -f verify_backup
export -f log_restore
export -f restore_full
export -f restore_selective
