#!/usr/bin/env bash
# Validate that team is ready to mark wave complete
# Checks PR status, branch state, and task completion

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Load team metadata
if [ ! -f ".team-metadata.json" ]; then
    error "Not in a team worktree directory"
    exit 1
fi

TEAM_ID=$(grep '"team_id"' .team-metadata.json | sed 's/.*"team_id":[[:space:]]*"\([^"]*\)".*/\1/')
WAVE_NUMBER=$(grep '"wave_number"' .team-metadata.json | sed 's/.*"wave_number":[[:space:]]*\([0-9]*\).*/\1/')
JOB_ID=$(grep '"job_id"' .team-metadata.json | sed 's/.*"job_id":[[:space:]]*"\([^"]*\)".*/\1/')
BRANCH_NAME=$(grep '"branch_name"' .team-metadata.json | sed 's/.*"branch_name":[[:space:]]*"\([^"]*\)".*/\1/')

echo "🔍 Pre-Completion Validation"
echo "============================"
echo "👥 Team: $TEAM_ID"
echo "🌊 Wave: $WAVE_NUMBER" 
echo "🌿 Branch: $BRANCH_NAME"
echo "🆔 Job: $JOB_ID"
echo ""

# Check 1: Git status
log "Checking git status..."
if ! git diff --quiet HEAD; then
    error "Uncommitted changes detected"
    echo "Please commit all changes before marking wave complete"
    git status --short
    exit 1
fi

if ! git diff --quiet --cached; then
    error "Staged changes detected"
    echo "Please commit staged changes before marking wave complete"
    git status --short
    exit 1
fi

success "✅ Working directory clean"

# Check 2: Branch status  
log "Checking branch sync status..."
git fetch origin main --quiet || warn "Could not fetch from origin"

# Check if we're ahead of main
COMMITS_AHEAD=$(git rev-list --count HEAD ^origin/main 2>/dev/null || echo "0")
COMMITS_BEHIND=$(git rev-list --count origin/main ^HEAD 2>/dev/null || echo "0")

if [ "$COMMITS_AHEAD" -eq 0 ]; then
    error "No new commits on branch $BRANCH_NAME"
    echo "Branch appears identical to main - no work to submit"
    exit 1
fi

success "✅ Branch has $COMMITS_AHEAD commits ahead of main"

if [ "$COMMITS_BEHIND" -gt 0 ]; then
    warn "⚠️  Branch is $COMMITS_BEHIND commits behind main"
    echo "Consider rebasing or merging main before creating PR"
fi

# Check 3: GitHub CLI and PR status
if ! command -v gh &> /dev/null; then
    error "GitHub CLI (gh) is required for PR validation"
    echo "Install from: https://cli.github.com/"
    exit 1
fi

log "Checking GitHub authentication..."
if ! gh auth status >/dev/null 2>&1; then
    error "Not authenticated with GitHub"
    echo "Run: gh auth login"
    exit 1
fi

success "✅ GitHub CLI authenticated"

log "Checking PR status..."
PR_INFO=$(gh pr status --json state,number,headRefName,url 2>/dev/null || echo "{}")

# Check if current branch has a PR
CURRENT_BRANCH_PR=$(echo "$PR_INFO" | jq -r ".currentBranch // {}")

if [ "$CURRENT_BRANCH_PR" = "{}" ] || [ "$CURRENT_BRANCH_PR" = "null" ]; then
    warn "⚠️  No PR found for current branch"
    echo ""
    echo "Create a PR first:"
    echo "  gh pr create --title 'Wave $WAVE_NUMBER - Team $TEAM_ID' --body 'Completed wave $WAVE_NUMBER tasks'"
    echo ""
    echo "Or create PR via GitHub web interface"
    exit 1
fi

PR_STATE=$(echo "$CURRENT_BRANCH_PR" | jq -r '.state')
PR_NUMBER=$(echo "$CURRENT_BRANCH_PR" | jq -r '.number')
PR_URL=$(echo "$CURRENT_BRANCH_PR" | jq -r '.url')

echo "🔗 PR #$PR_NUMBER: $PR_URL"
echo "📊 Status: $PR_STATE"

case "$PR_STATE" in
    "OPEN")
        warn "⚠️  PR is still open - not yet merged"
        echo ""
        echo "Wait for PR review and merge before marking wave complete"
        echo "PR: $PR_URL"
        ;;
    "MERGED")
        success "✅ PR is merged! Ready to mark wave complete"
        echo ""
        echo "PR #$PR_NUMBER has been merged to main"
        echo "You can now run: ./team-scripts/mark-wave-complete.sh"
        exit 0
        ;;
    "CLOSED")
        error "❌ PR was closed without merging"
        echo ""
        echo "PR #$PR_NUMBER was closed. You may need to:"
        echo "1. Reopen the PR if closed accidentally"
        echo "2. Create a new PR if issues were found"
        echo "3. Address any feedback and resubmit"
        exit 1
        ;;
    *)
        error "Unknown PR state: $PR_STATE"
        exit 1
        ;;
esac

# Check 4: Task completion (if task list exists)
TASK_FILE="$HOME/claude-wave-workstream-sync/$JOB_ID/assignments/$TEAM_ID-wave-$WAVE_NUMBER-tasklist.md"
if [ -f "$TASK_FILE" ]; then
    log "Checking task completion status..."
    
    # Simple check for task status updates in the file
    TOTAL_TASKS=$(grep -c "^### P1\.T" "$TASK_FILE" 2>/dev/null || echo "0")
    COMPLETED_TASKS=$(grep -c "Status.*✅\|Status.*Complete\|Status.*Done" "$TASK_FILE" 2>/dev/null || echo "0")
    
    echo "📋 Tasks: $COMPLETED_TASKS/$TOTAL_TASKS marked complete"
    
    if [ "$COMPLETED_TASKS" -lt "$TOTAL_TASKS" ]; then
        warn "⚠️  Not all tasks marked complete in task list"
        echo "Update task statuses in: $TASK_FILE"
        echo ""
        echo "This is advisory - ensure all assigned tasks are actually complete"
    else
        success "✅ All tasks marked complete in task list"
    fi
else
    warn "⚠️  Task list not found: $TASK_FILE"
    echo "Ensure all assigned wave $WAVE_NUMBER tasks are complete"
fi

echo ""
echo "🎯 Next Steps:"
if [ "$PR_STATE" = "MERGED" ]; then
    echo "1. ✅ PR merged - ready to mark wave complete"
    echo "2. Run: ./team-scripts/mark-wave-complete.sh"
else
    echo "1. ⏳ Wait for PR #$PR_NUMBER to be reviewed and merged"
    echo "2. Monitor PR status: gh pr view $PR_NUMBER"
    echo "3. After merge, run: ./team-scripts/mark-wave-complete.sh"
fi