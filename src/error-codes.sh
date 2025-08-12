#!/usr/bin/env bash
# Claude Auto-Tee Error Code System
# Comprehensive error classification and reporting

# Error Code Categories (Exit Codes 1-99)
# 1-9:   Input/Configuration Errors
# 10-19: Temp Directory/File System Errors  
# 20-29: Resource/Space Errors
# 30-39: Command Execution Errors
# 40-49: Output Processing Errors
# 50-59: Cleanup/Lifecycle Errors
# 60-69: Platform/Compatibility Errors
# 70-79: Permission/Security Errors
# 80-89: Network/External Service Errors
# 90-99: Internal/Unexpected Errors

# Input/Configuration Errors (1-9)
readonly ERR_INVALID_INPUT=1
readonly ERR_MALFORMED_JSON=2
readonly ERR_MISSING_COMMAND=3
readonly ERR_INVALID_CONFIG=4
readonly ERR_UNSUPPORTED_MODE=5

# Temp Directory/File System Errors (10-19)
readonly ERR_NO_TEMP_DIR=10
readonly ERR_TEMP_DIR_NOT_WRITABLE=11
readonly ERR_TEMP_FILE_CREATE_FAILED=12
readonly ERR_TEMP_FILE_WRITE_FAILED=13
readonly ERR_TEMP_FILE_READ_FAILED=14
readonly ERR_TEMP_DIR_NOT_FOUND=15

# Resource/Space Errors (20-29)
readonly ERR_INSUFFICIENT_SPACE=20
readonly ERR_DISK_FULL=21
readonly ERR_QUOTA_EXCEEDED=22
readonly ERR_SPACE_CHECK_FAILED=23
readonly ERR_RESOURCE_EXHAUSTED=24

# Command Execution Errors (30-39)
readonly ERR_COMMAND_NOT_FOUND=30
readonly ERR_COMMAND_TIMEOUT=31
readonly ERR_COMMAND_KILLED=32
readonly ERR_COMMAND_INVALID=33
readonly ERR_PIPE_BROKEN=34
readonly ERR_EXECUTION_FAILED=35

# Output Processing Errors (40-49)  
readonly ERR_OUTPUT_TOO_LARGE=40
readonly ERR_OUTPUT_BINARY=41
readonly ERR_OUTPUT_CORRUPT=42
readonly ERR_ENCODING_ERROR=43
readonly ERR_TEE_FAILED=44

# Cleanup/Lifecycle Errors (50-59)
readonly ERR_CLEANUP_FAILED=50
readonly ERR_TEMP_FILE_ORPHANED=51
readonly ERR_SIGNAL_HANDLER_FAILED=52
readonly ERR_LIFECYCLE_VIOLATION=53

# Platform/Compatibility Errors (60-69)
readonly ERR_PLATFORM_UNSUPPORTED=60
readonly ERR_SHELL_INCOMPATIBLE=61
readonly ERR_FEATURE_UNAVAILABLE=62
readonly ERR_VERSION_MISMATCH=63

# Permission/Security Errors (70-79)
readonly ERR_PERMISSION_DENIED=70
readonly ERR_ACCESS_FORBIDDEN=71
readonly ERR_SECURITY_VIOLATION=72
readonly ERR_PRIVILEGE_REQUIRED=73

# Network/External Service Errors (80-89)
readonly ERR_NETWORK_UNAVAILABLE=80
readonly ERR_SERVICE_TIMEOUT=81
readonly ERR_EXTERNAL_FAILURE=82

# Internal/Unexpected Errors (90-99)
readonly ERR_INTERNAL_ERROR=90
readonly ERR_ASSERTION_FAILED=91
readonly ERR_CORRUPTED_STATE=92
readonly ERR_UNEXPECTED_CONDITION=99

