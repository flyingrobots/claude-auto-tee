#!/usr/bin/env bash
# Git Worktree Manager for Wave-Based Execution
# Creates isolated worktrees for team independence with automatic branch management

set -euo pipefail

# Configuration
WORKTREE_BASE_DIR="${WORKTREE_BASE_DIR:-$HOME/claude-wave-worktrees}"
MAIN_REPO_DIR="${MAIN_REPO_DIR:-$(git rev-parse --show-toplevel)}"
PROJECT_NAME="${PROJECT_NAME:-$(basename "$MAIN_REPO_DIR")}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" >&2
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}" >&2
}

# Validate we're in a git repo
validate_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error "Not in a git repository"
        exit 1
    fi
}

# Create team worktree with proper isolation
create_team_worktree() {
    local team_id="$1"
    local wave_number="$2"
    local job_id="${3:-$(date +%Y%m%d-%H%M%S)}"
    
    validate_git_repo
    
    local worktree_dir="$WORKTREE_BASE_DIR/$PROJECT_NAME-$job_id/$team_id-wave-$wave_number"
    local branch_name="team-$team_id/wave-$wave_number/$job_id"
    
    log "Creating worktree for team $team_id, wave $wave_number"
    
    # Ensure base directory exists
    mkdir -p "$(dirname "$worktree_dir")"
    
    # Create new branch from main
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        warn "Branch $branch_name already exists, using existing branch"
    else
        log "Creating new branch: $branch_name"
        git checkout -b "$branch_name" main
        git checkout main  # Switch back to main
    fi
    
    # Create worktree
    if [ -d "$worktree_dir" ]; then
        warn "Worktree directory $worktree_dir already exists, removing..."
        git worktree remove "$worktree_dir" 2>/dev/null || rm -rf "$worktree_dir"
    fi
    
    log "Creating worktree at: $worktree_dir"
    git worktree add "$worktree_dir" "$branch_name"
    
    # Setup team-specific configuration in worktree
    cd "$worktree_dir"
    
    # Create team metadata
    cat > .team-metadata.json << EOF
{
    "team_id": "$team_id",
    "wave_number": $wave_number,
    "job_id": "$job_id",
    "branch_name": "$branch_name",
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "worktree_path": "$worktree_dir",
    "main_repo_path": "$MAIN_REPO_DIR"
}
EOF
    
    # Create team-specific scripts
    cat > team-scripts/sync-status.sh << 'EOF'
#!/usr/bin/env bash
# Check sync status for this team
source .team-metadata.json 2>/dev/null || {
    echo "Error: Not in a team worktree directory"
    exit 1
}

SYNC_DIR="$HOME/claude-wave-workstream-sync/$job_id/wave-$wave_number"
READY_FILE="$SYNC_DIR/$team_id.ready.txt"

echo "Team: $team_id"
echo "Wave: $wave_number"
echo "Job ID: $job_id"
echo "Ready file: $READY_FILE"
echo "Status: $([ -f "$READY_FILE" ] && echo "READY" || echo "NOT READY")"

if [ -f "$READY_FILE" ]; then
    echo "Ready since: $(stat -f %Sm "$READY_FILE" 2>/dev/null || stat -c %y "$READY_FILE" 2>/dev/null)"
    echo "Content:"
    cat "$READY_FILE"
fi
EOF
    
    chmod +x team-scripts/sync-status.sh
    
    # Create wave completion script
    cat > team-scripts/mark-wave-complete.sh << 'EOF'
#!/usr/bin/env bash
# Mark wave complete ONLY after PR is merged
set -euo pipefail

source <(grep -E '^[[:space:]]*"[^"]+":' .team-metadata.json | sed 's/[[:space:]]*"//g' | sed 's/":[[:space:]]*/=/g' | sed 's/,$//')

# Validate PR is merged
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is required to validate PR status"
    exit 1
fi

# Check if current branch has an open/merged PR
PR_STATUS=$(gh pr status --json state,number,headRefName | jq -r ".currentBranch.state // \"none\"")

if [ "$PR_STATUS" != "MERGED" ]; then
    echo "Error: Cannot mark wave complete. PR status: $PR_STATUS"
    echo "Wave can only be marked complete AFTER PR is merged to main"
    echo ""
    echo "Current status: $PR_STATUS"
    echo "Required status: MERGED"
    exit 1
fi

# Get PR details for audit trail
PR_NUMBER=$(gh pr status --json number,headRefName | jq -r ".currentBranch.number // \"unknown\"")
PR_URL=$(gh pr status --json url,headRefName | jq -r ".currentBranch.url // \"unknown\"")

# Create sync directory and ready file
SYNC_DIR="$HOME/claude-wave-workstream-sync/$job_id/wave-$wave_number"
READY_FILE="$SYNC_DIR/$team_id.ready.txt"

mkdir -p "$SYNC_DIR"

# Create ready file with audit trail
cat > "$READY_FILE" << EOF_READY
TEAM_WAVE_COMPLETION_CONFIRMATION

Team ID: $team_id
Wave Number: $wave_number
Job ID: $job_id
Completed At: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Branch: $branch_name
PR Number: #$PR_NUMBER
PR URL: $PR_URL
PR Status: MERGED
Hostname: $(hostname)
User: $(whoami)

Task Completion Verified: YES
PR Merged to Main: YES
Ready for Next Wave: YES

Verification Hash: $(echo "$team_id-$wave_number-$job_id-$(date +%s)" | sha256sum | cut -d' ' -f1)
EOF_READY

echo "✅ Wave $wave_number marked complete for team $team_id"
echo "📄 Ready file created: $READY_FILE"
echo "🔗 PR #$PR_NUMBER merged: $PR_URL"
echo ""
echo "Waiting for other teams to complete wave $wave_number..."

# Show sync status
./team-scripts/check-wave-sync.sh
EOF
    
    chmod +x team-scripts/mark-wave-complete.sh
    
    # Create task list for this team/wave
    mkdir -p tasks
    
    success "Team worktree created successfully!"
    echo ""
    echo "📁 Worktree location: $worktree_dir"
    echo "🌿 Branch: $branch_name"
    echo "👥 Team ID: $team_id"
    echo "🌊 Wave: $wave_number"
    echo "🆔 Job ID: $job_id"
    echo ""
    echo "Next steps:"
    echo "1. cd $worktree_dir"
    echo "2. Start working on wave $wave_number tasks"
    echo "3. Create PR when tasks complete"
    echo "4. Run ./team-scripts/mark-wave-complete.sh AFTER PR merges"
    
    cd "$MAIN_REPO_DIR"
}

