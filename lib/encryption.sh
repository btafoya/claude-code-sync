#!/bin/bash
# lib/encryption.sh - Encryption and decryption engine

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Encryption configuration (only set if not already set)
if [ -z "${CLAUDE_SYNC_ENCRYPTION_SET:-}" ]; then
    readonly CIPHER_ALGO="AES256"
    readonly S2K_DIGEST="SHA512"
    readonly S2K_COUNT="65011712"
    readonly CLAUDE_SYNC_ENCRYPTION_SET=1
fi

# Prompt for password securely
prompt_password() {
    local prompt="${1:-Enter password}"
    local password
    local password_confirm

    # First attempt
    read -s -p "$prompt: " password
    echo

    # Confirm password
    read -s -p "Confirm password: " password_confirm
    echo

    # Verify passwords match
    if [ "$password" != "$password_confirm" ]; then
        log_error "Passwords do not match"
    fi

    # Check minimum length
    if [ ${#password} -lt 12 ]; then
        log_warn "Password is less than 12 characters (not recommended)"
        if ! confirm_action "Continue with weak password?"; then
            log_error "Aborted by user"
        fi
    fi

    echo "$password"
}

# Prompt for password (decrypt mode - no confirmation)
prompt_password_decrypt() {
    local prompt="${1:-Enter decryption password}"
    local password

    read -s -p "$prompt: " password
    echo

    if [ -z "$password" ]; then
        log_error "Password cannot be empty"
    fi

    echo "$password"
}

# Encrypt a single file
encrypt_file() {
    local input_file="$1"
    local output_file="$2"
    local password="$3"

    validate_file "$input_file" "Input file"

    log_debug "Encrypting: $input_file → $output_file"

    # Encrypt with GPG
    echo "$password" | gpg --batch --yes \
        --passphrase-fd 0 \
        --symmetric \
        --cipher-algo "$CIPHER_ALGO" \
        --s2k-mode 3 \
        --s2k-count "$S2K_COUNT" \
        --s2k-digest-algo "$S2K_DIGEST" \
        --compress-algo ZLIB \
        --output "$output_file" \
        "$input_file" 2>/dev/null

    if [ $? -ne 0 ]; then
        rm -f "$output_file"
        log_error "Encryption failed"
    fi

    log_debug "Encryption successful: $(get_file_size "$output_file")"
}

# Decrypt a single file
decrypt_file() {
    local input_file="$1"
    local output_file="$2"
    local password="$3"

    validate_file "$input_file" "Encrypted file"

    log_debug "Decrypting: $input_file → $output_file"

    # Decrypt with GPG
    echo "$password" | gpg --batch --yes \
        --passphrase-fd 0 \
        --decrypt \
        --output "$output_file" \
        "$input_file" 2>/dev/null

    if [ $? -ne 0 ]; then
        rm -f "$output_file"
        log_error "Decryption failed (wrong password or corrupted file)"
    fi

    log_debug "Decryption successful: $(get_file_size "$output_file")"
}

# Encrypt archive (tar.gz → tar.gz.gpg)
encrypt_archive() {
    local archive="$1"
    local encrypted="$2"
    local password="$3"

    log_info "Encrypting archive..."
    encrypt_file "$archive" "$encrypted" "$password"
}

# Decrypt archive (tar.gz.gpg → tar.gz)
decrypt_archive() {
    local encrypted="$1"
    local archive="$2"
    local password="$3"

    log_info "Decrypting archive..."
    decrypt_file "$encrypted" "$archive" "$password"
}

# Verify encryption works (round-trip test)
verify_encryption() {
    local test_file="/tmp/claude-sync-test-$$"
    local encrypted_file="${test_file}.gpg"
    local decrypted_file="${test_file}.dec"

    log_info "Testing encryption/decryption..."

    # Create test file
    echo "test data" > "$test_file"

    # Get password
    local password=$(prompt_password "Test encryption password")

    # Encrypt
    encrypt_file "$test_file" "$encrypted_file" "$password"

    # Decrypt
    decrypt_file "$encrypted_file" "$decrypted_file" "$password"

    # Compare
    if cmp -s "$test_file" "$decrypted_file"; then
        log_info "✓ Encryption verification successful"
        rm -f "$test_file" "$encrypted_file" "$decrypted_file"
        return 0
    else
        log_error "✗ Encryption verification failed"
    fi
}

# Generate SHA256 checksum
generate_checksum() {
    local file="$1"
    validate_file "$file" "File"

    sha256sum "$file" | awk '{print $1}'
}

# Verify checksum
verify_checksum() {
    local file="$1"
    local expected_checksum="$2"

    validate_file "$file" "File"

    local actual_checksum=$(generate_checksum "$file")

    if [ "$actual_checksum" = "$expected_checksum" ]; then
        log_debug "✓ Checksum verified"
        return 0
    else
        log_error "✗ Checksum mismatch\n  Expected: $expected_checksum\n  Actual:   $actual_checksum\n  File may be corrupted or tampered with"
    fi
}

# Export functions
export -f prompt_password
export -f prompt_password_decrypt
export -f encrypt_file
export -f decrypt_file
export -f encrypt_archive
export -f decrypt_archive
export -f verify_encryption
export -f generate_checksum
export -f verify_checksum