# Error Message Mappings
# Use different approach for older bash compatibility
if declare -A test_array 2>/dev/null; then
    declare -A ERROR_MESSAGES=(
    # Input/Configuration Errors
    [$ERR_INVALID_INPUT]="Invalid input provided"
    [$ERR_MALFORMED_JSON]="Malformed JSON input"
    [$ERR_MISSING_COMMAND]="No command specified in input"
    [$ERR_INVALID_CONFIG]="Invalid configuration parameters"
    [$ERR_UNSUPPORTED_MODE]="Unsupported operation mode"
    
    # Temp Directory/File System Errors
    [$ERR_NO_TEMP_DIR]="No suitable temp directory found"
    [$ERR_TEMP_DIR_NOT_WRITABLE]="Temp directory is not writable"
    [$ERR_TEMP_FILE_CREATE_FAILED]="Failed to create temp file"
    [$ERR_TEMP_FILE_WRITE_FAILED]="Failed to write to temp file"
    [$ERR_TEMP_FILE_READ_FAILED]="Failed to read from temp file"
    [$ERR_TEMP_DIR_NOT_FOUND]="Specified temp directory not found"
    
    # Resource/Space Errors
    [$ERR_INSUFFICIENT_SPACE]="Insufficient disk space for temp file"
    [$ERR_DISK_FULL]="Disk full during operation"
    [$ERR_QUOTA_EXCEEDED]="Disk quota exceeded"
    [$ERR_SPACE_CHECK_FAILED]="Unable to check available disk space"
    [$ERR_RESOURCE_EXHAUSTED]="System resources exhausted"
    
    # Command Execution Errors
    [$ERR_COMMAND_NOT_FOUND]="Command not found"
    [$ERR_COMMAND_TIMEOUT]="Command execution timed out"
    [$ERR_COMMAND_KILLED]="Command was terminated"
    [$ERR_COMMAND_INVALID]="Invalid command syntax"
    [$ERR_PIPE_BROKEN]="Broken pipe in command chain"
    [$ERR_EXECUTION_FAILED]="Command execution failed"
    
    # Output Processing Errors
    [$ERR_OUTPUT_TOO_LARGE]="Command output exceeds size limits"
    [$ERR_OUTPUT_BINARY]="Binary output not supported"
    [$ERR_OUTPUT_CORRUPT]="Output data appears corrupted"
    [$ERR_ENCODING_ERROR]="Character encoding error"
    [$ERR_TEE_FAILED]="Failed to tee command output"
    
    # Cleanup/Lifecycle Errors
    [$ERR_CLEANUP_FAILED]="Temp file cleanup failed"
    [$ERR_TEMP_FILE_ORPHANED]="Temp file became orphaned"
    [$ERR_SIGNAL_HANDLER_FAILED]="Signal handler setup failed"
    [$ERR_LIFECYCLE_VIOLATION]="Lifecycle state violation"
    
    # Platform/Compatibility Errors
    [$ERR_PLATFORM_UNSUPPORTED]="Platform not supported"
    [$ERR_SHELL_INCOMPATIBLE]="Shell incompatible"
    [$ERR_FEATURE_UNAVAILABLE]="Required feature unavailable"
    [$ERR_VERSION_MISMATCH]="Version compatibility mismatch"
    
    # Permission/Security Errors
    [$ERR_PERMISSION_DENIED]="Permission denied"
    [$ERR_ACCESS_FORBIDDEN]="Access forbidden"
    [$ERR_SECURITY_VIOLATION]="Security policy violation"
    [$ERR_PRIVILEGE_REQUIRED]="Elevated privileges required"
    
    # Network/External Service Errors
    [$ERR_NETWORK_UNAVAILABLE]="Network unavailable"
    [$ERR_SERVICE_TIMEOUT]="External service timeout"
    [$ERR_EXTERNAL_FAILURE]="External service failure"
    
    # Internal/Unexpected Errors
    [$ERR_INTERNAL_ERROR]="Internal error occurred"
    [$ERR_ASSERTION_FAILED]="Internal assertion failed"
    [$ERR_CORRUPTED_STATE]="Internal state corrupted"
    [$ERR_UNEXPECTED_CONDITION]="Unexpected condition encountered"
)
else
    # Fallback for older bash versions - use functions
    get_error_message_fallback() {
        case "$1" in
            $ERR_INVALID_INPUT) echo "Invalid input provided" ;;
            $ERR_MALFORMED_JSON) echo "Malformed JSON input" ;;
            $ERR_MISSING_COMMAND) echo "No command specified in input" ;;
            $ERR_INVALID_CONFIG) echo "Invalid configuration parameters" ;;
            $ERR_UNSUPPORTED_MODE) echo "Unsupported operation mode" ;;
            $ERR_NO_TEMP_DIR) echo "No suitable temp directory found" ;;
            $ERR_TEMP_DIR_NOT_WRITABLE) echo "Temp directory is not writable" ;;
            $ERR_TEMP_FILE_CREATE_FAILED) echo "Failed to create temp file" ;;
            $ERR_TEMP_FILE_WRITE_FAILED) echo "Failed to write to temp file" ;;
            $ERR_TEMP_FILE_READ_FAILED) echo "Failed to read from temp file" ;;
            $ERR_TEMP_DIR_NOT_FOUND) echo "Specified temp directory not found" ;;
            $ERR_INSUFFICIENT_SPACE) echo "Insufficient disk space for temp file" ;;
            $ERR_DISK_FULL) echo "Disk full during operation" ;;
            $ERR_QUOTA_EXCEEDED) echo "Disk quota exceeded" ;;
            $ERR_SPACE_CHECK_FAILED) echo "Unable to check available disk space" ;;
            $ERR_RESOURCE_EXHAUSTED) echo "System resources exhausted" ;;
            $ERR_COMMAND_NOT_FOUND) echo "Command not found" ;;
            $ERR_COMMAND_TIMEOUT) echo "Command execution timed out" ;;
            $ERR_COMMAND_KILLED) echo "Command was terminated" ;;
            $ERR_COMMAND_INVALID) echo "Invalid command syntax" ;;
            $ERR_PIPE_BROKEN) echo "Broken pipe in command chain" ;;
            $ERR_EXECUTION_FAILED) echo "Command execution failed" ;;
            $ERR_OUTPUT_TOO_LARGE) echo "Command output exceeds size limits" ;;
            $ERR_OUTPUT_BINARY) echo "Binary output not supported" ;;
            $ERR_OUTPUT_CORRUPT) echo "Output data appears corrupted" ;;
            $ERR_ENCODING_ERROR) echo "Character encoding error" ;;
            $ERR_TEE_FAILED) echo "Failed to tee command output" ;;
            $ERR_CLEANUP_FAILED) echo "Temp file cleanup failed" ;;
            $ERR_TEMP_FILE_ORPHANED) echo "Temp file became orphaned" ;;
            $ERR_SIGNAL_HANDLER_FAILED) echo "Signal handler setup failed" ;;
            $ERR_LIFECYCLE_VIOLATION) echo "Lifecycle state violation" ;;
            $ERR_PLATFORM_UNSUPPORTED) echo "Platform not supported" ;;
            $ERR_SHELL_INCOMPATIBLE) echo "Shell incompatible" ;;
            $ERR_FEATURE_UNAVAILABLE) echo "Required feature unavailable" ;;
            $ERR_VERSION_MISMATCH) echo "Version compatibility mismatch" ;;
            $ERR_PERMISSION_DENIED) echo "Permission denied" ;;
            $ERR_ACCESS_FORBIDDEN) echo "Access forbidden" ;;
            $ERR_SECURITY_VIOLATION) echo "Security policy violation" ;;
            $ERR_PRIVILEGE_REQUIRED) echo "Elevated privileges required" ;;
            $ERR_NETWORK_UNAVAILABLE) echo "Network unavailable" ;;
            $ERR_SERVICE_TIMEOUT) echo "External service timeout" ;;
            $ERR_EXTERNAL_FAILURE) echo "External service failure" ;;
            $ERR_INTERNAL_ERROR) echo "Internal error occurred" ;;
            $ERR_ASSERTION_FAILED) echo "Internal assertion failed" ;;
            $ERR_CORRUPTED_STATE) echo "Internal state corrupted" ;;
            $ERR_UNEXPECTED_CONDITION) echo "Unexpected condition encountered" ;;
            *) echo "Unknown error code: $1" ;;
        esac
    }
