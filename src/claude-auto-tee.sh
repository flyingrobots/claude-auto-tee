#!/usr/bin/env bash
# Claude Auto-Tee Hook - Minimal Implementation
# Automatically injects tee for pipe commands to save full output

# Read Claude Code hook input
input=$(cat)

# Extract command from JSON (handle escaped quotes)
command_escaped=$(echo "$input" | sed -n 's/.*"command":"\([^"]*\(\\"[^"]*\)*\)".*/\1/p' | tr -d '\n')
command=$(echo "$command_escaped" | sed 's/\\"/"/g')

# Check if command contains pipe and doesn't already have tee
if echo "$command" | grep -c " | " > /dev/null && [ $(echo "$command" | grep -c " | ") -gt 0 ]; then
    if echo "$command" | grep -q "tee "; then
        # Skip - already has tee
        echo "$input"
        exit 0
    fi
    # Process - has pipe but no tee
    # Generate unique temp file
    temp_file="/tmp/claude-$(date +%s%N | cut -b1-13).log"
    
    # Find first pipe and split command
    before_pipe="${command%% | *}"
    after_pipe="${command#* | }"
    
    # Construct modified command with tee
    # Only add 2>&1 if not already present
    if echo "$before_pipe" | grep -q "2>&1"; then
        modified_command="$before_pipe | tee \"$temp_file\" | $after_pipe"
    else
        modified_command="$before_pipe 2>&1 | tee \"$temp_file\" | $after_pipe"
    fi
    
    # Build new JSON - simpler approach using printf with proper escaping
    # Escape the command properly for JSON
    modified_with_echo="$modified_command ; echo \"Full output saved to: $temp_file\""
    # Escape quotes and backslashes for JSON
    escaped_command=$(printf '%s' "$modified_with_echo" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    
    # Use a more robust approach to reconstruct JSON
    # First extract the timeout value
    timeout_value=$(echo "$input" | sed -n 's/.*"timeout":\([^,}]*\).*/\1/p')
    if [ -z "$timeout_value" ]; then
        timeout_value="null"
    fi
    
    # Output properly formatted JSON
    printf '{"tool":{"name":"Bash","input":{"command":"%s"}},"timeout":%s}\n' \
        "$escaped_command" "$timeout_value"
    
else
    # Pass through unchanged
    echo "$input"
fi