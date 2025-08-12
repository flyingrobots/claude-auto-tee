#!/usr/bin/env bash
# Pre-push hook that runs integrity check and quality verification
# Ensures no quality bypasses make it to remote repository

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

echo -e "${BOLD}🚀 Pre-push Quality Verification${NC}"
echo "================================="

# Run integrity check first
echo -e "${YELLOW}Running integrity check...${NC}"
if ! "$SCRIPT_DIR/../integrity-guard.sh"; then
    echo -e "${RED}${BOLD}🚫 PUSH BLOCKED: Integrity check failed!${NC}" >&2
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Integrity verified - push allowed${NC}"
exit 0