fi

# Error Categories for Classification
if declare -A test_array2 2>/dev/null; then
    declare -A ERROR_CATEGORIES=(
    [$ERR_INVALID_INPUT]="input"
    [$ERR_MALFORMED_JSON]="input"
    [$ERR_MISSING_COMMAND]="input"
    [$ERR_INVALID_CONFIG]="input"
    [$ERR_UNSUPPORTED_MODE]="input"
    
    [$ERR_NO_TEMP_DIR]="filesystem"
    [$ERR_TEMP_DIR_NOT_WRITABLE]="filesystem"
    [$ERR_TEMP_FILE_CREATE_FAILED]="filesystem"
    [$ERR_TEMP_FILE_WRITE_FAILED]="filesystem"
    [$ERR_TEMP_FILE_READ_FAILED]="filesystem"
    [$ERR_TEMP_DIR_NOT_FOUND]="filesystem"
    
    [$ERR_INSUFFICIENT_SPACE]="resource"
    [$ERR_DISK_FULL]="resource"
    [$ERR_QUOTA_EXCEEDED]="resource"
    [$ERR_SPACE_CHECK_FAILED]="resource"
    [$ERR_RESOURCE_EXHAUSTED]="resource"
    
    [$ERR_COMMAND_NOT_FOUND]="execution"
    [$ERR_COMMAND_TIMEOUT]="execution"
    [$ERR_COMMAND_KILLED]="execution"
    [$ERR_COMMAND_INVALID]="execution"
    [$ERR_PIPE_BROKEN]="execution"
    [$ERR_EXECUTION_FAILED]="execution"
    
    [$ERR_OUTPUT_TOO_LARGE]="output"
    [$ERR_OUTPUT_BINARY]="output"
    [$ERR_OUTPUT_CORRUPT]="output"
    [$ERR_ENCODING_ERROR]="output"
    [$ERR_TEE_FAILED]="output"
    
    [$ERR_CLEANUP_FAILED]="lifecycle"
    [$ERR_TEMP_FILE_ORPHANED]="lifecycle"
    [$ERR_SIGNAL_HANDLER_FAILED]="lifecycle"
    [$ERR_LIFECYCLE_VIOLATION]="lifecycle"
    
    [$ERR_PLATFORM_UNSUPPORTED]="platform"
    [$ERR_SHELL_INCOMPATIBLE]="platform"
    [$ERR_FEATURE_UNAVAILABLE]="platform"
    [$ERR_VERSION_MISMATCH]="platform"
    
    [$ERR_PERMISSION_DENIED]="permission"
    [$ERR_ACCESS_FORBIDDEN]="permission"
    [$ERR_SECURITY_VIOLATION]="permission"
    [$ERR_PRIVILEGE_REQUIRED]="permission"
    
    [$ERR_NETWORK_UNAVAILABLE]="network"
    [$ERR_SERVICE_TIMEOUT]="network"
    [$ERR_EXTERNAL_FAILURE]="network"
    
    [$ERR_INTERNAL_ERROR]="internal"
    [$ERR_ASSERTION_FAILED]="internal"
    [$ERR_CORRUPTED_STATE]="internal"
    [$ERR_UNEXPECTED_CONDITION]="internal"
)
else
    # Fallback for older bash versions
    get_error_category_fallback() {
        case "$1" in
            $ERR_INVALID_INPUT|$ERR_MALFORMED_JSON|$ERR_MISSING_COMMAND|$ERR_INVALID_CONFIG|$ERR_UNSUPPORTED_MODE) echo "input" ;;
            $ERR_NO_TEMP_DIR|$ERR_TEMP_DIR_NOT_WRITABLE|$ERR_TEMP_FILE_CREATE_FAILED|$ERR_TEMP_FILE_WRITE_FAILED|$ERR_TEMP_FILE_READ_FAILED|$ERR_TEMP_DIR_NOT_FOUND) echo "filesystem" ;;
            $ERR_INSUFFICIENT_SPACE|$ERR_DISK_FULL|$ERR_QUOTA_EXCEEDED|$ERR_SPACE_CHECK_FAILED|$ERR_RESOURCE_EXHAUSTED) echo "resource" ;;
            $ERR_COMMAND_NOT_FOUND|$ERR_COMMAND_TIMEOUT|$ERR_COMMAND_KILLED|$ERR_COMMAND_INVALID|$ERR_PIPE_BROKEN|$ERR_EXECUTION_FAILED) echo "execution" ;;
            $ERR_OUTPUT_TOO_LARGE|$ERR_OUTPUT_BINARY|$ERR_OUTPUT_CORRUPT|$ERR_ENCODING_ERROR|$ERR_TEE_FAILED) echo "output" ;;
            $ERR_CLEANUP_FAILED|$ERR_TEMP_FILE_ORPHANED|$ERR_SIGNAL_HANDLER_FAILED|$ERR_LIFECYCLE_VIOLATION) echo "lifecycle" ;;
            $ERR_PLATFORM_UNSUPPORTED|$ERR_SHELL_INCOMPATIBLE|$ERR_FEATURE_UNAVAILABLE|$ERR_VERSION_MISMATCH) echo "platform" ;;
            $ERR_PERMISSION_DENIED|$ERR_ACCESS_FORBIDDEN|$ERR_SECURITY_VIOLATION|$ERR_PRIVILEGE_REQUIRED) echo "permission" ;;
            $ERR_NETWORK_UNAVAILABLE|$ERR_SERVICE_TIMEOUT|$ERR_EXTERNAL_FAILURE) echo "network" ;;
            $ERR_INTERNAL_ERROR|$ERR_ASSERTION_FAILED|$ERR_CORRUPTED_STATE|$ERR_UNEXPECTED_CONDITION) echo "internal" ;;
            *) echo "unknown" ;;
        esac
    }
