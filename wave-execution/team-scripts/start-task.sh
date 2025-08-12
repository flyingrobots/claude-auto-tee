#!/usr/bin/env bash
# Start a specific task with proper GitHub-native workflow setup
# Usage: ./start-task.sh {taskid}
# 
# This script:
# 1. Syncs to target branch (origin/main)
# 2. Creates feature branch feat/{taskid}-task
# 3. Assigns GitHub issue to current user
# 4. Sets up task progress tracking

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
    echo "1. Sync to origin/main"
    echo "2. Create feature branch feat/P1.T001-task"
    echo "3. Assign corresponding GitHub issue"
    echo "4. Set up task progress tracking"
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
BASE_BRANCH=$(grep '"base_branch"' .team-metadata.json | sed 's/.*"base_branch":[[:space:]]*"\([^"]*\)".*/\1/')

echo "🚀 Starting Task: $TASK_ID"
echo "================================="
echo "👥 Team: $TEAM_ID"
echo "🌊 Wave: $WAVE_NUMBER"
echo "🆔 Job: $JOB_ID"
echo "📅 Started: $(date '+%Y-%m-%d %H:%M:%S')"
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

# Get current user for issue assignment
GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "")
if [ -z "$GH_USER" ]; then
    error "Could not determine GitHub username"
    exit 1
fi

log "Authenticated as GitHub user: $GH_USER"

# Step 1: Sync to target branch
log "Step 1: Syncing to target branch ($BASE_BRANCH)..."
git fetch origin "$BASE_BRANCH" --quiet

if ! git checkout "origin/$BASE_BRANCH" --quiet 2>/dev/null; then
    error "Failed to checkout origin/$BASE_BRANCH"
    echo "Ensure the base branch exists and is accessible"
    exit 1
fi

success "✅ Synced to origin/$BASE_BRANCH"

# Step 2: Create feature branch
FEATURE_BRANCH="feat/${TASK_ID}-task"
log "Step 2: Creating feature branch: $FEATURE_BRANCH"

if git show-ref --verify --quiet "refs/heads/$FEATURE_BRANCH"; then
    warn "Branch $FEATURE_BRANCH already exists"
    echo "Switching to existing branch..."
    git checkout "$FEATURE_BRANCH" --quiet
else
    git checkout -B "$FEATURE_BRANCH" --quiet
    success "✅ Created and switched to $FEATURE_BRANCH"
fi

# Step 3: Find and assign GitHub issue
log "Step 3: Finding GitHub issue for task $TASK_ID..."

# Search for issue with task ID in title
ISSUE_NUMBER=$(gh issue list --state open --search "$TASK_ID in:title" --json number --jq '.[0].number // empty' 2>/dev/null || echo "")

if [ -z "$ISSUE_NUMBER" ]; then
    warn "No GitHub issue found with '$TASK_ID' in title"
    echo ""
    echo "Please ensure GitHub issues are created for all tasks, or create manually:"
    echo "  gh issue create --title '$TASK_ID: [Task Description]' --body 'Task implementation for $TASK_ID'"
    echo ""
    echo "Continuing without issue assignment..."
else
    log "Found GitHub issue #$ISSUE_NUMBER for task $TASK_ID"
    
    # Assign issue to current user
    if gh issue edit "$ISSUE_NUMBER" --assignee "$GH_USER" >/dev/null 2>&1; then
        success "✅ Assigned issue #$ISSUE_NUMBER to $GH_USER"
        
        # Add comment indicating task start
        gh issue comment "$ISSUE_NUMBER" --body "🚀 **Task Started by Team $TEAM_ID**

Started working on this task in branch: \`$FEATURE_BRANCH\`
Job ID: \`$JOB_ID\`
Wave: $WAVE_NUMBER

Status: In Progress 🔄" >/dev/null 2>&1 || warn "Could not add start comment to issue"
        
    else
        warn "Could not assign issue #$ISSUE_NUMBER to $GH_USER"
    fi
    
    # Store issue number for later use
    echo "{ \"task_id\": \"$TASK_ID\", \"issue_number\": $ISSUE_NUMBER, \"feature_branch\": \"$FEATURE_BRANCH\", \"started_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"github_user\": \"$GH_USER\" }" > ".task-progress.json"
fi

# Step 4: Set up task progress tracking
log "Step 4: Setting up task progress tracking..."

PROGRESS_DIR="$HOME/claude-wave-workstream-sync/$JOB_ID/progress/team-$TEAM_ID"
TASK_PROGRESS_FILE="$PROGRESS_DIR/task-$TASK_ID.progress.txt"

mkdir -p "$PROGRESS_DIR"

# Create initial progress file
cat > "$TASK_PROGRESS_FILE" << EOF
# Task Progress: $TASK_ID
# Team: $TEAM_ID
# Wave: $WAVE_NUMBER
# Job: $JOB_ID
# Started: $(date '+%Y-%m-%d %H:%M:%S')
# Feature Branch: $FEATURE_BRANCH
# GitHub User: $GH_USER
# GitHub Issue: ${ISSUE_NUMBER:-"Not found"}

## Progress Log
$(date '+%Y-%m-%d %H:%M:%S') - Task started by $GH_USER in branch $FEATURE_BRANCH

## Definition of Done Checklist
- [ ] Task implementation complete
- [ ] Unit tests written and passing
- [ ] Integration tests passing
- [ ] Code reviewed (if applicable)
- [ ] Documentation updated
- [ ] Acceptance criteria met

## Next Steps
1. Implement task requirements
2. Run: ./commit-progress.sh "step description" for each major step
3. When complete: ./create-task-pr.sh $TASK_ID
EOF

success "✅ Created task progress file: $TASK_PROGRESS_FILE"

# Create initial commit on feature branch
git add .task-progress.json 2>/dev/null || true
if git diff --cached --quiet; then
    # No staged changes, just create empty commit
    git commit --allow-empty -m "feat($TASK_ID): start task implementation

- Created feature branch feat/$TASK_ID-task
- Assigned GitHub issue ${ISSUE_NUMBER:-"(manual creation needed)"}
- Set up task progress tracking

Task started by team $TEAM_ID in wave $WAVE_NUMBER" --quiet
else
    # Stage and commit the task progress file
    git commit -m "feat($TASK_ID): start task implementation

- Created feature branch feat/$TASK_ID-task  
- Assigned GitHub issue ${ISSUE_NUMBER:-"(manual creation needed)"}
- Set up task progress tracking

Task started by team $TEAM_ID in wave $WAVE_NUMBER" --quiet
fi

success "✅ Created initial commit for task $TASK_ID"

echo ""
echo "🎯 Task $TASK_ID Started Successfully!"
echo "====================================="
echo "🌿 Feature Branch: $FEATURE_BRANCH"
echo "📁 Progress File: $TASK_PROGRESS_FILE"
if [ -n "${ISSUE_NUMBER:-}" ]; then
    echo "🔗 GitHub Issue: #$ISSUE_NUMBER"
    echo "📋 Issue URL: $(gh issue view "$ISSUE_NUMBER" --json url --jq '.url' 2>/dev/null || echo 'N/A')"
fi
echo ""
echo "📖 Next Steps:"
echo "1. Implement the task requirements"
echo "2. Use: ./commit-progress.sh \"step description\" to track progress"
echo "3. When ready: ./create-task-pr.sh $TASK_ID"
echo ""
echo "💡 Useful commands:"
echo "   gh issue view ${ISSUE_NUMBER:-"ISSUE_NUM"}  # View issue details"
echo "   git log --oneline                          # View commit history"
echo "   ./commit-progress.sh \"implemented X\"       # Commit with progress"