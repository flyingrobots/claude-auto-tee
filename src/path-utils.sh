#!/usr/bin/env bash
# Path Utilities for claude-auto-tee
# P1.T007 - Validate path handling (forward/backward slashes)

# Normalize path separators across platforms
normalize_path() {
    local input_path="$1"
    local normalized_path
    
    if [[ -z "$input_path" ]]; then
        echo ""
        return 0
    fi
    
    # Handle different path formats
    case "$(uname -s)" in
        "CYGWIN"* | "MINGW"* | "MSYS"*)
            # Windows-like environments - convert forward slashes to backslashes
            normalized_path=$(echo "$input_path" | sed 's|/|\\|g')
            ;;
        *)
            # Unix-like environments - convert backslashes to forward slashes
            normalized_path=$(echo "$input_path" | sed 's|\\|/|g')
            ;;
    esac
    
    # Remove duplicate separators
    case "$(uname -s)" in
        "CYGWIN"* | "MINGW"* | "MSYS"*)
            normalized_path=$(echo "$normalized_path" | sed 's|\\\\\\*|\\|g')
            ;;
        *)
            normalized_path=$(echo "$normalized_path" | sed 's|//*|/|g')
            ;;
    esac
    
    # Remove trailing separator (except for root)
    case "$(uname -s)" in
        "CYGWIN"* | "MINGW"* | "MSYS"*)
            if [[ "$normalized_path" != "\\" ]] && [[ "$normalized_path" != ?:\\ ]]; then
                normalized_path="${normalized_path%\\}"
            fi
            ;;
        *)
            if [[ "$normalized_path" != "/" ]]; then
                normalized_path="${normalized_path%/}"
            fi
            ;;
    esac
    
    echo "$normalized_path"
}

# Join path components with appropriate separators
join_path() {
    local separator="/"
    local result=""
    local component
    
    # Determine platform-appropriate separator
    case "$(uname -s)" in
        "CYGWIN"* | "MINGW"* | "MSYS"*)
            separator="\\"
            ;;
    esac
    
    # Process each argument as a path component
    for component in "$@"; do
        if [[ -z "$component" ]]; then
            continue
        fi
        
        # Normalize component
        component=$(normalize_path "$component")
        
        if [[ -z "$result" ]]; then
            result="$component"
        else
            # Remove leading separator from component if present
            case "$(uname -s)" in
                "CYGWIN"* | "MINGW"* | "MSYS"*)
                    component="${component#\\}"
                    result="${result}\\${component}"
                    ;;
                *)
                    component="${component#/}"
                    result="${result}/${component}"
                    ;;
            esac
        fi
    done
    
    echo "$result"
}

# Check if path is absolute
is_absolute_path() {
    local path="$1"
    
    case "$(uname -s)" in
        "CYGWIN"* | "MINGW"* | "MSYS"*)
            # Windows: Check for drive letter or UNC path
            if [[ "$path" =~ ^[A-Za-z]:[\\/] ]] || [[ "$path" =~ ^[\\/][\\/] ]]; then
                return 0
            fi
            ;;
        *)
            # Unix: Check for leading slash
            if [[ "$path" =~ ^/ ]]; then
                return 0
            fi
            ;;
    esac
    
    return 1
}

# Resolve relative path to absolute path
resolve_absolute_path() {
    local input_path="$1"
    local base_dir="${2:-$(pwd)}"
    
    # If already absolute, just normalize
    if is_absolute_path "$input_path"; then
        normalize_path "$input_path"
        return 0
    fi
    
    # Join with base directory and normalize
    local full_path
    full_path=$(join_path "$base_dir" "$input_path")
    normalize_path "$full_path"
}