fi

# Severity Levels
if declare -A test_array3 2>/dev/null; then
    declare -A ERROR_SEVERITY=(
    # Input errors - usually user fixable
    [$ERR_INVALID_INPUT]="error"
    [$ERR_MALFORMED_JSON]="error"
    [$ERR_MISSING_COMMAND]="error"
    [$ERR_INVALID_CONFIG]="error"
    [$ERR_UNSUPPORTED_MODE]="error"
    
    # Filesystem errors - system/environment issues
    [$ERR_NO_TEMP_DIR]="fatal"
    [$ERR_TEMP_DIR_NOT_WRITABLE]="fatal"
    [$ERR_TEMP_FILE_CREATE_FAILED]="error"
    [$ERR_TEMP_FILE_WRITE_FAILED]="error"
    [$ERR_TEMP_FILE_READ_FAILED]="error"
    [$ERR_TEMP_DIR_NOT_FOUND]="error"
    
    # Resource errors - system capacity issues
    [$ERR_INSUFFICIENT_SPACE]="warning"
    [$ERR_DISK_FULL]="error"
    [$ERR_QUOTA_EXCEEDED]="error"
    [$ERR_SPACE_CHECK_FAILED]="warning"
    [$ERR_RESOURCE_EXHAUSTED]="fatal"
    
    # Execution errors - command-related
    [$ERR_COMMAND_NOT_FOUND]="error"
    [$ERR_COMMAND_TIMEOUT]="warning"
    [$ERR_COMMAND_KILLED]="warning"
    [$ERR_COMMAND_INVALID]="error"
    [$ERR_PIPE_BROKEN]="error"
    [$ERR_EXECUTION_FAILED]="error"
    
    # Output processing - data handling issues
    [$ERR_OUTPUT_TOO_LARGE]="warning"
    [$ERR_OUTPUT_BINARY]="info"
    [$ERR_OUTPUT_CORRUPT]="error"
    [$ERR_ENCODING_ERROR]="warning"
    [$ERR_TEE_FAILED]="error"
    
    # Lifecycle - cleanup and management
    [$ERR_CLEANUP_FAILED]="warning"
    [$ERR_TEMP_FILE_ORPHANED]="info"
    [$ERR_SIGNAL_HANDLER_FAILED]="warning"
    [$ERR_LIFECYCLE_VIOLATION]="error"
    
    # Platform compatibility
    [$ERR_PLATFORM_UNSUPPORTED]="fatal"
    [$ERR_SHELL_INCOMPATIBLE]="error"
    [$ERR_FEATURE_UNAVAILABLE]="warning"
    [$ERR_VERSION_MISMATCH]="warning"
    
    # Security and permissions
    [$ERR_PERMISSION_DENIED]="error"
    [$ERR_ACCESS_FORBIDDEN]="error"
    [$ERR_SECURITY_VIOLATION]="fatal"
    [$ERR_PRIVILEGE_REQUIRED]="error"
    
    # Network and external
    [$ERR_NETWORK_UNAVAILABLE]="warning"
    [$ERR_SERVICE_TIMEOUT]="warning"
    [$ERR_EXTERNAL_FAILURE]="error"
    
    # Internal errors - bugs or corruption
    [$ERR_INTERNAL_ERROR]="fatal"
    [$ERR_ASSERTION_FAILED]="fatal"
    [$ERR_CORRUPTED_STATE]="fatal"
    [$ERR_UNEXPECTED_CONDITION]="fatal"
    )
