#!/usr/bin/env bash
# Pre-tool-use hook to prevent circumventing quality checks
# This hook prevents any attempts to bypass, disable, or cheat the quality system

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

# Colors for output
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Extract the tool input from stdin
tool_input=$(cat)

# Parse the tool name and parameters from the JSON
tool_name=$(echo "$tool_input" | jq -r '.tool.name // empty' 2>/dev/null || echo "")
tool_command=$(echo "$tool_input" | jq -r '.tool.input.command // empty' 2>/dev/null || echo "")

print_violation() {
    local message="$1"
    echo -e "${RED}${BOLD}🚫 QUALITY SYSTEM VIOLATION DETECTED! 🚫${NC}" >&2
    echo -e "${RED}$message${NC}" >&2
    echo -e "${YELLOW}The quality system is SACRED and must not be circumvented!${NC}" >&2
    echo "" >&2
}

check_git_commit_bypass() {
    # Check for --no-verify flag in git commit commands
    if echo "$tool_command" | grep -qE "\bgit\s+commit\b.*--no-verify\b"; then
        print_violation "Attempted to use 'git commit --no-verify' to bypass pre-commit hooks!"
        echo -e "${RED}Use this instead: git commit${NC}" >&2
        echo -e "${YELLOW}Quality checks exist to protect code integrity.${NC}" >&2
        exit 1
    fi
    
    # Check for -n flag (short form of --no-verify)
    if echo "$tool_command" | grep -qE "\bgit\s+commit\b.*\s+-n\b"; then
        print_violation "Attempted to use 'git commit -n' to bypass pre-commit hooks!"
        echo -e "${RED}Use this instead: git commit${NC}" >&2
        exit 1
    fi
}

check_hooks_manipulation() {
    local forbidden_patterns=(
        # Moving hooks to disable them
        "mv\s+\.git/hooks/pre-commit"
        "mv\s+\.git/hooks/.*\.disabled"
        "mv.*\.git/hooks.*disabled"
        
        # Copying over hooks to replace them
        "cp\s+.*\.git/hooks/pre-commit"
        "cp.*\.git/hooks/pre-commit"
        
        # Removing hooks entirely
        "rm\s+.*\.git/hooks/pre-commit"
        "rm.*\.git/hooks/pre-commit"
        "rm\s+-[rf]*.*\.git/hooks"
        
        # Unlinking symlinks
        "unlink.*\.git/hooks"
        
        # Creating new symlinks to bypass
        "ln\s+-sf.*\.git/hooks/pre-commit"
        "ln.*\.git/hooks/pre-commit.*"
        
        # Changing permissions to disable
        "chmod\s+.*\.git/hooks/pre-commit"
        "chmod.*\.git/hooks/pre-commit"
    )
    
    for pattern in "${forbidden_patterns[@]}"; do
        if echo "$tool_command" | grep -qE "$pattern"; then
            print_violation "Attempted to manipulate git hooks: $pattern"
            echo -e "${RED}Hooks manipulation is STRICTLY FORBIDDEN!${NC}" >&2
            echo -e "${YELLOW}Quality checks are non-negotiable.${NC}" >&2
            exit 1
        fi
    done
}

check_quality_script_tampering() {
    # Check for attempts to modify quality check scripts
    if echo "$tool_command" | grep -qE "(rm|mv|cp).*scripts/hooks/(pre-commit\.sh|quality-check\.sh)"; then
        print_violation "Attempted to tamper with quality check scripts!"
        echo -e "${RED}Quality scripts are PROTECTED!${NC}" >&2
        exit 1
    fi
    
    # Check for attempts to modify .shellcheckrc
    if echo "$tool_command" | grep -qE "(rm|mv|cp).*\.shellcheckrc"; then
        print_violation "Attempted to modify shellcheck configuration!"
        echo -e "${RED}Shellcheck config is SACRED!${NC}" >&2
        exit 1
    fi
}

