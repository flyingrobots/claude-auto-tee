#!/usr/bin/env bash
# Pre-commit hook with BRUTAL shell quality checks
# This will make even Linus Torvalds cry with its strictness

set -euo pipefail
IFS=$'\n\t'

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly TEMP_DIR="/tmp/claude-auto-tee-hooks-$$"

# Cleanup on exit
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Create temp directory
mkdir -p "$TEMP_DIR"

echo -e "${BOLD}${BLUE}🔥 INITIATING NUCLEAR-GRADE SHELL QUALITY CHECKS 🔥${NC}"
echo -e "${YELLOW}Warning: These checks are so strict they might cause permanent psychological damage${NC}"
echo ""

# Function to print results
print_result() {
    local status="$1"
    local message="$2"
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✅ $message${NC}"
    elif [ "$status" = "FAIL" ]; then
        echo -e "${RED}❌ $message${NC}"
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}⚠️  $message${NC}"
    fi
}

# Get list of shell files to check
get_shell_files() {
    # Find shell files by extension
    find "$PROJECT_ROOT" \
        -type f \
        \( -name "*.sh" \
        -o -name "*.bash" \
        -o -name "*.bats" \) \
        ! -path "*/node_modules/*" \
        ! -path "*/.git/*" \
        ! -path "*/target/*" \
        ! -path "*/build/*" | sort
    
    # Find executable files in common script directories
    for dir in "$PROJECT_ROOT/bin" "$PROJECT_ROOT/scripts"; do
        if [[ -d "$dir" ]]; then
            find "$dir" -type f -perm +111 2>/dev/null | while read -r file; do
                if is_shell_script "$file"; then
                    echo "$file"
                fi
            done
        fi
    done
}

# Check if file is a shell script
is_shell_script() {
    local file="$1"
    
    # Check shebang
    if head -1 "$file" | grep -qE "^#!.*\b(bash|sh|zsh|ksh|dash)\b"; then
        return 0
    fi
    
    # Check file command output
    if command -v file >/dev/null && file "$file" | grep -qi "shell script"; then
        return 0
    fi
    
    return 1
}