else
    # Fallback for older bash versions
    get_error_severity_fallback() {
        case "$1" in
            $ERR_INVALID_INPUT|$ERR_MALFORMED_JSON|$ERR_MISSING_COMMAND|$ERR_INVALID_CONFIG|$ERR_UNSUPPORTED_MODE) echo "error" ;;
            $ERR_NO_TEMP_DIR|$ERR_TEMP_DIR_NOT_WRITABLE|$ERR_RESOURCE_EXHAUSTED|$ERR_PLATFORM_UNSUPPORTED|$ERR_SECURITY_VIOLATION|$ERR_INTERNAL_ERROR|$ERR_ASSERTION_FAILED|$ERR_CORRUPTED_STATE|$ERR_UNEXPECTED_CONDITION) echo "fatal" ;;
            $ERR_TEMP_FILE_CREATE_FAILED|$ERR_TEMP_FILE_WRITE_FAILED|$ERR_TEMP_FILE_READ_FAILED|$ERR_TEMP_DIR_NOT_FOUND|$ERR_DISK_FULL|$ERR_QUOTA_EXCEEDED|$ERR_COMMAND_NOT_FOUND|$ERR_COMMAND_INVALID|$ERR_PIPE_BROKEN|$ERR_EXECUTION_FAILED|$ERR_OUTPUT_CORRUPT|$ERR_TEE_FAILED|$ERR_LIFECYCLE_VIOLATION|$ERR_SHELL_INCOMPATIBLE|$ERR_PERMISSION_DENIED|$ERR_ACCESS_FORBIDDEN|$ERR_PRIVILEGE_REQUIRED|$ERR_EXTERNAL_FAILURE) echo "error" ;;
            $ERR_INSUFFICIENT_SPACE|$ERR_SPACE_CHECK_FAILED|$ERR_COMMAND_TIMEOUT|$ERR_COMMAND_KILLED|$ERR_OUTPUT_TOO_LARGE|$ERR_ENCODING_ERROR|$ERR_CLEANUP_FAILED|$ERR_SIGNAL_HANDLER_FAILED|$ERR_FEATURE_UNAVAILABLE|$ERR_VERSION_MISMATCH|$ERR_NETWORK_UNAVAILABLE|$ERR_SERVICE_TIMEOUT) echo "warning" ;;
            $ERR_OUTPUT_BINARY|$ERR_TEMP_FILE_ORPHANED) echo "info" ;;
            *) echo "unknown" ;;
        esac
    }
