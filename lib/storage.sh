#!/bin/bash
# lib/storage.sh - Storage backend abstraction

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Use same directory configuration
if [ -z "${CLAUDE_SYNC_DIRS_SET:-}" ]; then
    readonly CLAUDE_DIR="$HOME/.claude"
    readonly SYNC_DIR="$HOME/.claude-sync"
    readonly STORAGE_DIR="$SYNC_DIR/storage"
    readonly CURRENT_DIR="$STORAGE_DIR/current"
    readonly SNAPSHOTS_DIR="$STORAGE_DIR/snapshots"
    readonly GIT_REMOTE_DIR="$SYNC_DIR/git-remote"
    readonly CLAUDE_SYNC_DIRS_SET=1
fi

# Git backend functions

storage_git_init() {
    local repo_url="$1"

    log_info "Initializing git storage backend"

    if [ -z "$repo_url" ]; then
        log_error "Git repository URL required"
    fi

    # Check if git is installed
    if ! command_exists git; then
        log_error "git is not installed. Install with: sudo apt install git"
    fi

    # Create git remote directory
    ensure_directory "$GIT_REMOTE_DIR"

    # Check if already initialized
    if [ -d "$GIT_REMOTE_DIR/.git" ]; then
        log_warn "Git repository already initialized at $GIT_REMOTE_DIR"
        return 0
    fi

    # Clone or init repository
    if [[ "$repo_url" =~ ^(https?|git|ssh):// ]] || [[ "$repo_url" =~ ^[^@]+@[^:]+: ]]; then
        # Remote repository - clone it
        log_info "Cloning remote repository: $repo_url"
        git clone "$repo_url" "$GIT_REMOTE_DIR" 2>&1 | grep -v "warning: You appear to have cloned an empty repository" || true

        if [ $? -ne 0 ] && [ ! -d "$GIT_REMOTE_DIR/.git" ]; then
            log_error "Failed to clone repository. Check URL and credentials."
        fi
    else
        # Local path or will create new repo
        log_info "Initializing new git repository"
        cd "$GIT_REMOTE_DIR"
        git init
        git config user.name "claude-sync"
        git config user.email "claude-sync@localhost"

        # Create initial commit
        echo "# Claude Code Configuration Backup" > README.md
        echo "" >> README.md
        echo "Encrypted backups managed by claude-sync" >> README.md
        git add README.md
        git commit -m "Initial commit"

        # Add remote if URL provided
        if [ -n "$repo_url" ]; then
            git remote add origin "$repo_url"
        fi
    fi

    # Save git URL to config
    echo "GIT_REPO_URL=\"$repo_url\"" > "$SYNC_DIR/config/git.conf"

    log_info "✓ Git storage backend initialized"
}

storage_git_save() {
    local backup_file="$1"
    local message="${2:-Backup from $(get_hostname) - $(date)}"

    if [ ! -d "$GIT_REMOTE_DIR/.git" ]; then
        log_error "Git repository not initialized. Run: claude-sync init --git <repo-url>"
    fi

    log_info "Saving backup to git repository"

    cd "$GIT_REMOTE_DIR"

    # Copy backup file
    cp "$backup_file" backups/latest-backup.tar.gz.gpg

    # Copy metadata if available
    if [ -f "$CURRENT_DIR/latest-backup.checksum" ]; then
        cp "$CURRENT_DIR/latest-backup.checksum" backups/latest-backup.checksum
    fi
    if [ -f "$CURRENT_DIR/latest-backup.timestamp" ]; then
        cp "$CURRENT_DIR/latest-backup.timestamp" backups/latest-backup.timestamp
    fi
    if [ -f "$CURRENT_DIR/latest-backup.hostname" ]; then
        cp "$CURRENT_DIR/latest-backup.hostname" backups/latest-backup.hostname
    fi

    # Create backups directory if needed
    mkdir -p backups

    # Git add and commit
    git add backups/
    git commit -m "$message" 2>&1 | grep -v "nothing to commit" || true

    # Check if we should push
    if [ "${AUTO_PUSH:-true}" = "true" ]; then
        # Check if we have a remote
        if git remote | grep -q "origin"; then
            log_info "Pushing to remote repository..."
            git push origin main 2>&1 || git push origin master 2>&1 || {
                log_warn "Push failed. You may need to: git push -u origin main"
                return 1
            }
            log_info "✓ Pushed to remote"
        else
            log_debug "No remote configured, skipping push"
        fi
    fi

    log_info "✓ Backup saved to git repository"
}

storage_git_load() {
    if [ ! -d "$GIT_REMOTE_DIR/.git" ]; then
        log_error "Git repository not initialized"
    fi

    log_info "Loading backup from git repository"

    cd "$GIT_REMOTE_DIR"

    # Pull latest changes if we have a remote
    if git remote | grep -q "origin"; then
        log_info "Pulling latest changes..."
        git pull origin main 2>&1 || git pull origin master 2>&1 || {
            log_warn "Pull failed, using local version"
        }
    fi

    # Copy backup to current
    if [ -f "backups/latest-backup.tar.gz.gpg" ]; then
        cp backups/latest-backup.tar.gz.gpg "$CURRENT_DIR/latest-backup.tar.gz.gpg"

        # Copy metadata if available
        [ -f "backups/latest-backup.checksum" ] && cp backups/latest-backup.checksum "$CURRENT_DIR/"
        [ -f "backups/latest-backup.timestamp" ] && cp backups/latest-backup.timestamp "$CURRENT_DIR/"
        [ -f "backups/latest-backup.hostname" ] && cp backups/latest-backup.hostname "$CURRENT_DIR/"

        log_info "✓ Backup loaded from git repository"
    else
        log_error "No backup found in git repository"
    fi
}

storage_git_sync() {
    if [ ! -d "$GIT_REMOTE_DIR/.git" ]; then
        log_error "Git repository not initialized"
    fi

    log_info "Syncing with git repository"

    cd "$GIT_REMOTE_DIR"

    # Pull changes
    log_info "Pulling changes from remote..."
    git pull origin main 2>&1 || git pull origin master 2>&1 || {
        log_error "Failed to pull from remote"
    }

    # If we have local changes, push them
    if ! git diff-index --quiet HEAD 2>/dev/null; then
        log_info "Pushing local changes..."
        git push origin main 2>&1 || git push origin master 2>&1 || {
            log_error "Failed to push to remote"
        }
    fi

    log_info "✓ Sync complete"
}

# Export functions
export -f storage_git_init
export -f storage_git_save
export -f storage_git_load
export -f storage_git_sync