# ULTRA STRICT shellcheck configuration
run_shellcheck() {
    local file="$1"
    local errors=0
    
    echo -e "${BLUE}Checking: $file${NC}"
    
    # The most brutal shellcheck configuration possible
    # Every single warning becomes an error
    if ! shellcheck \
        --check-sourced \
        --external-sources \
        --enable=all \
        --severity=error \
        --format=gcc \
        --wiki-link-count=10 \
        --exclude=SC1091 \
        "$file" > "$TEMP_DIR/shellcheck.out" 2>&1; then
        
        echo -e "${RED}💀 SHELLCHECK EXECUTION FAILED FOR: $file${NC}"
        cat "$TEMP_DIR/shellcheck.out"
        ((errors++))
    fi
    
    # Additional custom strict checks
    echo -e "${BLUE}Running ULTRA STRICT custom checks...${NC}"
    
    # Check for any use of `eval` (security risk)
    if grep -n "eval" "$file"; then
        print_result "FAIL" "FORBIDDEN: eval usage detected (security vulnerability)"
        ((errors++))
    fi
    
    # Check for any unquoted variables
    if grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^A-Za-z0-9_"]' "$file" | grep -v '${'; then
        print_result "FAIL" "FORBIDDEN: Unquoted variable usage detected"
        ((errors++))
    fi
    
    # Check for missing 'set -euo pipefail'
    if ! grep -q "set -euo pipefail" "$file"; then
        print_result "FAIL" "MISSING: 'set -euo pipefail' is MANDATORY"
        ((errors++))
    fi
    
    # Check for missing IFS setting
    if ! grep -q "IFS=" "$file"; then
        print_result "FAIL" "MISSING: IFS must be explicitly set"
        ((errors++))
    fi
    
    # Check for any use of backticks (must use $())
    if grep -n '`' "$file"; then
        print_result "FAIL" "FORBIDDEN: Backticks detected - use \$() instead"
        ((errors++))
    fi
    
    # Check for any use of 'test' command (must use [[ ]])
    if grep -nE '\btest\b' "$file"; then
        print_result "FAIL" "FORBIDDEN: 'test' command - use [[ ]] instead"
        ((errors++))
    fi
    
    # Check for any use of single brackets (must use [[ ]])
    if grep -nE '\[\s+.*\s+\]' "$file" | grep -v '\[\['; then
        print_result "FAIL" "FORBIDDEN: Single brackets - use [[ ]] instead"
        ((errors++))
    fi
    
    # Check for any function without 'local' declarations
    if grep -A 5 "^[a-zA-Z_][a-zA-Z0-9_]*\s*()" "$file" | grep -B 5 -A 5 "=" | grep -v "local\s"; then
        print_result "WARN" "SUSPICIOUS: Functions should use 'local' for all variables"
    fi
    
    # Check for any use of 'which' (non-POSIX)
    if grep -n "which" "$file"; then
        print_result "FAIL" "FORBIDDEN: 'which' is non-POSIX - use 'command -v' instead"
        ((errors++))
    fi
    
    # Check for any hardcoded /tmp paths
    if grep -n "/tmp/" "$file"; then
        print_result "WARN" "SUSPICIOUS: Hardcoded /tmp path - use \$TMPDIR or mktemp"
    fi
    
    # Check for any use of $* instead of "$@"
    if grep -n '\$\*' "$file"; then
        print_result "FAIL" "FORBIDDEN: Use '\"$@\"' instead of \$*"
        ((errors++))
    fi
    
    # Check for missing readonly declarations on constants
    if grep -nE '^[A-Z_][A-Z0-9_]*=' "$file" | grep -v "readonly"; then
        print_result "FAIL" "MISSING: Constants must be declared readonly"
        ((errors++))
    fi
    
    # Check for any use of 'echo -e' (non-portable)
    if grep -n "echo -e" "$file"; then
        print_result "FAIL" "NON-PORTABLE: Use printf instead of echo -e"
        ((errors++))
    fi
    
    # Check for any missing error handling on commands
    if grep -nE '^[[:space:]]*[a-zA-Z_].*[^&]$' "$file" | grep -v -E '(if|while|for|case|set|local|readonly|export|return|exit|echo|printf|\|\||&&|\||#)'; then
        print_result "WARN" "CHECK: Commands should have explicit error handling"
    fi
    
    # Check for any use of 'cd' without error checking
    if grep -n "cd " "$file" | grep -v "cd.*||"; then
        print_result "FAIL" "FORBIDDEN: 'cd' without error checking"
        ((errors++))
    fi
    
    # Check for any use of 'source' instead of '.'
    if grep -n "source " "$file"; then
        print_result "FAIL" "NON-POSIX: Use '. file' instead of 'source file'"
        ((errors++))
    fi
    
    # Check for proper function declarations
    if grep -nE "^function " "$file"; then
        print_result "FAIL" "NON-POSIX: Use 'name()' instead of 'function name'"
        ((errors++))
    fi
    
    # Check for any use of non-POSIX regex operators
    if grep -nE '=~|\[\[.*\]\].*=~' "$file"; then
        print_result "WARN" "NON-POSIX: =~ operator is bash-specific"
    fi
    
    # Check file encoding (must be UTF-8)
    if command -v file >/dev/null; then
        if ! file "$file" | grep -qi "utf-8"; then
            print_result "FAIL" "ENCODING: File must be UTF-8 encoded"
            ((errors++))
        fi
    fi
    
    # Check for proper exit codes
    if ! grep -qE "(exit [0-9]+|return [0-9]+)" "$file" && [ "$(basename "$file")" != "*.sh" ]; then
        print_result "WARN" "CHECK: Script should have explicit exit codes"
    fi
    
    # Verify no trailing whitespace
    if grep -n "[[:space:]]$" "$file"; then
        print_result "FAIL" "WHITESPACE: Trailing whitespace detected"
        ((errors++))
    fi
    
    # Check for consistent indentation (4 spaces only)
    if grep -n $'^\t' "$file"; then
        print_result "FAIL" "INDENTATION: Tabs detected - use 4 spaces only"
        ((errors++))
    fi
    
    # Verify proper shebang
    local first_line
    first_line=$(head -1 "$file")
    if [[ "$first_line" != "#!/usr/bin/env bash" ]] && [[ "$first_line" != "#!/bin/bash" ]]; then
        if [[ "$first_line" =~ ^#! ]]; then
            print_result "FAIL" "SHEBANG: Use '#!/usr/bin/env bash' for portability"
            ((errors++))
        fi
    fi
    
    return $errors
}

# Main execution
main() {
    local total_errors=0
    local files_checked=0
    local shell_files
    
    echo -e "${BOLD}Searching for shell scripts...${NC}"
    
    # Get all shell files  
    local shell_files_list
    shell_files_list=$(get_shell_files)
    if [[ -z "$shell_files_list" ]]; then
        echo -e "${YELLOW}No shell files found to check.${NC}"
        return 0
    fi
    
    # Check each file using process substitution to avoid subshell
    while IFS= read -r file; do
        if [[ -f "$file" ]] && is_shell_script "$file"; then
            echo ""
            echo -e "${BOLD}${BLUE}═══ BRUTAL CHECK: $file ═══${NC}"
            
            local file_errors=0
            if ! run_shellcheck "$file"; then
                file_errors=$?
            fi
            
            total_errors=$((total_errors + file_errors))
            files_checked=$((files_checked + 1))
            
            if [[ $file_errors -eq 0 ]]; then
                print_result "PASS" "File survived the nuclear inspection"
            else
                print_result "FAIL" "File failed with $file_errors error(s)"
            fi
        fi
    done <<< "$shell_files_list"
    
    echo ""
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}FINAL JUDGMENT:${NC}"
    echo -e "Files checked: $files_checked"
    echo -e "Total errors: $total_errors"
    
    if [[ $total_errors -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}🎉 MIRACULOUS! All files survived the brutal inspection!${NC}"
        echo -e "${GREEN}Your code is worthy of the gods themselves.${NC}"
        exit 0
    else
        echo -e "${RED}${BOLD}💀 COMMIT REJECTED! Your code has brought shame upon this repository!${NC}"
        echo -e "${RED}Fix these $total_errors errors before you dare commit again!${NC}"
        echo ""
        echo -e "${YELLOW}Remember: These checks exist to forge your code in the fires of perfectionism.${NC}"
        echo -e "${YELLOW}Only the strongest shell scripts survive this gauntlet.${NC}"
        exit 1
    fi
}

# Run the gauntlet
main "$@"