fi

# Error Reporting Functions

# Basic error reporting
report_error() {
    local error_code="$1"
    local context="${2:-}"
    local exit_after="${3:-true}"
    
    local message
    local category 
    local severity
    if declare -A test_array 2>/dev/null; then
        message="${ERROR_MESSAGES[$error_code]:-Unknown error}"
        category="${ERROR_CATEGORIES[$error_code]:-unknown}"
        severity="${ERROR_SEVERITY[$error_code]:-error}"
    else
        message=$(get_error_message_fallback "$error_code")
        category=$(get_error_category_fallback "$error_code")
        severity=$(get_error_severity_fallback "$error_code")
    fi
    
    # Format error message
    local formatted_message="[ERROR $error_code] $message"
    if [ -n "$context" ]; then
        formatted_message="$formatted_message: $context"
    fi
    
    echo "$formatted_message" >&2
    
    # Verbose mode additional information
    if is_verbose_mode 2>/dev/null; then
        echo "[VERBOSE] Error category: $category" >&2
        echo "[VERBOSE] Error severity: $severity" >&2
    fi
    
    # Exit if requested
    if [ "$exit_after" = "true" ]; then
        exit "$error_code"
    fi
    
    return "$error_code"
}

# Structured error reporting (JSON format)
report_error_json() {
    local error_code="$1"
    local context="${2:-}"
    local exit_after="${3:-true}"
    
    local message
    local category
    local severity
    if declare -A test_array 2>/dev/null; then
        message="${ERROR_MESSAGES[$error_code]:-Unknown error}"
        category="${ERROR_CATEGORIES[$error_code]:-unknown}"
        severity="${ERROR_SEVERITY[$error_code]:-error}"
    else
        message=$(get_error_message_fallback "$error_code")
        category=$(get_error_category_fallback "$error_code")
        severity=$(get_error_severity_fallback "$error_code")
    fi
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Create JSON error object
    cat >&2 <<EOF
{
  "error": {
    "code": $error_code,
    "message": "$message",
    "context": "$context",
    "category": "$category",
    "severity": "$severity",
    "timestamp": "$timestamp",
    "tool": "claude-auto-tee"
  }
}
EOF
    
    if [ "$exit_after" = "true" ]; then
        exit "$error_code"
    fi
    
    return "$error_code"
}

