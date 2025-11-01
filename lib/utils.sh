#!/bin/bash
# lib/utils.sh - Shared utilities and logging functions

# Color codes for terminal output (only set if not already set)
if [ -z "${CLAUDE_SYNC_COLORS_SET:-}" ]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m' # No Color
    readonly CLAUDE_SYNC_COLORS_SET=1
fi

# Check if colors should be disabled
if [ -t 1 ] && [ "${NO_COLOR:-0}" = "0" ]; then
    USE_COLOR=true
else
    USE_COLOR=false
fi

# Logging functions
log_info() {
    local msg="$1"
    if [ "$USE_COLOR" = true ]; then
        echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $msg"
    else
        echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $msg"
    fi
}

log_warn() {
    local msg="$1"
    if [ "$USE_COLOR" = true ]; then
        echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $msg" >&2
    else
        echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $msg" >&2
    fi
}

log_error() {
    local msg="$1"
    if [ "$USE_COLOR" = true ]; then
        echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $msg" >&2
    else
        echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $msg" >&2
    fi
    exit 1
}

log_debug() {
    local msg="$1"
    if [ "${VERBOSE:-false}" = "true" ]; then
        if [ "$USE_COLOR" = true ]; then
            echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $msg"
        else
            echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $msg"
        fi
    fi
}

# Interactive confirmation prompt
confirm_action() {
    local prompt="${1:-Continue?}"
    local response

    # Skip in non-interactive mode
    if [ "${FORCE:-false}" = "true" ]; then
        log_debug "Auto-confirming (force mode): $prompt"
        return 0
    fi

    read -p "$prompt [y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Get machine hostname
get_hostname() {
    hostname -s
}

# Get ISO 8601 timestamp
get_timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

# Get local timestamp for filenames
get_timestamp_filename() {
    date '+%Y%m%d-%H%M%S'
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Check required dependencies
check_dependencies() {
    local deps=("gpg" "tar" "gzip" "sha256sum" "jq")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing[*]}\nInstall with: sudo apt install ${missing[*]}"
    fi

    log_debug "All dependencies present"
}

# Ensure directory exists with proper permissions
ensure_directory() {
    local dir="$1"
    local perms="${2:-700}"

    if [ ! -d "$dir" ]; then
        log_debug "Creating directory: $dir"
        mkdir -p "$dir" || log_error "Failed to create directory: $dir"
        chmod "$perms" "$dir"
    fi
}

# Cleanup temporary files on exit
cleanup_temp() {
    local temp_dir="$1"
    if [ -d "$temp_dir" ]; then
        log_debug "Cleaning up temporary directory: $temp_dir"
        rm -rf "$temp_dir"
    fi
}

# Validate file exists
validate_file() {
    local file="$1"
    local description="${2:-File}"

    if [ ! -f "$file" ]; then
        log_error "$description not found: $file"
    fi
}

# Validate directory exists
validate_directory() {
    local dir="$1"
    local description="${2:-Directory}"

    if [ ! -d "$dir" ]; then
        log_error "$description not found: $dir"
    fi
}

# Get file size in human-readable format
get_file_size() {
    local file="$1"
    du -h "$file" 2>/dev/null | awk '{print $1}'
}

# Count files in directory
count_files() {
    local dir="$1"
    find "$dir" -type f 2>/dev/null | wc -l
}

# Colorize output (for manual use)
colorize() {
    local color="$1"
    local text="$2"

    if [ "$USE_COLOR" != true ]; then
        echo "$text"
        return
    fi

    case "$color" in
        red)    echo -e "${RED}${text}${NC}" ;;
        green)  echo -e "${GREEN}${text}${NC}" ;;
        yellow) echo -e "${YELLOW}${text}${NC}" ;;
        blue)   echo -e "${BLUE}${text}${NC}" ;;
        *)      echo "$text" ;;
    esac
}

# Export functions for use in other scripts
export -f log_info
export -f log_warn
export -f log_error
export -f log_debug
export -f confirm_action
export -f get_hostname
export -f get_timestamp
export -f get_timestamp_filename
export -f command_exists
export -f check_dependencies
export -f ensure_directory
export -f cleanup_temp
export -f validate_file
export -f validate_directory
export -f get_file_size
export -f count_files
export -f colorize
