#!/bin/bash
# Run all test suites

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "═══════════════════════════════════════"
echo "  claude-code-sync Test Suite"
echo "═══════════════════════════════════════"
echo ""

# Run test_utils.sh
if [ -f "$SCRIPT_DIR/test_utils.sh" ]; then
    echo "Running test_utils.sh..."
    "$SCRIPT_DIR/test_utils.sh"
    echo ""
fi

echo "═══════════════════════════════════════"
echo "  All Tests Complete"
echo "═══════════════════════════════════════"