# Warning reporting (non-fatal)
report_warning() {
    local error_code="$1"
    local context="${2:-}"
    
    local message
    local category
    if declare -A test_array 2>/dev/null; then
        message="${ERROR_MESSAGES[$error_code]:-Unknown warning}"
        category="${ERROR_CATEGORIES[$error_code]:-unknown}"
    else
        message=$(get_error_message_fallback "$error_code")
        category=$(get_error_category_fallback "$error_code")
    fi
    
    echo "[WARNING $error_code] $message${context:+: $context}" >&2
    
    if is_verbose_mode 2>/dev/null; then
        echo "[VERBOSE] Warning category: $category" >&2
    fi
    
    return 0
}

# Assertion function for internal error checking
assert() {
    local condition="$1"
    local message="${2:-Assertion failed}"
    
    # Basic validation to prevent code injection in assertions
    if echo "$condition" | grep -qE '(;|\\||&|\\$\\(|`)'; then
        report_error $ERR_ASSERTION_FAILED "Unsafe assertion condition rejected: $message"
        return
    fi
    
    if ! eval "$condition"; then
        report_error $ERR_ASSERTION_FAILED "$message ($condition)"
    fi
}

# Error context management  
ERROR_CONTEXT=""

set_error_context() {
    ERROR_CONTEXT="$1"
}

clear_error_context() {
    ERROR_CONTEXT=""
}