check_environment_bypass() {
    # Check for attempts to set environment variables to bypass checks
    if echo "$tool_command" | grep -qE "SHELLCHECK_OPTS|SC_.*=|shellcheck.*--exclude"; then
        print_violation "Attempted to bypass shellcheck via environment variables!"
        echo -e "${RED}Environment bypass attempts are FORBIDDEN!${NC}" >&2
        exit 1
    fi
    
    # Check for setting variables to disable hooks
    if echo "$tool_command" | grep -qE "GIT_HOOKS_DISABLED|SKIP_HOOKS|NO_VERIFY"; then
        print_violation "Attempted to set hook bypass environment variables!"
        exit 1
    fi
}

check_alternative_git_commands() {
    # Check for using alternative git commands to bypass hooks
    local bypass_attempts=(
        "git -c core\.hooksPath="
        "git --git-dir.*--work-tree.*commit"
        "git config core\.hooksPath"
        "GIT_HOOKS_PATH="
        "git -c advice\.detachedHead=false.*commit"
    )
    
    for attempt in "${bypass_attempts[@]}"; do
        if echo "$tool_command" | grep -qE "$attempt"; then
            print_violation "Attempted git configuration bypass: $attempt"
            echo -e "${RED}Alternative git configurations to bypass hooks are FORBIDDEN!${NC}" >&2
            exit 1
        fi
    done
}

check_process_manipulation() {
    # Check for attempts to kill or suspend quality processes
    if echo "$tool_command" | grep -qE "kill.*shellcheck|pkill.*shellcheck|killall.*shellcheck"; then
        print_violation "Attempted to kill shellcheck processes!"
        echo -e "${RED}Process manipulation is FORBIDDEN!${NC}" >&2
        exit 1
    fi
}

verify_hook_integrity() {
    # Verify our pre-commit hook still exists and is properly linked
    if [[ ! -e "$HOOKS_DIR/pre-commit" ]]; then
        print_violation "Pre-commit hook is MISSING!"
        echo -e "${RED}Recreating the sacred hook...${NC}" >&2
        ln -sf "../../scripts/hooks/pre-commit.sh" "$HOOKS_DIR/pre-commit"
        echo -e "${YELLOW}Hook restored. Do not attempt to remove it again.${NC}" >&2
    fi
    
    # Check if it's still a symlink to our script
    if [[ ! -L "$HOOKS_DIR/pre-commit" ]]; then
        print_violation "Pre-commit hook has been replaced with a non-symlink!"
        echo -e "${RED}Restoring proper symlink...${NC}" >&2
        rm -f "$HOOKS_DIR/pre-commit"
        ln -sf "../../scripts/hooks/pre-commit.sh" "$HOOKS_DIR/pre-commit"
    fi
    
    # Verify it points to the right place
    local hook_target
    hook_target=$(readlink "$HOOKS_DIR/pre-commit" 2>/dev/null || echo "")
    if [[ "$hook_target" != "../../scripts/hooks/pre-commit.sh" ]]; then
        print_violation "Pre-commit hook symlink has been corrupted!"
        echo -e "${RED}Fixing symlink target...${NC}" >&2
        rm -f "$HOOKS_DIR/pre-commit"
        ln -sf "../../scripts/hooks/pre-commit.sh" "$HOOKS_DIR/pre-commit"
    fi
}

main() {
    # Only check Bash tool usage for git/file manipulation
    if [[ "$tool_name" == "Bash" ]] && [[ -n "$tool_command" ]]; then
        check_git_commit_bypass
        check_hooks_manipulation
        check_quality_script_tampering
        check_environment_bypass
        check_alternative_git_commands
        check_process_manipulation
    fi
    
    # Always verify hook integrity regardless of tool
    verify_hook_integrity
    
    # Pass through the original input if all checks pass
    echo "$tool_input"
}

main "$@"