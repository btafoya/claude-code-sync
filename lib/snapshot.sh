#!/bin/bash
# lib/snapshot.sh - Snapshot management for versioned backups

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/encryption.sh"

# Use same directory configuration
if [ -z "${CLAUDE_CODE_SYNC_DIRS_SET:-}" ]; then
    readonly SYNC_DIR="$HOME/.claude-code-sync"
    readonly STORAGE_DIR="$SYNC_DIR/storage"
    readonly SNAPSHOTS_DIR="$STORAGE_DIR/snapshots"
    readonly CURRENT_DIR="$STORAGE_DIR/current"
    readonly CLAUDE_CODE_SYNC_DIRS_SET=1
fi

# Create a named snapshot
snapshot_create() {
    local snapshot_name="$1"

    if [ -z "$snapshot_name" ]; then
        # Auto-generate name from timestamp
        snapshot_name="snapshot-$(get_timestamp_filename)"
    fi

    # Sanitize snapshot name (remove special characters)
    snapshot_name=$(echo "$snapshot_name" | tr -cd '[:alnum:]-_')

    log_info "Creating snapshot: $snapshot_name"

    # Check if latest backup exists
    if [ ! -f "$CURRENT_DIR/latest-backup.tar.gz.gpg" ]; then
        log_error "No backup found. Create a backup first with: claude-code-sync backup"
    fi

    # Create snapshot directory
    local snapshot_dir="$SNAPSHOTS_DIR/$snapshot_name"

    if [ -d "$snapshot_dir" ]; then
        log_error "Snapshot '$snapshot_name' already exists"
    fi

    ensure_directory "$snapshot_dir"

    # Copy backup file
    cp "$CURRENT_DIR/latest-backup.tar.gz.gpg" "$snapshot_dir/backup.tar.gz.gpg"

    # Copy metadata
    [ -f "$CURRENT_DIR/latest-backup.checksum" ] && \
        cp "$CURRENT_DIR/latest-backup.checksum" "$snapshot_dir/backup.checksum"
    [ -f "$CURRENT_DIR/latest-backup.timestamp" ] && \
        cp "$CURRENT_DIR/latest-backup.timestamp" "$snapshot_dir/backup.timestamp"
    [ -f "$CURRENT_DIR/latest-backup.hostname" ] && \
        cp "$CURRENT_DIR/latest-backup.hostname" "$snapshot_dir/backup.hostname"

    # Create snapshot metadata
    cat > "$snapshot_dir/metadata.json" <<EOF
{
  "name": "$snapshot_name",
  "created": "$(get_timestamp)",
  "machine": "$(get_hostname)",
  "size": "$(get_file_size "$snapshot_dir/backup.tar.gz.gpg")"
}
EOF

    # Create file manifest
    if [ -d "$CURRENT_DIR/mirror" ]; then
        find "$CURRENT_DIR/mirror" -type f -printf '%P\n' | sort > "$snapshot_dir/manifest.txt"
    fi

    log_info "✓ Snapshot created: $snapshot_name"
    log_info "  Location: $snapshot_dir"
    log_info "  Size: $(get_file_size "$snapshot_dir/backup.tar.gz.gpg")"
}

