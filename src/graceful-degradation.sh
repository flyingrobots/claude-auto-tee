#!/usr/bin/env bash
# Claude Auto-Tee Graceful Degradation Implementation
# Provides fail-safe fallback mechanisms for common failure scenarios

# Source error codes if not already loaded
if [ -z "$ERR_NO_TEMP_DIR" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/error-codes.sh"
fi

# Degradation configuration constants
readonly MIN_SPACE_BYTES=$((1024 * 1024))                   # 1MB minimum space requirement
readonly MAX_COMMAND_LENGTH=10000                           # Maximum safe command length
readonly TEMP_FILE_PREFIX=".claude-test-"                  # Prefix for temp test files

# Degradation configuration
CLAUDE_DEGRADATION_MODE=${CLAUDE_DEGRADATION_MODE:-auto}    # auto|strict|permissive
CLAUDE_RETRY_ATTEMPTS=${CLAUDE_RETRY_ATTEMPTS:-3}           # number of retry attempts
CLAUDE_RETRY_DELAY=${CLAUDE_RETRY_DELAY:-1}                # initial retry delay seconds
CLAUDE_FAIL_FAST=${CLAUDE_FAIL_FAST:-false}                # override fail-safe behavior
CLAUDE_METRICS_LOG=${CLAUDE_METRICS_LOG:-}                 # optional metrics logging

# Global state
ORIGINAL_INPUT=""
DEGRADATION_ACTIVE="false"

# Utility functions for compatibility
verbose_log() {
    if is_verbose_mode 2>/dev/null; then
        echo "[VERBOSE] $1" >&2
    fi
}

is_verbose_mode() {
    [ "${CLAUDE_AUTO_TEE_VERBOSE:-0}" = "1" ]
}

# Mock functions for testing - these would be implemented elsewhere
detect_temp_directory() {
    local temp_candidates=("/tmp" "$HOME/tmp" "$HOME" ".")
    for dir in "${temp_candidates[@]}"; do
        if [ -d "$dir" ] && [ -w "$dir" ]; then
            echo "$dir"
            return 0
        fi
    done
    return 1
}

get_available_space() {
    local dir="$1"
    if command -v df >/dev/null 2>&1; then
        df -k "$dir" 2>/dev/null | tail -1 | awk '{print $4 * 1024}'
    else
        echo "1000000"  # 1MB fallback
    fi
}

# Error context management functions
set_error_context() {
    ERROR_CONTEXT="$1"
}

clear_error_context() {
    ERROR_CONTEXT=""
}

# Initialize degradation system
initialize_degradation() {
    local original_input="$1"
    ORIGINAL_INPUT="$original_input"
    DEGRADATION_ACTIVE="false"
    
    # Configure behavior based on mode
    configure_degradation_behavior
    
    # Set up signal handlers for graceful exit
    trap 'handle_failure_gracefully $ERR_UNEXPECTED_CONDITION "Script interrupted" "$ORIGINAL_INPUT"' INT TERM
}

# Configure degradation behavior based on mode
configure_degradation_behavior() {
    case "$CLAUDE_DEGRADATION_MODE" in
        "strict")
            # Fail fast on any error - for debugging
            CLAUDE_FAIL_FAST=true
            CLAUDE_RETRY_ATTEMPTS=0
            verbose_log "Degradation mode: strict (fail-fast enabled)"
            ;;
        "permissive")  
            # Maximum tolerance - almost always pass through
            CLAUDE_RETRY_ATTEMPTS=5
            CLAUDE_RETRY_DELAY=0.5
            verbose_log "Degradation mode: permissive (maximum tolerance)"
            ;;
        "auto"|*)
            # Default balanced approach
            verbose_log "Degradation mode: auto (balanced fail-safe)"
            ;;
    esac
}

# Main degradation decision point
handle_failure_gracefully() {
    local error_code="$1"
    local context="$2"
    local original_input="${3:-$ORIGINAL_INPUT}"
    
    # Override with fail-fast if configured
    if [ "$CLAUDE_FAIL_FAST" = "true" ]; then
        report_error "$error_code" "$context" true
        return $error_code
    fi
    
    # Get error category for decision making
    local category=$(get_error_category "$error_code")
    
    case "$category" in
        "input"|"internal")
            # Fail-fast scenarios - user can fix these
            report_error "$error_code" "$context" true
            ;;
        "filesystem"|"resource"|"platform"|"permission")
            # Fail-safe scenarios - pass through with warning
            initiate_passthrough_mode "$error_code" "$context" "$original_input"
            ;;
        "execution"|"output")
            # Fail-safe with recovery attempt
            attempt_recovery "$error_code" "$context" "$original_input"
            ;;
        *)
            # Unknown category - be conservative, pass through
            report_warning $ERR_UNEXPECTED_CONDITION "Unknown error category: $category"
            initiate_passthrough_mode $ERR_UNEXPECTED_CONDITION "Unknown error category" "$original_input"
            ;;
    esac
}

