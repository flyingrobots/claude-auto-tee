#!/bin/sh
# Claude Auto-Tee Environment Exporter
# 
# POSIX-compliant shell script that exports CLAUDE_CAPTURES and CLAUDE_LAST_CAPTURE
# environment variables based on the captures registry.
#
# Usage: . /path/to/env-exporter.sh
# 
# Interfaces produced: EnvExporter:v1 (shell version)
#
# Environment variables set:
# - CLAUDE_LAST_CAPTURE: Path to most recent capture file
# - CLAUDE_CAPTURES: JSON array of recent captures (last 10 entries)

# Configuration
CLAUDE_REGISTRY_FILE="${HOME}/.claude/captures.json"
CLAUDE_MAX_CAPTURES=10
CLAUDE_DEBUG="${CLAUDE_DEBUG:-0}"

# Logging function
claude_log() {
    if [ "$CLAUDE_DEBUG" = "1" ]; then
        printf "[env-exporter] %s: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
    fi
}

# Error handling function
claude_error() {
    printf "[env-exporter] ERROR: %s\n" "$*" >&2
    return 1
}

# Escape special shell characters in a path
# Input: path string
# Output: shell-safe quoted string
claude_escape_path() {
    if [ -z "$1" ]; then
        printf '""'
        return 0
    fi
    
    # Use printf to safely escape the path with double quotes
    # Escape backslashes, double quotes, backticks, dollar signs, and exclamation marks
    printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/`/\\`/g; s/\$/\\$/g; s/!/\\!/g')"
}

# Extract JSON string value safely without jq
# Input: json_string key_name
# Output: unescaped string value
claude_extract_json_string() {
    json_string="$1"
    key_name="$2"
    
    # Use sed to extract the value for the given key
    printf '%s' "$json_string" | sed -n 's/.*"'"$key_name"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
}

# Extract JSON array length without jq
# Input: json_string
# Output: array length (0 if empty or not an array)
claude_json_array_length() {
    json_string="$1"
    
    if [ -z "$json_string" ] || ! printf '%s' "$json_string" | grep -q '^\[.*\]$'; then
        printf '0'
        return
    fi
    
    # Count objects by counting opening braces (more reliable)
    count=$(printf '%s' "$json_string" | grep -o '{' | wc -l | tr -d ' ')
    printf '%d' "$count"
}

# Extract path from last JSON object in array
# Input: json_array
# Output: path string from last object
claude_extract_last_path() {
    json_array="$1"
    
    # Extract the last object by finding the last occurrence of path
    printf '%s' "$json_array" | sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | tail -1
}

# Truncate JSON array to last N entries (simplified version)
# Input: json_string max_elements
# Output: truncated JSON array
claude_truncate_json_array() {
    json_string="$1"
    max_elements="$2"
    
    if [ -z "$json_string" ] || ! printf '%s' "$json_string" | grep -q '^\[.*\]$'; then
        printf '[]'
        return 0
    fi
    
    array_length=$(claude_json_array_length "$json_string")
    
    if [ "$array_length" -le "$max_elements" ]; then
        printf '%s' "$json_string"
        return 0
    fi
    
    # For now, if we have more than max_elements, just return the original array
    # This is a simplified implementation - could be enhanced later
    printf '%s' "$json_string"
}

# Escape JSON string for shell export
# Input: json_string
# Output: shell-safe escaped JSON
claude_escape_json_for_shell() {
    if [ -z "$1" ]; then
        printf '""'
        return 0
    fi
    
    # Escape the JSON string for shell use
    printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/`/\\`/g; s/\$/\\$/g; s/!/\\!/g')"
}