# List all team worktrees
list_worktrees() {
    local job_id="${1:-}"
    
    validate_git_repo
    
    echo "Current Git Worktrees:"
    echo "======================"
    
    git worktree list | while read -r worktree branch commit; do
        if [[ "$worktree" == *"claude-wave-worktrees"* ]]; then
            if [ -f "$worktree/.team-metadata.json" ]; then
                local team_info=$(cd "$worktree" && cat .team-metadata.json)
                local team_id=$(echo "$team_info" | jq -r '.team_id')
                local wave=$(echo "$team_info" | jq -r '.wave_number')
                local job=$(echo "$team_info" | jq -r '.job_id')
                
                if [ -z "$job_id" ] || [ "$job" = "$job_id" ]; then
                    echo "📁 $worktree"
                    echo "   👥 Team: $team_id | 🌊 Wave: $wave | 🆔 Job: $job"
                    echo "   🌿 Branch: $branch"
                    echo ""
                fi
            else
                echo "📁 $worktree (no team metadata)"
                echo "   🌿 Branch: $branch"
                echo ""
            fi
        fi
    done
}

# Clean up worktrees
cleanup_worktrees() {
    local job_id="${1:-}"
    local force="${2:-false}"
    
    validate_git_repo
    
    if [ "$force" != "true" ] && [ -z "$job_id" ]; then
        error "Must specify job_id for cleanup, or use --force to clean all"
        exit 1
    fi
    
    log "Cleaning up worktrees..."
    
    git worktree list | while read -r worktree branch commit; do
        if [[ "$worktree" == *"claude-wave-worktrees"* ]]; then
            local should_clean=false
            
            if [ "$force" = "true" ]; then
                should_clean=true
            elif [ -f "$worktree/.team-metadata.json" ]; then
                local job=$(cd "$worktree" && jq -r '.job_id' .team-metadata.json 2>/dev/null || echo "")
                if [ "$job" = "$job_id" ]; then
                    should_clean=true
                fi
            fi
            
            if [ "$should_clean" = "true" ]; then
                log "Removing worktree: $worktree"
                git worktree remove "$worktree" --force 2>/dev/null || true
                
                # Clean up branch if it exists
                if git show-ref --verify --quiet "refs/heads/$branch"; then
                    log "Removing branch: $branch"
                    git branch -D "$branch" 2>/dev/null || true
                fi
            fi
        fi
    done
    
    # Clean up empty directories
    if [ -d "$WORKTREE_BASE_DIR" ]; then
        find "$WORKTREE_BASE_DIR" -type d -empty -delete 2>/dev/null || true
    fi
    
    success "Worktree cleanup complete"
}

