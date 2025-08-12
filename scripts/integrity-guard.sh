#!/usr/bin/env bash
# Quality System Integrity Guard
# Self-healing script that ensures quality checks cannot be bypassed

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

print_status() {
    local status="$1"
    local message="$2"
    case "$status" in
        "OK") echo -e "${GREEN}✅ $message${NC}" ;;
        "WARN") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "ERROR") echo -e "${RED}❌ $message${NC}" ;;
        "FIX") echo -e "${YELLOW}🔧 $message${NC}" ;;
    esac
}

check_and_fix_hooks() {
    local fixed=0
    
    # Check pre-commit hook
    if [[ ! -e "$HOOKS_DIR/pre-commit" ]]; then
        print_status "ERROR" "Pre-commit hook missing"
        print_status "FIX" "Restoring pre-commit hook..."
        ln -sf "../../scripts/hooks/pre-commit.sh" "$HOOKS_DIR/pre-commit"
        ((fixed++))
    elif [[ ! -L "$HOOKS_DIR/pre-commit" ]]; then
        print_status "ERROR" "Pre-commit hook is not a symlink"
        print_status "FIX" "Converting to proper symlink..."
        rm -f "$HOOKS_DIR/pre-commit"
        ln -sf "../../scripts/hooks/pre-commit.sh" "$HOOKS_DIR/pre-commit"
        ((fixed++))
    else
        local target
        target=$(readlink "$HOOKS_DIR/pre-commit")
        if [[ "$target" != "../../scripts/hooks/pre-commit.sh" ]]; then
            print_status "ERROR" "Pre-commit hook points to wrong target: $target"
            print_status "FIX" "Fixing symlink target..."
            rm -f "$HOOKS_DIR/pre-commit"
            ln -sf "../../scripts/hooks/pre-commit.sh" "$HOOKS_DIR/pre-commit"
            ((fixed++))
        else
            print_status "OK" "Pre-commit hook is properly linked"
        fi
    fi
    
    # Check commit-msg hook
    if [[ ! -e "$HOOKS_DIR/commit-msg" ]]; then
        print_status "ERROR" "Commit-msg hook missing"
        print_status "FIX" "Restoring commit-msg hook..."
        ln -sf "../../scripts/hooks/commit-msg.sh" "$HOOKS_DIR/commit-msg"
        ((fixed++))
    elif [[ ! -L "$HOOKS_DIR/commit-msg" ]]; then
        print_status "ERROR" "Commit-msg hook is not a symlink"
        print_status "FIX" "Converting to proper symlink..."
        rm -f "$HOOKS_DIR/commit-msg"
        ln -sf "../../scripts/hooks/commit-msg.sh" "$HOOKS_DIR/commit-msg"
        ((fixed++))
    else
        print_status "OK" "Commit-msg hook is properly linked"
    fi
    
    return $fixed
}

check_script_permissions() {
    local fixed=0
    local scripts=(
        "scripts/hooks/pre-commit.sh"
        "scripts/hooks/commit-msg.sh" 
        "scripts/hooks/pre-tool-use.sh"
        "scripts/quality-check.sh"
    )
    
    for script in "${scripts[@]}"; do
        local full_path="$PROJECT_ROOT/$script"
        if [[ -f "$full_path" ]]; then
            if [[ ! -x "$full_path" ]]; then
                print_status "ERROR" "$script is not executable"
                print_status "FIX" "Making $script executable..."
                chmod +x "$full_path"
                ((fixed++))
            else
                print_status "OK" "$script is executable"
            fi
        else
            print_status "ERROR" "$script is missing"
        fi
    done
    
    return $fixed
}

check_config_files() {
    local fixed=0
    
    # Check .shellcheckrc
    if [[ ! -f "$PROJECT_ROOT/.shellcheckrc" ]]; then
        print_status "ERROR" ".shellcheckrc is missing"
        print_status "FIX" "Recreating shellcheck configuration..."
        cat > "$PROJECT_ROOT/.shellcheckrc" << 'EOF'
# ULTRA STRICT shellcheck configuration
enable=all
severity=error
check-sourced=true
external-sources=true
wiki-link-count=10
disable=SC1091
format=gcc
shell=bash
EOF
        ((fixed++))
    else
        print_status "OK" ".shellcheckrc exists"
    fi
    
    # Check Claude settings
    if [[ ! -f "$PROJECT_ROOT/.claude/settings.json" ]]; then
        print_status "ERROR" "Claude settings missing"
        print_status "FIX" "Recreating Claude settings..."
        mkdir -p "$PROJECT_ROOT/.claude"
        cat > "$PROJECT_ROOT/.claude/settings.json" << 'EOF'
{
  "hooks": {
    "preToolUse": [
      {
        "command": "./scripts/hooks/pre-tool-use.sh",
        "matchers": ["Bash", "Edit", "Write", "MultiEdit"]
      }
    ]
  }
}
EOF
        ((fixed++))
    else
        print_status "OK" "Claude settings exist"
    fi
    
    return $fixed
}

detect_bypass_attempts() {
    # Check for suspicious files that might indicate bypass attempts
    local suspicious_files=(
        ".git/hooks/pre-commit.disabled"
        ".git/hooks/pre-commit.bak"
        ".git/hooks/pre-commit.old"
        "scripts/hooks/pre-commit.sh.disabled"
        "scripts/hooks/pre-commit.sh.bak"
    )
    
    for file in "${suspicious_files[@]}"; do
        if [[ -e "$PROJECT_ROOT/$file" ]]; then
            print_status "WARN" "Suspicious bypass file detected: $file"
        fi
    done
    
    # Check git config for bypass settings
    if git config --get core.hooksPath >/dev/null 2>&1; then
        local hooks_path
        hooks_path=$(git config --get core.hooksPath)
        if [[ "$hooks_path" != ".git/hooks" ]]; then
            print_status "WARN" "Git hooks path has been redirected to: $hooks_path"
        fi
    fi
}

main() {
    echo -e "${BOLD}🔒 Quality System Integrity Check${NC}"
    echo "======================================"
    
    local total_fixes=0
    
    # Run all checks
    check_and_fix_hooks && ((total_fixes += $?))
    check_script_permissions && ((total_fixes += $?))
    check_config_files && ((total_fixes += $?))
    detect_bypass_attempts
    
    echo ""
    if [[ $total_fixes -eq 0 ]]; then
        print_status "OK" "Quality system integrity verified - all protections active"
    else
        print_status "FIX" "Applied $total_fixes fixes to maintain quality system integrity"
        echo -e "${YELLOW}The quality system is now secure and bypass-resistant.${NC}"
    fi
    
    return 0
}

main "$@"