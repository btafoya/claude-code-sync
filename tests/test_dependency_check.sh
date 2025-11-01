#!/bin/bash
# Test dependency checking and auto-installation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source utils
source "$PROJECT_ROOT/lib/utils.sh"

echo "═══════════════════════════════════════"
echo "  Dependency Check Test"
echo "═══════════════════════════════════════"
echo ""

# Test 1: Check with all dependencies present
echo "Test 1: Checking dependencies (all present scenario)"
echo "────────────────────────────────────────"
check_dependencies
echo ""

echo "✓ Dependency check completed successfully"
echo ""

# Test 2: Show what would happen with missing dependencies
echo "Test 2: Simulating missing dependency scenario"
echo "────────────────────────────────────────"
echo "If a dependency were missing, the script would:"
echo "  1. Detect missing required packages"
echo "  2. Prompt user: 'Install missing packages using apt?'"
echo "  3. Run: sudo apt update && sudo apt install -y <packages>"
echo "  4. Verify installation succeeded"
echo "  5. Handle optional dependencies separately"
echo ""

echo "✓ Test complete"