# Context-aware error reporting
report_error_with_context() {
    local error_code="$1"
    local additional_context="${2:-}"
    local exit_after="${3:-true}"
    
    local full_context="$ERROR_CONTEXT"
    if [ -n "$additional_context" ]; then
        if [ -n "$full_context" ]; then
            full_context="$full_context: $additional_context"
        else
            full_context="$additional_context"
        fi
    fi
    
    report_error "$error_code" "$full_context" "$exit_after"
}

# Error code validation
is_valid_error_code() {
    local code="$1"
    if declare -A test_array 2>/dev/null; then
        [ -n "${ERROR_MESSAGES[$code]:-}" ]
    else
        [ "$(get_error_message_fallback "$code")" != "Unknown error code: $code" ]
    fi
}

# Get error information
get_error_message() {
    local code="$1"
    if declare -A test_array 2>/dev/null; then
        echo "${ERROR_MESSAGES[$code]:-Unknown error code: $code}"
    else
        get_error_message_fallback "$code"
    fi
}

get_error_category() {
    local code="$1"
    if declare -A test_array 2>/dev/null; then
        echo "${ERROR_CATEGORIES[$code]:-unknown}"
    else
        get_error_category_fallback "$code"
    fi
}

get_error_severity() {
    local code="$1"
    if declare -A test_array 2>/dev/null; then
        echo "${ERROR_SEVERITY[$code]:-unknown}"
    else
        get_error_severity_fallback "$code"
    fi
}

# List all error codes (utility function)
list_error_codes() {
    local category_filter="${1:-}"
    
    echo "Claude Auto-Tee Error Codes:"
    echo "============================"
    
    for code in $(printf '%s\n' "${!ERROR_MESSAGES[@]}" | sort -n); do
        local message="${ERROR_MESSAGES[$code]}"
        local category="${ERROR_CATEGORIES[$code]}"
        local severity="${ERROR_SEVERITY[$code]}"
        
        # Filter by category if specified
        if [ -n "$category_filter" ] && [ "$category" != "$category_filter" ]; then
            continue
        fi
        
        printf "%3d: %-50s [%s/%s]\n" "$code" "$message" "$category" "$severity"
    done
}

# Export error code constants for use in main script
export ERR_INVALID_INPUT ERR_MALFORMED_JSON ERR_MISSING_COMMAND ERR_INVALID_CONFIG ERR_UNSUPPORTED_MODE
export ERR_NO_TEMP_DIR ERR_TEMP_DIR_NOT_WRITABLE ERR_TEMP_FILE_CREATE_FAILED ERR_TEMP_FILE_WRITE_FAILED
export ERR_TEMP_FILE_READ_FAILED ERR_TEMP_DIR_NOT_FOUND
export ERR_INSUFFICIENT_SPACE ERR_DISK_FULL ERR_QUOTA_EXCEEDED ERR_SPACE_CHECK_FAILED ERR_RESOURCE_EXHAUSTED
export ERR_COMMAND_NOT_FOUND ERR_COMMAND_TIMEOUT ERR_COMMAND_KILLED ERR_COMMAND_INVALID ERR_PIPE_BROKEN
export ERR_EXECUTION_FAILED ERR_OUTPUT_TOO_LARGE ERR_OUTPUT_BINARY ERR_OUTPUT_CORRUPT ERR_ENCODING_ERROR
export ERR_TEE_FAILED ERR_CLEANUP_FAILED ERR_TEMP_FILE_ORPHANED ERR_SIGNAL_HANDLER_FAILED
export ERR_LIFECYCLE_VIOLATION ERR_PLATFORM_UNSUPPORTED ERR_SHELL_INCOMPATIBLE ERR_FEATURE_UNAVAILABLE
export ERR_VERSION_MISMATCH ERR_PERMISSION_DENIED ERR_ACCESS_FORBIDDEN ERR_SECURITY_VIOLATION
export ERR_PRIVILEGE_REQUIRED ERR_NETWORK_UNAVAILABLE ERR_SERVICE_TIMEOUT ERR_EXTERNAL_FAILURE
export ERR_INTERNAL_ERROR ERR_ASSERTION_FAILED ERR_CORRUPTED_STATE ERR_UNEXPECTED_CONDITION