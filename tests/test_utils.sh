#!/bin/bash
# Test suite for lib/utils.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/lib/utils.sh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Test helper
assert_equal() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    ((TESTS_RUN++))

    if [ "$expected" = "$actual" ]; then
        echo "✓ $test_name"
        ((TESTS_PASSED++))
    else
        echo "✗ $test_name"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
    fi
}

assert_success() {
    local command="$1"
    local test_name="$2"

    ((TESTS_RUN++))

    if eval "$command" &>/dev/null; then
        echo "✓ $test_name"
        ((TESTS_PASSED++))
    else
        echo "✗ $test_name (command failed)"
    fi
}

echo "Testing lib/utils.sh"
echo "===================="
echo ""

# Test get_hostname
test_hostname() {
    local hostname=$(get_hostname)
    [ -n "$hostname" ] && echo "✓ get_hostname returns value: $hostname" || echo "✗ get_hostname failed"
    ((TESTS_RUN++))
    [ -n "$hostname" ] && ((TESTS_PASSED++))
}

# Test get_timestamp
test_timestamp() {
    local timestamp=$(get_timestamp)
    if [[ "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
        echo "✓ get_timestamp returns ISO 8601 format"
        ((TESTS_PASSED++))
    else
        echo "✗ get_timestamp format incorrect: $timestamp"
    fi
    ((TESTS_RUN++))
}

# Test get_timestamp_filename
test_timestamp_filename() {
    local timestamp=$(get_timestamp_filename)
    if [[ "$timestamp" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
        echo "✓ get_timestamp_filename returns correct format"
        ((TESTS_PASSED++))
    else
        echo "✗ get_timestamp_filename format incorrect: $timestamp"
    fi
    ((TESTS_RUN++))
}

# Test command_exists
test_command_exists() {
    if command_exists "bash"; then
        echo "✓ command_exists detects bash"
        ((TESTS_PASSED++))
    else
        echo "✗ command_exists failed to detect bash"
    fi
    ((TESTS_RUN++))

    if ! command_exists "nonexistent_command_xyz"; then
        echo "✓ command_exists correctly reports missing command"
        ((TESTS_PASSED++))
    else
        echo "✗ command_exists false positive"
    fi
    ((TESTS_RUN++))
}

# Test ensure_directory
test_ensure_directory() {
    local test_dir="/tmp/claude-sync-test-$$"

    ensure_directory "$test_dir"

    if [ -d "$test_dir" ]; then
        echo "✓ ensure_directory creates directory"
        ((TESTS_PASSED++))
    else
        echo "✗ ensure_directory failed"
    fi
    ((TESTS_RUN++))

    # Cleanup
    rm -rf "$test_dir"
}

# Test count_files
test_count_files() {
    local test_dir="/tmp/claude-sync-test-$$"
    mkdir -p "$test_dir"
    touch "$test_dir/file1" "$test_dir/file2" "$test_dir/file3"

    local count=$(count_files "$test_dir")

    if [ "$count" = "3" ]; then
        echo "✓ count_files returns correct count"
        ((TESTS_PASSED++))
    else
        echo "✗ count_files returned $count, expected 3"
    fi
    ((TESTS_RUN++))

    # Cleanup
    rm -rf "$test_dir"
}

# Run tests
test_hostname
test_timestamp
test_timestamp_filename
test_command_exists
test_ensure_directory
test_count_files

# Summary
echo ""
echo "===================="
echo "Tests: $TESTS_PASSED/$TESTS_RUN passed"
echo "===================="

if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
    exit 0
else
    exit 1
fi