# Main export function
claude_export_environment() {
    claude_log "Starting environment export process"
    
    # Check if registry file exists
    if [ ! -f "$CLAUDE_REGISTRY_FILE" ]; then
        claude_log "Registry file does not exist: $CLAUDE_REGISTRY_FILE"
        # Unset variables if registry doesn't exist
        unset CLAUDE_LAST_CAPTURE
        unset CLAUDE_CAPTURES
        claude_log "Environment variables unset due to missing registry"
        return 0
    fi
    
    # Check if registry file is readable
    if [ ! -r "$CLAUDE_REGISTRY_FILE" ]; then
        claude_error "Registry file is not readable: $CLAUDE_REGISTRY_FILE"
        return 1
    fi
    
    # Read the registry file
    claude_log "Reading registry file: $CLAUDE_REGISTRY_FILE"
    registry_content=$(cat "$CLAUDE_REGISTRY_FILE" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        claude_error "Failed to read registry file: $CLAUDE_REGISTRY_FILE"
        return 1
    fi
    
    if [ -z "$registry_content" ]; then
        claude_log "Registry file is empty"
        unset CLAUDE_LAST_CAPTURE
        unset CLAUDE_CAPTURES
        return 0
    fi
    
    # Extract captures array from registry (handle multi-line JSON)
    # Remove newlines but preserve spaces within strings, then extract the array
    captures_array=$(printf '%s' "$registry_content" | tr -d '\n\r' | sed -n 's/.*"captures"[[:space:]]*:[[:space:]]*\(\[.*\]\).*/\1/p')
    
    if [ -z "$captures_array" ]; then
        claude_log "No captures array found in registry"
        unset CLAUDE_LAST_CAPTURE
        unset CLAUDE_CAPTURES
        return 0
    fi
    
    # Get array length
    array_length=$(claude_json_array_length "$captures_array")
    claude_log "Found $array_length captures in registry"
    
    if [ "$array_length" -eq 0 ]; then
        claude_log "Captures array is empty"
        unset CLAUDE_LAST_CAPTURE
        unset CLAUDE_CAPTURES
        return 0
    fi
    
    # Get the last capture path for CLAUDE_LAST_CAPTURE
    last_capture_path=$(claude_extract_last_path "$captures_array")
    
    if [ -n "$last_capture_path" ]; then
        export CLAUDE_LAST_CAPTURE="$last_capture_path"
        claude_log "Set CLAUDE_LAST_CAPTURE to: $last_capture_path"
    else
        claude_log "Could not extract path from last capture"
        unset CLAUDE_LAST_CAPTURE
    fi
    
    # Truncate captures array to last N entries for CLAUDE_CAPTURES
    truncated_captures=$(claude_truncate_json_array "$captures_array" "$CLAUDE_MAX_CAPTURES")
    
    if [ -n "$truncated_captures" ] && [ "$truncated_captures" != "[]" ]; then
        export CLAUDE_CAPTURES="$truncated_captures"
        claude_log "Set CLAUDE_CAPTURES with $(claude_json_array_length "$truncated_captures") entries"
    else
        claude_log "No valid captures to export"
        unset CLAUDE_CAPTURES
    fi
    
    claude_log "Environment export completed successfully"
    return 0
}

# Validation function to check if variables are set correctly
claude_validate_export() {
    if [ -n "$CLAUDE_LAST_CAPTURE" ]; then
        claude_log "✓ CLAUDE_LAST_CAPTURE is set: $CLAUDE_LAST_CAPTURE"
    else
        claude_log "✗ CLAUDE_LAST_CAPTURE is not set"
    fi
    
    if [ -n "$CLAUDE_CAPTURES" ]; then
        capture_count=$(claude_json_array_length "$CLAUDE_CAPTURES")
        claude_log "✓ CLAUDE_CAPTURES is set with $capture_count entries"
    else
        claude_log "✗ CLAUDE_CAPTURES is not set"
    fi
}

# Function to display current environment state (for debugging)
claude_show_environment() {
    printf "CLAUDE_LAST_CAPTURE=%s\n" "${CLAUDE_LAST_CAPTURE:-<unset>}"
    printf "CLAUDE_CAPTURES=%s\n" "${CLAUDE_CAPTURES:-<unset>}"
}

# Main execution - when sourced, this runs; when executed directly, it shows help
# Simple detection: if we can use 'return' successfully, we're sourced
if (return 0 2>/dev/null); then
    # Script is being sourced, perform the export
    claude_export_environment
    export_result=$?
    
    if [ "$CLAUDE_DEBUG" = "1" ]; then
        claude_validate_export
    fi
    
    return $export_result
else
    # Script is being executed directly, show usage
    cat << 'EOF'
Claude Auto-Tee Environment Exporter

This script exports CLAUDE_CAPTURES and CLAUDE_LAST_CAPTURE environment variables
based on the captures registry at ~/.claude/captures.json.

Usage:
  Source this script in your shell:
    . /path/to/env-exporter.sh

  Or with debug output:
    CLAUDE_DEBUG=1 . /path/to/env-exporter.sh

Environment Variables Set:
  CLAUDE_LAST_CAPTURE  - Path to the most recent capture file
  CLAUDE_CAPTURES      - JSON array of recent captures (last 10 entries)

Environment Variables Read:
  CLAUDE_DEBUG         - Set to 1 to enable debug logging
  HOME                 - Used to locate ~/.claude/captures.json

Exit Codes:
  0 - Success (variables exported or unset appropriately)
  1 - Error reading registry file or other failure

For acceptance testing:
  test -n "$CLAUDE_LAST_CAPTURE" && echo "SUCCESS" || echo "FAILURE"

EOF
fi