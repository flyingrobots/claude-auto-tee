#!/usr/bin/env bash
# Manual quality check script - runs the same brutal checks as pre-commit hook
# Usage: ./scripts/quality-check.sh [--fix] [file1] [file2] ...

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

show_help() {
    cat << EOF
${BOLD}NUCLEAR QUALITY CHECKER${NC}

Usage: $0 [OPTIONS] [FILES...]

OPTIONS:
    --fix       Attempt to auto-fix some issues (dangerous!)
    --help      Show this help message
    --version   Show version information

FILES:
    Specific files to check. If none provided, checks all shell files.

EXAMPLES:
    $0                              # Check all shell files
    $0 src/hook.sh                  # Check specific file  
    $0 --fix src/*.sh               # Check and auto-fix files

${YELLOW}WARNING: This tool implements quality checks so strict that even
battle-hardened Unix greybeards have been seen weeping after using it.${NC}
EOF
}

main() {
    local fix_mode=false
    local files_to_check=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --fix)
                fix_mode=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --version)
                echo "Nuclear Quality Checker v1.0 - Maximum Brutality Edition"
                exit 0
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                show_help >&2
                exit 1
                ;;
            *)
                files_to_check+=("$1")
                shift
                ;;
        esac
    done
    
    echo -e "${BOLD}${BLUE}🔥 INITIATING MANUAL QUALITY INSPECTION 🔥${NC}"
    
    if [[ $fix_mode == true ]]; then
        echo -e "${YELLOW}${BOLD}⚠️  FIX MODE ENABLED - PROCEED WITH EXTREME CAUTION ⚠️${NC}"
    fi
    
    # Run the brutal pre-commit hook
    if [[ ${#files_to_check[@]} -eq 0 ]]; then
        # Check all files
        exec "$SCRIPT_DIR/hooks/pre-commit.sh"
    else
        # TODO: Could modify pre-commit script to accept file list
        echo -e "${YELLOW}Note: File-specific checking not yet implemented.${NC}"
        echo -e "${YELLOW}Running full repository check instead...${NC}"
        exec "$SCRIPT_DIR/hooks/pre-commit.sh"
    fi
}

main "$@"