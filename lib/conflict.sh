#!/bin/bash
# lib/conflict.sh - Conflict detection and resolution

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Detect conflicts between backup and current files
detect_conflicts() {
    local backup_dir="$1"
    local target_dir="$2"

    log_debug "Detecting conflicts between backup and current files"

    local conflicts=()
    local conflict_count=0

    # Find files in both locations with different content
    while IFS= read -r -d '' file; do
        local rel_path="${file#$backup_dir/}"
        local target_file="$target_dir/$rel_path"

        if [ -f "$target_file" ]; then
            if ! cmp -s "$file" "$target_file"; then
                conflicts+=("$rel_path")
                ((conflict_count++))
            fi
        fi
    done < <(find "$backup_dir" -type f -print0 2>/dev/null)

    if [ $conflict_count -gt 0 ]; then
        log_warn "Found $conflict_count conflicting file(s)"

        # Store conflicts for later resolution
        printf '%s\n' "${conflicts[@]}" > /tmp/claude-sync-conflicts-$$

        return 1  # Conflicts exist
    else
        log_debug "✓ No conflicts detected"
        return 0  # No conflicts
    fi
}

# Show conflict details
show_conflict() {
    local backup_file="$1"
    local current_file="$2"
    local rel_path="$3"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "CONFLICT: $rel_path"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ -f "$backup_file" ]; then
        local backup_time=$(stat -c %y "$backup_file" 2>/dev/null | cut -d'.' -f1)
        local backup_size=$(get_file_size "$backup_file")
        echo "Backup:  Modified $backup_time ($backup_size)"
    fi

    if [ -f "$current_file" ]; then
        local current_time=$(stat -c %y "$current_file" 2>/dev/null | cut -d'.' -f1)
        local current_size=$(get_file_size "$current_file")
        echo "Current: Modified $current_time ($current_size)"
    fi

    echo ""
}

# Show diff between two files
show_diff() {
    local file1="$1"
    local file2="$2"

    if command_exists diff; then
        diff -u "$file1" "$file2" 2>/dev/null || true
    else
        echo "diff command not available"
        echo "--- $file1 ---"
        head -20 "$file1"
        echo ""
        echo "--- $file2 ---"
        head -20 "$file2"
    fi
}

# Resolve single conflict interactively
resolve_conflict_interactive() {
    local backup_file="$1"
    local current_file="$2"
    local rel_path="$3"

    show_conflict "$backup_file" "$current_file" "$rel_path"

    echo "Choose action:"
    echo "  [1] Keep backup version (overwrite current)"
    echo "  [2] Keep current version (skip restore)"
    echo "  [3] Show diff"
    echo "  [4] Keep both (backup saved as .backup)"
    echo "  [5] Skip this file"
    echo "  [q] Quit without changes"
    echo ""

    local choice
    read -p "Your choice [1-5/q]: " choice

    case "$choice" in
        1)
            log_info "Using backup version"
            return 1  # Use backup
            ;;
        2)
            log_info "Keeping current version"
            return 2  # Keep current
            ;;
        3)
            show_diff "$current_file" "$backup_file"
            echo ""
            resolve_conflict_interactive "$backup_file" "$current_file" "$rel_path"
            return $?
            ;;
        4)
            log_info "Keeping both versions"
            return 4  # Keep both
            ;;
        5)
            log_info "Skipping file"
            return 5  # Skip
            ;;
        q|Q)
            log_error "Restore cancelled by user"
            ;;
        *)
            echo "Invalid choice. Please try again."
            resolve_conflict_interactive "$backup_file" "$current_file" "$rel_path"
            return $?
            ;;
    esac
}

# Resolve all conflicts interactively
resolve_conflicts_interactive() {
    local backup_dir="$1"
    local target_dir="$2"

    if [ ! -f /tmp/claude-sync-conflicts-$$ ]; then
        log_debug "No conflicts to resolve"
        return 0
    fi

    log_info "Starting interactive conflict resolution"

    local resolution_log="$HOME/.claude-sync/logs/conflicts.log"
    ensure_directory "$(dirname "$resolution_log")"

    while IFS= read -r rel_path; do
        local backup_file="$backup_dir/$rel_path"
        local current_file="$target_dir/$rel_path"

        resolve_conflict_interactive "$backup_file" "$current_file" "$rel_path"
        local resolution=$?

        # Log resolution
        echo "$(get_timestamp) | $rel_path | resolution=$resolution" >> "$resolution_log"

        # Apply resolution
        case $resolution in
            1)  # Use backup
                cp -f "$backup_file" "$current_file"
                ;;
            2)  # Keep current
                # Do nothing
                ;;
            4)  # Keep both
                cp "$backup_file" "${current_file}.backup"
                ;;
            5)  # Skip
                # Do nothing
                ;;
        esac
    done < /tmp/claude-sync-conflicts-$$

    # Cleanup
    rm -f /tmp/claude-sync-conflicts-$$

    log_info "✓ Conflict resolution complete"
}

# Auto-resolve conflicts (use backup version)
resolve_conflicts_auto() {
    local backup_dir="$1"
    local target_dir="$2"

    if [ ! -f /tmp/claude-sync-conflicts-$$ ]; then
        log_debug "No conflicts to resolve"
        return 0
    fi

    log_warn "Auto-resolving conflicts (using backup version)"

    while IFS= read -r rel_path; do
        local backup_file="$backup_dir/$rel_path"
        local current_file="$target_dir/$rel_path"

        log_info "Overwriting: $rel_path"
        cp -f "$backup_file" "$current_file"
    done < /tmp/claude-sync-conflicts-$$

    # Cleanup
    rm -f /tmp/claude-sync-conflicts-$$

    log_info "✓ Auto-resolution complete"
}

# Export functions
export -f detect_conflicts
export -f show_conflict
export -f show_diff
export -f resolve_conflict_interactive
export -f resolve_conflicts_interactive
export -f resolve_conflicts_auto