# Pass-through mode activation
initiate_passthrough_mode() {
    local error_code="$1"
    local context="$2"  
    local original_input="$3"
    local test_mode="${4:-false}"
    
    DEGRADATION_ACTIVE="true"
    
    # Log degradation event
    log_degradation_event "$error_code" "passthrough"
    
    # Show user-friendly message
    show_degradation_message "$error_code" ""
    
    # Show detailed information in verbose mode
    show_degradation_details "$error_code"
    
    # Pass through original input unchanged
    echo "$original_input"
    
    # Exit unless in test mode
    if [ "$test_mode" != "true" ]; then
        exit 0
    fi
}

# Recovery attempt for execution/output errors
attempt_recovery() {
    local error_code="$1"
    local context="$2"
    local original_input="$3"
    
    local recovery_attempted=false
    
    # Log recovery attempt
    log_degradation_event "$error_code" "recovery_attempt"
    
    case "$error_code" in
        $ERR_TEMP_FILE_CREATE_FAILED)
            if attempt_alternative_temp_location; then
                verbose_log "Recovery successful: alternative temp location found"
                return 0
            fi
            recovery_attempted=true
            ;;
        $ERR_INSUFFICIENT_SPACE)
            if attempt_minimal_space_mode; then
                verbose_log "Recovery successful: minimal space mode activated"
                return 0
            fi
            recovery_attempted=true
            ;;
        $ERR_TEE_FAILED|$ERR_PIPE_BROKEN)
            if attempt_simple_execution; then
                verbose_log "Recovery successful: simple execution without tee"
                return 0
            fi
            recovery_attempted=true
            ;;
    esac
    
    # Recovery failed, fall back to pass-through
    if [ "$recovery_attempted" = "true" ]; then
        report_warning "$error_code" "Recovery failed, falling back to pass-through mode"
        log_degradation_event "$error_code" "recovery_failed"
    fi
    
    initiate_passthrough_mode "$error_code" "$context" "$original_input"
}

# Recovery mechanism: try alternative temp locations
attempt_alternative_temp_location() {
    verbose_log "Attempting alternative temp directory locations"
    
    local alt_locations=(
        "$HOME/tmp"
        "$HOME/.tmp" 
        "$HOME/.cache"
        "$HOME"
        "."
    )
    
    for alt_dir in "${alt_locations[@]}"; do
        # Skip if directory doesn't exist
        [ -d "$alt_dir" ] || continue
        
        # Test write access with atomic temp file creation to avoid race conditions
        local test_file
        if test_file=$(mktemp "$alt_dir/${TEMP_FILE_PREFIX}XXXXXX" 2>/dev/null); then
            rm -f "$test_file" 2>/dev/null
            verbose_log "Alternative temp location found: $alt_dir"
            export CLAUDE_TEMP_DIR_OVERRIDE="$alt_dir"
            return 0
        fi
    done
    
    verbose_log "No alternative temp locations available"
    return 1
}

# Recovery mechanism: minimal space mode
attempt_minimal_space_mode() {
    verbose_log "Attempting minimal space mode"
    
    # Set very conservative space requirements
    export CLAUDE_MIN_TEMP_SPACE=$MIN_SPACE_BYTES  # Use configured minimum
    export CLAUDE_SPACE_CHECK=warn                 # Warn but proceed
    
    # Try with reduced requirements
    local temp_dir="${CLAUDE_TEMP_DIR_OVERRIDE:-$(detect_temp_directory 2>/dev/null)}"
    if [ -n "$temp_dir" ]; then
        local available=$(get_available_space "$temp_dir" 2>/dev/null || echo 0)
        if [ "$available" -gt $MIN_SPACE_BYTES ]; then
            verbose_log "Minimal space mode activated with ${available} bytes available"
            return 0
        fi
    fi
    
    verbose_log "Insufficient space even for minimal mode"
    return 1
}