# Create GitHub issue for wave coordination
create_wave_issue() {
    local wave_number="$1"
    local job_id="$2"
    
    if ! command -v gh &> /dev/null; then
        error "GitHub CLI (gh) is required for issue management"
        exit 1
    fi
    
    local issue_title="Wave $wave_number Coordination - Job $job_id"
    local issue_body=$(cat << EOF
# Wave $wave_number Team Coordination

**Job ID:** \`$job_id\`
**Wave:** $wave_number
**Started:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Team Status Tracking

Teams should comment on this issue with their status updates and mark themselves complete ONLY after their PR is merged.

### Wave $wave_number Tasks Summary
$(cat << 'TASKS_EOF'
<!-- This will be populated with wave-specific task breakdown -->
TASKS_EOF
)

## Completion Protocol

### For Teams:
1. ✅ Complete your assigned tasks in your team worktree
2. ✅ Create PR with your team's work
3. ✅ Get PR reviewed and merged to main
4. ✅ Run \`./team-scripts/mark-wave-complete.sh\` to create ready.txt
5. ✅ Comment on this issue: "Team [ID] wave $wave_number complete ✅"

### For Wave Sync:
- All teams must be marked complete before wave $(($wave_number + 1)) can begin
- Sync verification happens automatically via filesystem coordination
- Next wave starts only when ALL ready.txt files are present

## Team Comments
<!-- Teams add status updates here -->

EOF
)
    
    log "Creating GitHub issue for wave $wave_number coordination..."
    local issue_url=$(gh issue create --title "$issue_title" --body "$issue_body" --label "wave-coordination,wave-$wave_number")
    
    success "Wave coordination issue created: $issue_url"
    echo "Issue URL: $issue_url"
}

# Main command dispatcher
main() {
    case "${1:-help}" in
        "create")
            if [ $# -lt 3 ]; then
                error "Usage: $0 create <team_id> <wave_number> [job_id]"
                exit 1
            fi
            create_team_worktree "$2" "$3" "${4:-$(date +%Y%m%d-%H%M%S)}"
            ;;
        "list")
            list_worktrees "${2:-}"
            ;;
        "cleanup")
            cleanup_worktrees "${2:-}" "${3:-false}"
            ;;
        "issue")
            if [ $# -lt 3 ]; then
                error "Usage: $0 issue <wave_number> <job_id>"
                exit 1
            fi
            create_wave_issue "$2" "$3"
            ;;
        "help"|*)
            echo "Git Worktree Manager for Wave-Based Execution"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  create <team_id> <wave_number> [job_id]  Create team worktree"
            echo "  list [job_id]                            List worktrees"
            echo "  cleanup <job_id>                         Clean up worktrees for job"
            echo "  cleanup --all --force                    Clean up all worktrees"
            echo "  issue <wave_number> <job_id>             Create GitHub coordination issue"
            echo "  help                                     Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 create alpha 1 job-20250812          # Create worktree for team alpha, wave 1"
            echo "  $0 list job-20250812                     # List worktrees for specific job"
            echo "  $0 issue 1 job-20250812                 # Create GitHub issue for wave 1"
            echo "  $0 cleanup job-20250812                  # Clean up all worktrees for job"
            ;;
    esac
}

main "$@"