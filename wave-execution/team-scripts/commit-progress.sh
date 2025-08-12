#!/usr/bin/env bash
# Commit progress with automatic GitHub issue updates
# Usage: ./commit-progress.sh "step description"
#
# This script:
# 1. Creates a commit with the progress description
# 2. Updates the task progress file
# 3. Posts progress comment to GitHub issue

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

# Check arguments
if [ $# -lt 1 ]; then
    error "Usage: $0 \"step description\""
    echo ""
    echo "Examples:"
    echo "  $0 \"implemented core functionality\""
    echo "  $0 \"added unit tests\""
    echo "  $0 \"updated documentation\""
    echo ""
    echo "This will:"
    echo "1. Create a commit with the progress description"
    echo "2. Update task progress tracking"
    echo "3. Post progress to GitHub issue"
    exit 1
fi

STEP_DESCRIPTION="$1"

# Load team metadata
if [ ! -f ".team-metadata.json" ]; then
    error "Not in a team worktree directory"
    echo "This script must be run from a team worktree created by git-worktree-manager.sh"
    exit 1
fi

# Extract metadata
TEAM_ID=$(grep '"team_id"' .team-metadata.json | sed 's/.*"team_id":[[:space:]]*"\([^"]*\)".*/\1/')
WAVE_NUMBER=$(grep '"wave_number"' .team-metadata.json | sed 's/.*"wave_number":[[:space:]]*\([0-9]*\).*/\1/')
JOB_ID=$(grep '"job_id"' .team-metadata.json | sed 's/.*"job_id":[[:space:]]*"\([^"]*\)".*/\1/')

# Load task progress if available
TASK_ID=""
ISSUE_NUMBER=""
FEATURE_BRANCH=""
GITHUB_USER=""

if [ -f ".task-progress.json" ]; then
    TASK_ID=$(grep '"task_id"' .task-progress.json | sed 's/.*"task_id":[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || echo "")
    ISSUE_NUMBER=$(grep '"issue_number"' .task-progress.json | sed 's/.*"issue_number":[[:space:]]*\([0-9]*\).*/\1/' 2>/dev/null || echo "")
    FEATURE_BRANCH=$(grep '"feature_branch"' .task-progress.json | sed 's/.*"feature_branch":[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || echo "")
    GITHUB_USER=$(grep '"github_user"' .task-progress.json | sed 's/.*"github_user":[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || echo "")
fi

# If no task progress, try to get current branch
if [ -z "$FEATURE_BRANCH" ]; then
    FEATURE_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    # Try to extract task ID from branch name
    if [[ "$FEATURE_BRANCH" =~ feat/([^-]+)-task ]]; then
        TASK_ID="${BASH_REMATCH[1]}"
    fi
fi

CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
COMMIT_HASH_SHORT=""

echo "💾 Committing Progress"
echo "====================="
echo "👥 Team: $TEAM_ID"
echo "🌊 Wave: $WAVE_NUMBER"
echo "📝 Description: $STEP_DESCRIPTION"
if [ -n "$TASK_ID" ]; then
    echo "🎯 Task: $TASK_ID"
fi
if [ -n "$FEATURE_BRANCH" ]; then
    echo "🌿 Branch: $FEATURE_BRANCH"
fi
echo "⏰ Time: $CURRENT_TIME"
echo ""

# Check if there are changes to commit
if git diff --quiet HEAD && git diff --cached --quiet; then
    warn "No changes to commit"
    echo "Make some changes first, then run this script"
    exit 1
fi

# Check GitHub CLI if we have an issue to update
UPDATE_GITHUB=false
if [ -n "$ISSUE_NUMBER" ] && command -v gh &> /dev/null && gh auth status >/dev/null 2>&1; then
    UPDATE_GITHUB=true
    if [ -z "$GITHUB_USER" ]; then
        GITHUB_USER=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
    fi
fi

# Step 1: Stage all changes
log "Step 1: Staging changes..."
git add .
success "✅ Changes staged"

# Step 2: Create commit
log "Step 2: Creating commit..."
COMMIT_MSG="progress($TASK_ID): $STEP_DESCRIPTION

Team: $TEAM_ID
Wave: $WAVE_NUMBER
Time: $CURRENT_TIME"

git commit -m "$COMMIT_MSG" --quiet
COMMIT_HASH_SHORT=$(git rev-parse --short HEAD)
success "✅ Commit created: $COMMIT_HASH_SHORT"

# Step 3: Update task progress file
if [ -n "$TASK_ID" ]; then
    log "Step 3: Updating task progress file..."
    
    PROGRESS_DIR="$HOME/claude-wave-workstream-sync/$JOB_ID/progress/team-$TEAM_ID"
    TASK_PROGRESS_FILE="$PROGRESS_DIR/task-$TASK_ID.progress.txt"
    
    if [ -f "$TASK_PROGRESS_FILE" ]; then
        # Add progress entry to the file
        sed -i.bak "/## Progress Log/a\\
$CURRENT_TIME - $STEP_DESCRIPTION (commit: $COMMIT_HASH_SHORT)" "$TASK_PROGRESS_FILE"
        
        rm -f "$TASK_PROGRESS_FILE.bak" 2>/dev/null || true
        success "✅ Updated task progress file"
    else
        warn "Task progress file not found: $TASK_PROGRESS_FILE"
    fi
fi

# Step 4: Update GitHub issue
if [ "$UPDATE_GITHUB" = true ] && [ -n "$ISSUE_NUMBER" ]; then
    log "Step 4: Updating GitHub issue #$ISSUE_NUMBER..."
    
    # Count total commits on this branch (excluding initial branch commit)
    TOTAL_COMMITS=$(git rev-list --count HEAD ^origin/main 2>/dev/null || git rev-list --count HEAD 2>/dev/null || echo "1")
    
    # Create progress comment
    COMMENT_BODY="🔄 **Progress Update - Team $TEAM_ID**

**Step:** $STEP_DESCRIPTION  
**Commit:** \`$COMMIT_HASH_SHORT\`  
**Branch:** \`$FEATURE_BRANCH\`  
**Time:** $CURRENT_TIME  
**Total Commits:** $TOTAL_COMMITS  

*Task $TASK_ID in Wave $WAVE_NUMBER*"

    if gh issue comment "$ISSUE_NUMBER" --body "$COMMENT_BODY" >/dev/null 2>&1; then
        success "✅ Posted progress to GitHub issue #$ISSUE_NUMBER"
    else
        warn "Could not post comment to GitHub issue #$ISSUE_NUMBER"
    fi
else
    if [ -z "$ISSUE_NUMBER" ]; then
        warn "No GitHub issue found - progress not posted to GitHub"
    elif ! command -v gh &> /dev/null; then
        warn "GitHub CLI not available - progress not posted to GitHub"
    elif ! gh auth status >/dev/null 2>&1; then
        warn "Not authenticated with GitHub - progress not posted to GitHub"
    fi
fi

echo ""
echo "✅ Progress Committed Successfully!"
echo "=================================="
echo "📝 Commit: $COMMIT_HASH_SHORT - $STEP_DESCRIPTION"
if [ -n "$TASK_ID" ]; then
    echo "🎯 Task: $TASK_ID"
fi
if [ "$UPDATE_GITHUB" = true ] && [ -n "$ISSUE_NUMBER" ]; then
    echo "🔗 GitHub: Updated issue #$ISSUE_NUMBER"
    echo "📋 Issue URL: $(gh issue view "$ISSUE_NUMBER" --json url --jq '.url' 2>/dev/null || echo 'N/A')"
fi
echo ""
echo "📖 Next Steps:"
echo "1. Continue working on the task"
echo "2. Use: ./commit-progress.sh \"next step\" for more progress"
echo "3. When ready: ./create-task-pr.sh $TASK_ID"
echo ""
echo "💡 View recent commits: git log --oneline -5"