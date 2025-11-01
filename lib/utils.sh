#!/bin/bash
# lib/utils.sh - Shared utilities and logging functions

# Color codes for terminal output (only set if not already set)
if [ -z "${CLAUDE_CODE_SYNC_COLORS_SET:-}" ]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m' # No Color
    readonly CLAUDE_CODE_SYNC_COLORS_SET=1
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
    # Map commands to apt package names
    declare -A cmd_to_pkg=(
        ["gpg"]="gnupg"
        ["tar"]="tar"
        ["gzip"]="gzip"
        ["sha256sum"]="coreutils"
        ["jq"]="jq"
        ["rsync"]="rsync"
        ["git"]="git"
    )

    local required_cmds=("gpg" "tar" "gzip" "sha256sum" "rsync")
    local optional_cmds=("jq" "git")
    local missing_required=()
    local missing_optional=()
    local packages_to_install=()

    # Check required dependencies
    for cmd in "${required_cmds[@]}"; do
        if ! command_exists "$cmd"; then
            missing_required+=("$cmd")
            packages_to_install+=("${cmd_to_pkg[$cmd]}")
        fi
    done

    # Check optional dependencies
    for cmd in "${optional_cmds[@]}"; do
        if ! command_exists "$cmd"; then
            missing_optional+=("$cmd")
        fi
    done

    # Handle missing required dependencies
    if [ ${#missing_required[@]} -gt 0 ]; then
        log_warn "Missing required dependencies: ${missing_required[*]}"
        echo ""

        if confirm_action "Install missing packages using apt? (${packages_to_install[*]})"; then
            log_info "Installing packages: ${packages_to_install[*]}"

            if sudo apt update && sudo apt install -y "${packages_to_install[@]}"; then
                log_info "✓ Successfully installed required packages"

                # Verify installation
                local still_missing=()
                for cmd in "${missing_required[@]}"; do
                    if ! command_exists "$cmd"; then
                        still_missing+=("$cmd")
                    fi
                done

                if [ ${#still_missing[@]} -gt 0 ]; then
                    log_error "Installation completed but commands still missing: ${still_missing[*]}"
                fi
            else
                log_error "Failed to install packages. Please install manually:\n  sudo apt install ${packages_to_install[*]}"
            fi
        else
            log_error "Required dependencies not installed. Install with:\n  sudo apt install ${packages_to_install[*]}"
        fi
    fi

    # Handle missing optional dependencies
    if [ ${#missing_optional[@]} -gt 0 ]; then
        log_warn "Missing optional dependencies: ${missing_optional[*]}"

        local optional_pkgs=()
        for cmd in "${missing_optional[@]}"; do
            optional_pkgs+=("${cmd_to_pkg[$cmd]}")
        done

        if [ "${FORCE:-false}" = "false" ]; then
            echo ""
            if confirm_action "Install optional packages? (${optional_pkgs[*]})"; then
                log_info "Installing optional packages: ${optional_pkgs[*]}"
                sudo apt install -y "${optional_pkgs[@]}" || log_warn "Some optional packages failed to install"
            else
                log_info "Skipping optional dependencies. Some features may be limited."
                log_info "  To install later: sudo apt install ${optional_pkgs[*]}"
            fi
        fi
    fi

    log_debug "Dependency check complete"
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