# Recovery mechanism: simple execution without tee
attempt_simple_execution() {
    verbose_log "Attempting simple execution without tee enhancement"
    
    # Extract original command with proper JSON parsing
    local original_command
    if command -v jq >/dev/null 2>&1; then
        original_command=$(echo "$ORIGINAL_INPUT" | jq -r '.tool.input.command // empty' 2>/dev/null)
    else
        # Fallback regex with validation
        original_command=$(echo "$ORIGINAL_INPUT" | sed -n 's/.*"command":"\([^"]*\(\\"[^"]*\)*\)".*/\1/p' | sed 's/\\"/"/g')
    fi
    
    # Validate extracted command is reasonable (basic security check)
    if [ -n "$original_command" ] && [ ${#original_command} -lt $MAX_COMMAND_LENGTH ]; then
        # Additional security: validate command doesn't contain dangerous patterns
        if echo "$original_command" | grep -qE '(;|\||&|\$\(|`).*\b(rm|dd|mkfs|format)\b'; then
            verbose_log "Command contains potentially dangerous patterns, refusing simple execution"
            return 1
        fi
        
        verbose_log "Executing original command without tee: $original_command"
        
        # Execute the original command with bash -c for better security than eval
        bash -c "$original_command"
        local exit_code=$?
        
        # Show success message
        if [ $exit_code -eq 0 ]; then
            echo "Command completed successfully (claude-auto-tee functionality disabled)" >&2
        else
            echo "Command completed with exit code $exit_code (claude-auto-tee functionality disabled)" >&2
        fi
        
        exit $exit_code
    fi
    
    verbose_log "Could not extract or validate original command for simple execution"
    return 1
}

# Smart retry with exponential backoff
smart_retry() {
    local operation="$1"
    local max_attempts="${CLAUDE_RETRY_ATTEMPTS:-3}"
    local initial_delay="${CLAUDE_RETRY_DELAY:-1}"
    
    local attempt=1
    # Ensure delay is an integer for arithmetic operations
    local delay
    delay=$(echo "$initial_delay" | cut -d. -f1)
    [ "$delay" -lt 1 ] && delay=1
    
    while [ $attempt -le $max_attempts ]; do
        verbose_log "Retry attempt $attempt of $max_attempts: $operation"
        
        if eval "$operation"; then
            verbose_log "Retry successful on attempt $attempt"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            verbose_log "Attempt $attempt failed, waiting ${delay}s before retry"
            sleep $delay
            # Use arithmetic expansion for better compatibility
            delay=$((delay * 2))
            attempt=$((attempt + 1))
        else
            break
        fi
    done
    
    verbose_log "All retry attempts failed after $max_attempts tries"
    return 1
}

# User messaging during degradation
show_degradation_message() {
    local error_code="$1"
    local user_action="$2"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "  claude-auto-tee: Functionality Temporarily Disabled" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "  Issue: $(get_error_message "$error_code")" >&2
    echo "  Impact: Your command will execute normally without output capture" >&2
    if [ -n "$user_action" ]; then
        echo "  Action: $user_action" >&2
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
}

# Detailed degradation information for verbose mode
show_degradation_details() {
    local error_code="$1"
    
    if is_verbose_mode 2>/dev/null; then
        echo "[VERBOSE] Degradation analysis:" >&2
        echo "[VERBOSE] - Error code: $error_code" >&2
        echo "[VERBOSE] - Error category: $(get_error_category "$error_code")" >&2
        echo "[VERBOSE] - Error severity: $(get_error_severity "$error_code")" >&2
        echo "[VERBOSE] - Degradation mode: $CLAUDE_DEGRADATION_MODE" >&2
        echo "[VERBOSE] - Fallback strategy: Pass-through mode" >&2
        echo "[VERBOSE] - Recovery attempts: ${CLAUDE_RETRY_ATTEMPTS:-0}" >&2
        echo "[VERBOSE] - Original input preserved: yes" >&2
    fi
}

# Log degradation events for monitoring
log_degradation_event() {
    local error_code="$1"
    local degradation_type="$2"
    
    if [ -n "$CLAUDE_METRICS_LOG" ]; then
        local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        local category=$(get_error_category "$error_code")
        echo "$timestamp,degradation,$error_code,$degradation_type,$category" >> "$CLAUDE_METRICS_LOG"
    fi
}

# Safe operation wrapper
safe_operation() {
    local operation="$1"
    local error_code="$2"
    local context="$3"
    
    # Set error context
    set_error_context "$context"
    
    # Try operation with retry if configured
    if [ "${CLAUDE_RETRY_ATTEMPTS:-0}" -gt 0 ]; then
        if smart_retry "$operation"; then
            clear_error_context
            return 0
        fi
    else
        if eval "$operation"; then
            clear_error_context
            return 0
        fi
    fi
    
    # Operation failed, handle gracefully
    handle_failure_gracefully "$error_code" "$context" "$ORIGINAL_INPUT"
    return $?
}

# Check if degradation is currently active
is_degradation_active() {
    [ "$DEGRADATION_ACTIVE" = "true" ]
}

# Emergency pass-through function
emergency_passthrough() {
    echo "EMERGENCY: claude-auto-tee encountered unexpected error, executing original command" >&2
    echo "$ORIGINAL_INPUT"
    exit 0
}

# Cleanup function for graceful shutdown
cleanup_degradation() {
    if [ -n "$CLAUDE_TEMP_DIR_OVERRIDE" ]; then
        unset CLAUDE_TEMP_DIR_OVERRIDE
    fi
    
    clear_error_context 2>/dev/null || true
    DEGRADATION_ACTIVE="false"
}

# Utility function to test degradation behavior
test_degradation() {
    local error_code="$1"
    local test_input='{"tool":{"name":"Bash","input":{"command":"echo test"}},"timeout":null}'
    
    echo "Testing degradation for error code $error_code" >&2
    initialize_degradation "$test_input"
    handle_failure_gracefully "$error_code" "Test scenario" "$test_input"
}

# Export functions for use in main script
export -f handle_failure_gracefully
export -f initiate_passthrough_mode  
export -f attempt_recovery
export -f safe_operation
export -f initialize_degradation
export -f cleanup_degradation
export -f is_degradation_active
export -f emergency_passthrough