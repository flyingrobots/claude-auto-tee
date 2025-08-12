#!/usr/bin/env bash
# Commit message hook that prevents bypass commits and enforces quality
# This runs after pre-commit but before the commit is finalized

set -euo pipefail
IFS=$'\n\t'

readonly COMMIT_MSG_FILE="$1"
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Read the commit message
commit_msg=$(cat "$COMMIT_MSG_FILE")

# Check for bypass-related commit messages
if echo "$commit_msg" | grep -qiE "(bypass|skip|disable|ignore).*(hook|quality|check|shellcheck)"; then
    echo -e "${RED}${BOLD}🚫 BYPASS COMMIT DETECTED! 🚫${NC}" >&2
    echo -e "${RED}Commit message indicates attempt to bypass quality system:${NC}" >&2
    echo -e "${YELLOW}\"$commit_msg\"${NC}" >&2
    echo "" >&2
    echo -e "${RED}Quality bypasses are STRICTLY FORBIDDEN!${NC}" >&2
    echo -e "${YELLOW}Rewrite your commit to focus on legitimate changes.${NC}" >&2
    exit 1
fi

# Check for commit messages about disabling or circumventing checks
bypass_patterns=(
    "disable.*hook"
    "remove.*hook" 
    "temp.*disable"
    "temporarily.*disable"
    "circumvent"
    "work.*around.*hook"
    "bypass.*pre.?commit"
    "no.?verify"
    "--no-verify"
    "skip.*shellcheck"
)

for pattern in "${bypass_patterns[@]}"; do
    if echo "$commit_msg" | grep -qiE "$pattern"; then
        echo -e "${RED}${BOLD}🚫 SUSPICIOUS COMMIT MESSAGE! 🚫${NC}" >&2
        echo -e "${RED}Pattern detected: $pattern${NC}" >&2
        echo -e "${YELLOW}Quality system violations are not permitted.${NC}" >&2
        exit 1
    fi
done

# Verify the quality system is still intact before allowing commit
readonly HOOKS_DIR=".git/hooks"
readonly QUALITY_SCRIPT="scripts/hooks/pre-commit.sh"

if [[ ! -e "$HOOKS_DIR/pre-commit" ]]; then
    echo -e "${RED}${BOLD}🚨 QUALITY SYSTEM COMPROMISED! 🚨${NC}" >&2
    echo -e "${RED}Pre-commit hook is missing!${NC}" >&2
    echo -e "${YELLOW}Restoring quality system integrity...${NC}" >&2
    ln -sf "../../$QUALITY_SCRIPT" "$HOOKS_DIR/pre-commit"
    echo -e "${RED}Commit REJECTED. Try again with quality system restored.${NC}" >&2
    exit 1
fi

if [[ ! -x "$QUALITY_SCRIPT" ]]; then
    echo -e "${RED}${BOLD}🚨 QUALITY SYSTEM COMPROMISED! 🚨${NC}" >&2
    echo -e "${RED}Quality check script is not executable!${NC}" >&2
    chmod +x "$QUALITY_SCRIPT"
    echo -e "${RED}Commit REJECTED. Try again with quality system restored.${NC}" >&2
    exit 1
fi

# All checks passed
exit 0