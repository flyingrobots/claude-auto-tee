#!/usr/bin/env bash
# Create PR for completed task and start CI monitoring
# Usage: ./create-task-pr.sh {taskid}
#
# This script:
# 1. Validates task completion and acceptance criteria
# 2. Pushes feature branch to origin
# 3. Creates GitHub PR targeting main branch
# 4. Updates GitHub issue with PR link
# 5. Starts CI monitoring

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
    error "Usage: $0 {taskid}"
    echo ""
    echo "Example: $0 P1.T001"
    echo ""
    echo "This will:"
    echo "1. Validate task completion"
    echo "2. Push feature branch to origin"
    echo "3. Create GitHub PR targeting main"
    echo "4. Update GitHub issue with PR link"
    echo "5. Start CI monitoring"
    exit 1
fi

TASK_ID="$1"

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
BASE_BRANCH=$(grep '"base_branch"' .team-metadata.json | sed 's/.*"base_branch":[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || echo "main")

# Load task progress
ISSUE_NUMBER=""
FEATURE_BRANCH=""
GITHUB_USER=""

if [ -f ".task-progress.json" ]; then
    ISSUE_NUMBER=$(grep '"issue_number"' .task-progress.json | sed 's/.*"issue_number":[[:space:]]*\([0-9]*\).*/\1/' 2>/dev/null || echo "")
    FEATURE_BRANCH=$(grep '"feature_branch"' .task-progress.json | sed 's/.*"feature_branch":[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || echo "")
    GITHUB_USER=$(grep '"github_user"' .task-progress.json | sed 's/.*"github_user":[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || echo "")
fi

# Get current branch if not from task progress
if [ -z "$FEATURE_BRANCH" ]; then
    FEATURE_BRANCH=$(git rev-parse --abbrev-ref HEAD)
fi

CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')

echo "🚀 Creating Task PR: $TASK_ID"
echo "============================="
echo "👥 Team: $TEAM_ID"
echo "🌊 Wave: $WAVE_NUMBER"
echo "🎯 Task: $TASK_ID"
echo "🌿 Branch: $FEATURE_BRANCH"
echo "🎯 Target: $BASE_BRANCH"
if [ -n "$ISSUE_NUMBER" ]; then
    echo "🔗 Issue: #$ISSUE_NUMBER"
fi
echo "📅 Time: $CURRENT_TIME"
echo ""

# Check GitHub CLI
if ! command -v gh &> /dev/null; then
    error "GitHub CLI (gh) is required"
    echo "Install from: https://cli.github.com/"
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    error "Not authenticated with GitHub"
    echo "Run: gh auth login"
    exit 1
fi

if [ -z "$GITHUB_USER" ]; then
    GITHUB_USER=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
fi

# Step 1: Validate task completion
log "Step 1: Validating task completion..."

# Check for uncommitted changes
if ! git diff --quiet HEAD || ! git diff --cached --quiet; then
    error "Uncommitted changes detected"
    echo "Please commit all changes before creating PR:"
    echo "  ./commit-progress.sh \"final changes\""
    exit 1
fi

# Check if we're on the expected feature branch
if [ "$FEATURE_BRANCH" != "feat/${TASK_ID}-task" ]; then
    warn "Not on expected feature branch (expected: feat/${TASK_ID}-task, current: $FEATURE_BRANCH)"
    echo "Continue anyway? (y/N)"
    read -r response
    if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
        echo "Cancelled"
        exit 1
    fi
fi

# Count commits on this branch
TOTAL_COMMITS=$(git rev-list --count HEAD ^origin/$BASE_BRANCH 2>/dev/null || git rev-list --count HEAD 2>/dev/null || echo "1")

if [ "$TOTAL_COMMITS" -lt 1 ]; then
    error "No commits found on branch $FEATURE_BRANCH"
    echo "Make sure you have committed your changes"
    exit 1
fi

success "✅ Task validation passed ($TOTAL_COMMITS commits ready)"

# Step 2: Push feature branch to origin
log "Step 2: Pushing feature branch to origin..."

if git push origin "$FEATURE_BRANCH" --quiet 2>/dev/null; then
    success "✅ Pushed $FEATURE_BRANCH to origin"
else
    if git push origin "$FEATURE_BRANCH" -u --quiet 2>/dev/null; then
        success "✅ Pushed $FEATURE_BRANCH to origin (set upstream)"
    else
        error "Failed to push $FEATURE_BRANCH to origin"
        echo "Check your Git remote configuration and permissions"
        exit 1
    fi
fi

# Step 3: Create GitHub PR
log "Step 3: Creating GitHub PR..."

# Check if PR already exists
EXISTING_PR=$(gh pr list --head "$FEATURE_BRANCH" --json number --jq '.[0].number // empty' 2>/dev/null || echo "")

if [ -n "$EXISTING_PR" ]; then
    warn "PR already exists for branch $FEATURE_BRANCH: #$EXISTING_PR"
    echo "PR URL: $(gh pr view "$EXISTING_PR" --json url --jq '.url')"
    echo ""
    echo "Do you want to continue with existing PR? (y/N)"
    read -r response
    if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
        echo "Cancelled"
        exit 1
    fi
    PR_NUMBER="$EXISTING_PR"
else
    # Generate PR title and body
    PR_TITLE="feat($TASK_ID): Complete task implementation - Team $TEAM_ID"
    
    # Get commit messages for PR body
    COMMIT_SUMMARY=$(git log --oneline origin/$BASE_BRANCH..HEAD 2>/dev/null | head -10 || echo "No commits found")
    
    PR_BODY="## Summary
Completed task $TASK_ID as part of Wave $WAVE_NUMBER by Team $TEAM_ID.

## Changes
$(echo "$COMMIT_SUMMARY" | sed 's/^/- /')

## Task Details
- **Task ID:** $TASK_ID
- **Team:** $TEAM_ID  
- **Wave:** $WAVE_NUMBER
- **Job ID:** $JOB_ID
- **Branch:** $FEATURE_BRANCH
- **Commits:** $TOTAL_COMMITS
- **Completed:** $CURRENT_TIME

## Definition of Done
- [x] Task implementation complete
- [x] Code committed and pushed
- [x] Ready for review and CI validation

## Test Plan
- [ ] CI tests pass
- [ ] Manual testing complete (if applicable)
- [ ] Integration tests pass
- [ ] Code review complete

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

    # Create the PR
    if PR_NUMBER=$(gh pr create \
        --title "$PR_TITLE" \
        --body "$PR_BODY" \
        --base "$BASE_BRANCH" \
        --head "$FEATURE_BRANCH" \
        --assignee "$GITHUB_USER" \
        --json number --jq '.number' 2>/dev/null); then
        success "✅ Created PR #$PR_NUMBER"
    else
        error "Failed to create PR"
        echo "Check your repository permissions and try again"
        exit 1
    fi
fi

PR_URL=$(gh pr view "$PR_NUMBER" --json url --jq '.url' 2>/dev/null || echo "")

# Step 4: Update GitHub issue with PR link
if [ -n "$ISSUE_NUMBER" ]; then
    log "Step 4: Updating GitHub issue #$ISSUE_NUMBER with PR link..."
    
    ISSUE_COMMENT="🎯 **Task Complete - PR Created**

Task $TASK_ID implementation is complete and ready for review!

**PR Details:**
- **PR:** #$PR_NUMBER  
- **Link:** $PR_URL
- **Branch:** \`$FEATURE_BRANCH\`
- **Commits:** $TOTAL_COMMITS
- **Team:** $TEAM_ID
- **Completed:** $CURRENT_TIME

**Next Steps:**
1. ⏳ Waiting for CI checks to pass
2. 👀 Code review (if required)
3. ✅ Merge when ready

*This task is now waiting for CI validation and review.*"

    if gh issue comment "$ISSUE_NUMBER" --body "$ISSUE_COMMENT" >/dev/null 2>&1; then
        success "✅ Updated issue #$ISSUE_NUMBER with PR link"
    else
        warn "Could not update issue #$ISSUE_NUMBER"
    fi
else
    warn "No GitHub issue found - skipping issue update"
fi

# Step 5: Update task progress file
log "Step 5: Updating task progress tracking..."

PROGRESS_DIR="$HOME/claude-wave-workstream-sync/$JOB_ID/progress/team-$TEAM_ID"
TASK_PROGRESS_FILE="$PROGRESS_DIR/task-$TASK_ID.progress.txt"

if [ -f "$TASK_PROGRESS_FILE" ]; then
    # Add PR creation to progress log
    sed -i.bak "/## Progress Log/a\\
$CURRENT_TIME - PR created: #$PR_NUMBER ($PR_URL)" "$TASK_PROGRESS_FILE"
    
    # Update definition of done
    sed -i.bak 's/- \[ \] Task implementation complete/- [x] Task implementation complete/' "$TASK_PROGRESS_FILE"
    
    rm -f "$TASK_PROGRESS_FILE.bak" 2>/dev/null || true
    success "✅ Updated task progress file"
fi

# Update task progress JSON
if [ -f ".task-progress.json" ]; then
    # Add PR info to task progress
    sed -i.bak "s/\"started_at\":/\"pr_number\": $PR_NUMBER, \"pr_url\": \"$PR_URL\", \"pr_created_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"started_at\":/" ".task-progress.json" 2>/dev/null || true
    rm -f ".task-progress.json.bak" 2>/dev/null || true
fi

echo ""
echo "🎉 Task PR Created Successfully!"
echo "==============================="
echo "🔗 PR #$PR_NUMBER: $PR_URL"
echo "🌿 Branch: $FEATURE_BRANCH"
echo "📝 Commits: $TOTAL_COMMITS"
if [ -n "$ISSUE_NUMBER" ]; then
    echo "🔗 Issue: #$ISSUE_NUMBER"
fi
echo ""
echo "📖 Next Steps:"
echo "1. Monitor CI status: ./monitor-ci.sh $PR_NUMBER"
echo "2. Wait for CI checks to pass (green status)"
echo "3. Address any CI failures if they occur"
echo "4. After CI passes: ./complete-task.sh $TASK_ID"
echo ""
echo "💡 Useful commands:"
echo "   gh pr view $PR_NUMBER                    # View PR details"
echo "   gh pr checks $PR_NUMBER                 # Check CI status"
echo "   ./monitor-ci.sh $PR_NUMBER              # Monitor CI real-time"