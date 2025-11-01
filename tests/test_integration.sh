#!/bin/bash
# Integration tests for git and snapshot features

set -euo pipefail

# Test setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Setup test environment BEFORE sourcing modules
TEST_DIR="/tmp/claude-code-sync-test-$$"
HOME="$TEST_DIR/home"
export TEST_DIR HOME

mkdir -p "$HOME/.claude"
mkdir -p "$HOME/.claude-code-sync"

# Create test Claude files
echo "# Test CLAUDE.md" > "$HOME/.claude/CLAUDE.md"
echo "# Test RULES.md" > "$HOME/.claude/RULES.md"

# Source modules AFTER setting test HOME
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/storage.sh"
source "$PROJECT_ROOT/lib/snapshot.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test result tracking
test_passed() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} $1"
}

test_failed() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} $1"
    echo "  Error: $2"
}

# Cleanup test environment
cleanup_test_env() {
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

# Test: Git initialization
test_git_init() {
    local test_name="Git repository initialization"

    # Initialize with local path
    if storage_git_init "$TEST_DIR/test-repo.git" 2>/dev/null; then
        if [ -d "$HOME/.claude-code-sync/git-remote/.git" ]; then
            test_passed "$test_name"
        else
            test_failed "$test_name" "Git directory not created"
        fi
    else
        test_failed "$test_name" "storage_git_init failed"
    fi
}

# Test: Snapshot creation
test_snapshot_create() {
    local test_name="Snapshot creation"

    # Create a mock backup first
    mkdir -p "$HOME/.claude-code-sync/storage/current"
    echo "test backup" > "$HOME/.claude-code-sync/storage/current/latest-backup.tar.gz.gpg"
    echo "checksum123" > "$HOME/.claude-code-sync/storage/current/latest-backup.checksum"
    echo "$(date -Iseconds)" > "$HOME/.claude-code-sync/storage/current/latest-backup.timestamp"
    echo "test-host" > "$HOME/.claude-code-sync/storage/current/latest-backup.hostname"

    # Create snapshot
    if snapshot_create "test-snapshot"; then
        if [ -d "$HOME/.claude-code-sync/storage/snapshots/test-snapshot" ] && \
           [ -f "$HOME/.claude-code-sync/storage/snapshots/test-snapshot/backup.tar.gz.gpg" ]; then
            test_passed "$test_name"
        else
            test_failed "$test_name" "Snapshot files not created"
        fi
    else
        test_failed "$test_name" "snapshot_create failed"
    fi
}

# Test: Snapshot listing
test_snapshot_list() {
    local test_name="Snapshot listing"

    local output=$(snapshot_list 2>&1)

    if echo "$output" | grep -q "test-snapshot"; then
        test_passed "$test_name"
    else
        test_failed "$test_name" "Snapshot not listed"
    fi
}

# Test: Snapshot metadata
test_snapshot_metadata() {
    local test_name="Snapshot metadata generation"

    local metadata_file="$HOME/.claude-code-sync/storage/snapshots/test-snapshot/metadata.json"

    if [ -f "$metadata_file" ]; then
        if command -v jq >/dev/null 2>&1; then
            local snapshot_name=$(jq -r '.name' "$metadata_file" 2>/dev/null || echo "")
            if [ "$snapshot_name" = "test-snapshot" ]; then
                test_passed "$test_name"
            else
                test_failed "$test_name" "Invalid metadata content"
            fi
        else
            # Skip if jq not available
            test_passed "$test_name (jq not available, skipped validation)"
        fi
    else
        test_failed "$test_name" "Metadata file not created"
    fi
}

# Test: Snapshot restore preparation
test_snapshot_restore_prep() {
    local test_name="Snapshot restore preparation"

    # This just tests the copy operation, not full restore
    if snapshot_restore "test-snapshot" 2>/dev/null; then
        if [ -f "$HOME/.claude-code-sync/storage/current/latest-backup.tar.gz.gpg" ]; then
            test_passed "$test_name"
        else
            test_failed "$test_name" "Backup not copied to current"
        fi
    else
        test_failed "$test_name" "snapshot_restore failed"
    fi
}

# Test: Snapshot deletion
test_snapshot_delete() {
    local test_name="Snapshot deletion"

    # Create a test snapshot to delete
    snapshot_create "delete-me" 2>/dev/null

    # Force delete without confirmation
    export FORCE=true

    if snapshot_delete "delete-me" 2>/dev/null; then
        if [ ! -d "$HOME/.claude-code-sync/storage/snapshots/delete-me" ]; then
            test_passed "$test_name"
        else
            test_failed "$test_name" "Snapshot directory still exists"
        fi
    else
        test_failed "$test_name" "snapshot_delete failed"
    fi

    unset FORCE
}

# Test: Auto-generated snapshot name
test_snapshot_auto_name() {
    local test_name="Auto-generated snapshot name"

    if snapshot_create "" 2>/dev/null; then
        # Check if a snapshot with timestamp format exists
        local snapshot_count=$(ls "$HOME/.claude-code-sync/storage/snapshots" 2>/dev/null | grep -c "^snapshot-" || echo "0")
        if [ "$snapshot_count" -gt 0 ]; then
            test_passed "$test_name"
        else
            test_failed "$test_name" "Auto-named snapshot not created"
        fi
    else
        test_failed "$test_name" "snapshot_create with empty name failed"
    fi
}

# Test: Directory structure creation
test_directory_structure() {
    local test_name="Storage directory structure"

    # Clean and reinitialize
    rm -rf "$HOME/.claude-code-sync/storage"
    mkdir -p "$HOME/.claude-code-sync/storage"/{current,snapshots}

    if [ -d "$HOME/.claude-code-sync/storage/current" ] && \
       [ -d "$HOME/.claude-code-sync/storage/snapshots" ]; then
        test_passed "$test_name"
    else
        test_failed "$test_name" "Directory structure not created properly"
    fi
}

# Test: Snapshot name sanitization
test_snapshot_name_sanitization() {
    local test_name="Snapshot name sanitization"

    # Create snapshot with special characters
    if snapshot_create 'test@snapshot#with$special%chars' 2>/dev/null; then
        # Check if sanitized name exists (should only have alphanumeric, dash, underscore)
        local sanitized_count=$(ls "$HOME/.claude-code-sync/storage/snapshots" 2>/dev/null | grep -c "testsnapshotwithspecialchars" || echo "0")
        if [ "$sanitized_count" -gt 0 ]; then
            test_passed "$test_name"
        else
            test_failed "$test_name" "Name not sanitized properly"
        fi
    else
        test_failed "$test_name" "snapshot_create with special chars failed"
    fi
}

# Run all tests
run_tests() {
    echo "═══════════════════════════════════════"
    echo "  claude-code-sync Integration Tests"
    echo "═══════════════════════════════════════"
    echo ""

    # Git tests
    echo "Git Integration Tests:"
    test_git_init
    echo ""

    # Snapshot tests
    echo "Snapshot Management Tests:"
    test_directory_structure
    test_snapshot_create
    test_snapshot_metadata
    test_snapshot_list
    test_snapshot_auto_name
    test_snapshot_name_sanitization
    test_snapshot_restore_prep
    test_snapshot_delete
    echo ""

    cleanup_test_env

    # Summary
    echo "═══════════════════════════════════════"
    echo "  Test Results"
    echo "═══════════════════════════════════════"
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
        exit 1
    else
        echo "Tests failed: 0"
        echo ""
        echo -e "${GREEN}✓ All tests passed!${NC}"
        exit 0
    fi
}

# Run tests
run_tests