# Validate path components for security
validate_path_security() {
    local path="$1"
    
    # Check for dangerous patterns
    if [[ "$path" =~ \.\./|\.\.\\ ]]; then
        echo "Path contains parent directory traversal: $path" >&2
        return 1
    fi
    
    # Check for null bytes
    if [[ "$path" == *$'\0'* ]]; then
        echo "Path contains null bytes: $path" >&2
        return 1
    fi
    
    # Check for extremely long paths
    if [[ ${#path} -gt 4096 ]]; then
        echo "Path exceeds maximum length (4096): ${#path}" >&2
        return 1
    fi
    
    return 0
}

# Create a safe temp file path
create_safe_temp_path() {
    local temp_dir="$1"
    local prefix="${2:-claude-auto-tee}"
    local suffix="${3:-.log}"
    
    # Normalize temp directory
    temp_dir=$(normalize_path "$temp_dir")
    
    # Validate temp directory path
    if ! validate_path_security "$temp_dir"; then
        return 1
    fi
    
    # Generate unique filename component
    local timestamp
    timestamp=$(date +%s%N | cut -b1-13)
    local random_component="$RANDOM"
    local filename="${prefix}-${timestamp}-${random_component}${suffix}"
    
    # Join and return the complete path
    join_path "$temp_dir" "$filename"
}

# Handle UNC paths on Windows
handle_unc_path() {
    local path="$1"
    
    case "$(uname -s)" in
        "CYGWIN"* | "MINGW"* | "MSYS"*)
            # UNC path format: \\server\share\path
            if [[ "$path" =~ ^[\\/][\\/] ]]; then
                # Normalize UNC path
                local unc_path
                unc_path=$(echo "$path" | sed 's|/|\\|g' | sed 's|\\\\\\*|\\\\|g')
                
                # Ensure it starts with exactly two backslashes
                unc_path="\\\\${unc_path#\\\\}"
                
                echo "$unc_path"
                return 0
            fi
            ;;
    esac
    
    # Not a UNC path, return normalized path
    normalize_path "$path"
}

# Convert between Unix and Windows path formats (for WSL)
convert_wsl_path() {
    local path="$1"
    local to_format="${2:-unix}"  # "unix" or "windows"
    
    # Only relevant in WSL environment
    if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
        if command -v wslpath >/dev/null 2>&1; then
            case "$to_format" in
                "windows")
                    wslpath -w "$path" 2>/dev/null || echo "$path"
                    ;;
                "unix"|*)
                    wslpath -u "$path" 2>/dev/null || echo "$path"
                    ;;
            esac
            return 0
        fi
    fi
    
    # Fallback to basic conversion
    case "$to_format" in
        "windows")
            echo "$path" | sed 's|^/mnt/\([a-z]\)/|\U\1:/|' | sed 's|/|\\|g'
            ;;
        "unix"|*)
            echo "$path" | sed 's|^\([A-Z]\):|/mnt/\L\1|' | sed 's|\\|/|g'
            ;;
    esac
}

# Test path handling functions
test_path_functions() {
    echo "=== Path Utilities Test Suite ==="
    echo "Platform: $(uname -s)"
    echo ""
    
    # Test normalize_path
    echo "Testing normalize_path:"
    echo "  Input: '/tmp//test\\path/'"
    echo "  Output: '$(normalize_path '/tmp//test\path/')'"
    echo ""
    
    # Test join_path
    echo "Testing join_path:"
    echo "  Input: '/tmp' 'test' 'path'"
    echo "  Output: '$(join_path '/tmp' 'test' 'path')'"
    echo ""
    
    # Test is_absolute_path
    echo "Testing is_absolute_path:"
    for test_path in "/tmp/test" "relative/path" "C:\\Windows" "\\\\server\\share"; do
        if is_absolute_path "$test_path"; then
            echo "  '$test_path': ABSOLUTE"
        else
            echo "  '$test_path': RELATIVE"
        fi
    done
    echo ""
    
    # Test resolve_absolute_path
    echo "Testing resolve_absolute_path:"
    echo "  Input: 'relative/path' from '/tmp'"
    echo "  Output: '$(resolve_absolute_path 'relative/path' '/tmp')'"
    echo ""
    
    # Test create_safe_temp_path
    echo "Testing create_safe_temp_path:"
    echo "  Input: '/tmp'"
    echo "  Output: '$(create_safe_temp_path '/tmp')'"
    echo ""
    
    # Test UNC handling (Windows)
    if [[ "$(uname -s)" =~ ^(CYGWIN|MINGW|MSYS) ]]; then
        echo "Testing handle_unc_path (Windows):"
        echo "  Input: '//server/share/path'"
        echo "  Output: '$(handle_unc_path '//server/share/path')'"
        echo ""
    fi
    
    # Test WSL path conversion
    if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
        echo "Testing convert_wsl_path (WSL):"
        echo "  Unix to Windows: '/mnt/c/temp' -> '$(convert_wsl_path '/mnt/c/temp' 'windows')'"
        echo "  Windows to Unix: 'C:\\temp' -> '$(convert_wsl_path 'C:\temp' 'unix')'"
        echo ""
    fi
    
    echo "=== Path Utilities Test Complete ==="
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_path_functions
fi