# List all snapshots
snapshot_list() {
    log_info "Available snapshots:"
    echo ""

    if [ ! -d "$SNAPSHOTS_DIR" ] || [ -z "$(ls -A "$SNAPSHOTS_DIR" 2>/dev/null)" ]; then
        log_warn "No snapshots found"
        echo ""
        echo "Create a snapshot with: claude-code-sync snapshot create <name>"
        return 0
    fi

    local count=0

    for snapshot_dir in "$SNAPSHOTS_DIR"/*; do
        if [ -d "$snapshot_dir" ]; then
            local snapshot_name=$(basename "$snapshot_dir")
            ((count++))

            echo "[$count] $snapshot_name"

            # Show metadata if available
            if [ -f "$snapshot_dir/metadata.json" ]; then
                local created=$(jq -r '.created' "$snapshot_dir/metadata.json" 2>/dev/null || echo "unknown")
                local machine=$(jq -r '.machine' "$snapshot_dir/metadata.json" 2>/dev/null || echo "unknown")
                local size=$(jq -r '.size' "$snapshot_dir/metadata.json" 2>/dev/null || echo "unknown")

                echo "    Created: $created"
                echo "    Machine: $machine"
                echo "    Size: $size"
            else
                # Fallback to file stats
                if [ -f "$snapshot_dir/backup.tar.gz.gpg" ]; then
                    echo "    Size: $(get_file_size "$snapshot_dir/backup.tar.gz.gpg")"
                fi
            fi

            echo ""
        fi
    done

    log_info "Total snapshots: $count"
}

# Restore from a snapshot
snapshot_restore() {
    local snapshot_name="$1"

    if [ -z "$snapshot_name" ]; then
        log_error "Snapshot name required. List snapshots with: claude-code-sync snapshot list"
    fi

    local snapshot_dir="$SNAPSHOTS_DIR/$snapshot_name"

    if [ ! -d "$snapshot_dir" ]; then
        log_error "Snapshot not found: $snapshot_name"
    fi

    log_info "Restoring from snapshot: $snapshot_name"

    # Copy snapshot to current
    cp "$snapshot_dir/backup.tar.gz.gpg" "$CURRENT_DIR/latest-backup.tar.gz.gpg"

    # Copy metadata if available
    [ -f "$snapshot_dir/backup.checksum" ] && \
        cp "$snapshot_dir/backup.checksum" "$CURRENT_DIR/latest-backup.checksum"
    [ -f "$snapshot_dir/backup.timestamp" ] && \
        cp "$snapshot_dir/backup.timestamp" "$CURRENT_DIR/latest-backup.timestamp"
    [ -f "$snapshot_dir/backup.hostname" ] && \
        cp "$snapshot_dir/backup.hostname" "$CURRENT_DIR/latest-backup.hostname"

    log_info "✓ Snapshot copied to current backup"
    log_info "Now run: claude-code-sync restore"
}

# Delete a snapshot
snapshot_delete() {
    local snapshot_name="$1"

    if [ -z "$snapshot_name" ]; then
        log_error "Snapshot name required"
    fi

    local snapshot_dir="$SNAPSHOTS_DIR/$snapshot_name"

    if [ ! -d "$snapshot_dir" ]; then
        log_error "Snapshot not found: $snapshot_name"
    fi

    # Confirm deletion
    if ! confirm_action "Delete snapshot '$snapshot_name'?"; then
        log_info "Deletion cancelled"
        return 0
    fi

    rm -rf "$snapshot_dir"

    log_info "✓ Snapshot deleted: $snapshot_name"
}

# Compare two snapshots
snapshot_diff() {
    local snapshot1="$1"
    local snapshot2="$2"

    if [ -z "$snapshot1" ] || [ -z "$snapshot2" ]; then
        log_error "Two snapshot names required"
    fi

    local snap1_dir="$SNAPSHOTS_DIR/$snapshot1"
    local snap2_dir="$SNAPSHOTS_DIR/$snapshot2"

    if [ ! -d "$snap1_dir" ]; then
        log_error "Snapshot not found: $snapshot1"
    fi

    if [ ! -d "$snap2_dir" ]; then
        log_error "Snapshot not found: $snapshot2"
    fi

    log_info "Comparing snapshots: $snapshot1 vs $snapshot2"
    echo ""

    # Compare manifests if available
    if [ -f "$snap1_dir/manifest.txt" ] && [ -f "$snap2_dir/manifest.txt" ]; then
        echo "File differences:"
        echo ""

        # Files only in snapshot1
        local only_in_1=$(comm -23 <(sort "$snap1_dir/manifest.txt") <(sort "$snap2_dir/manifest.txt") | wc -l)
        if [ $only_in_1 -gt 0 ]; then
            echo "  Only in $snapshot1: $only_in_1 file(s)"
        fi

        # Files only in snapshot2
        local only_in_2=$(comm -13 <(sort "$snap1_dir/manifest.txt") <(sort "$snap2_dir/manifest.txt") | wc -l)
        if [ $only_in_2 -gt 0 ]; then
            echo "  Only in $snapshot2: $only_in_2 file(s)"
        fi

        # Common files
        local common=$(comm -12 <(sort "$snap1_dir/manifest.txt") <(sort "$snap2_dir/manifest.txt") | wc -l)
        echo "  Common files: $common"
    fi

    echo ""

    # Compare sizes
    local size1=$(get_file_size "$snap1_dir/backup.tar.gz.gpg")
    local size2=$(get_file_size "$snap2_dir/backup.tar.gz.gpg")

    echo "Backup sizes:"
    echo "  $snapshot1: $size1"
    echo "  $snapshot2: $size2"
}

# Export functions
export -f snapshot_create
export -f snapshot_list
export -f snapshot_restore
export -f snapshot_delete
export -f snapshot_diff
