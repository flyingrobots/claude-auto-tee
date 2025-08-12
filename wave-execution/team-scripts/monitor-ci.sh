#!/usr/bin/env bash
# Monitor CI status for a PR until all checks pass
# Usage: ./monitor-ci.sh {pr-number} [check-interval]
#
# This script:
# 1. Continuously monitors CI check status
# 2. Reports real-time status updates
# 3. Updates GitHub issue with CI progress
# 4. Exits when all checks pass or fail permanently

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

status() {
    echo -e "${PURPLE}[STATUS] $1${NC}"
}

# Check arguments
if [ $# -lt 1 ]; then
    error "Usage: $0 {pr-number} [check-interval-seconds]"
    echo ""
    echo "Examples:"
    echo "  $0 123                # Monitor PR #123 with default 30s interval"
    echo "  $0 123 60             # Monitor PR #123 with 60s interval"
    echo ""
    echo "This will continuously monitor CI status until:"
    echo "- All checks pass (success exit)"
    echo "- Any check fails permanently (error exit)"
    echo "- User interrupts (Ctrl+C)"
    exit 1
fi

PR_NUMBER="$1"
CHECK_INTERVAL="${2:-30}"  # Default 30 seconds

# Validate PR number is numeric
if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
    error "PR number must be numeric: $PR_NUMBER"
    exit 1
fi

# Load team metadata if available
TEAM_ID=""
WAVE_NUMBER=""
JOB_ID=""
TASK_ID=""
ISSUE_NUMBER=""

if [ -f ".team-metadata.json" ]; then
    TEAM_ID=$(grep '"team_id"' .team-metadata.json | sed 's/.*"team_id":[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || echo "")
    WAVE_NUMBER=$(grep '"wave_number"' .team-metadata.json | sed 's/.*"wave_number":[[:space:]]*\([0-9]*\).*/\1/' 2>/dev/null || echo "")
    JOB_ID=$(grep '"job_id"' .team-metadata.json | sed 's/.*"job_id":[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || echo "")
fi

if [ -f ".task-progress.json" ]; then
    TASK_ID=$(grep '"task_id"' .task-progress.json | sed 's/.*"task_id":[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || echo "")
    ISSUE_NUMBER=$(grep '"issue_number"' .task-progress.json | sed 's/.*"issue_number":[[:space:]]*\([0-9]*\).*/\1/' 2>/dev/null || echo "")
fi

echo "🔍 Monitoring CI Status for PR #$PR_NUMBER"
echo "=========================================="
if [ -n "$TEAM_ID" ]; then
    echo "👥 Team: $TEAM_ID"
fi
if [ -n "$TASK_ID" ]; then
    echo "🎯 Task: $TASK_ID"
fi
if [ -n "$WAVE_NUMBER" ]; then
    echo "🌊 Wave: $WAVE_NUMBER"
fi
echo "⏱️  Check Interval: ${CHECK_INTERVAL}s"
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

# Verify PR exists
if ! gh pr view "$PR_NUMBER" >/dev/null 2>&1; then
    error "PR #$PR_NUMBER not found or not accessible"
    exit 1
fi

PR_URL=$(gh pr view "$PR_NUMBER" --json url --jq '.url' 2>/dev/null || echo "")
PR_TITLE=$(gh pr view "$PR_NUMBER" --json title --jq '.title' 2>/dev/null || echo "")

log "Monitoring PR: $PR_TITLE"
log "URL: $PR_URL"
echo ""

# Track previous status to detect changes
PREV_OVERALL_STATUS=""
PREV_CHECK_COUNT=0
LAST_ISSUE_UPDATE=""
CHECK_COUNT=0

# Cleanup function
cleanup() {
    echo ""
    log "Monitoring stopped"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Function to update GitHub issue with CI status
update_issue_if_needed() {
    local overall_status="$1"
    local check_summary="$2"
    local current_time="$3"
    
    # Only update issue if we have issue number and status changed significantly
    if [ -n "$ISSUE_NUMBER" ] && [ -n "$overall_status" ]; then
        # Update every 5 checks or on significant status change
        local should_update=false
        
        if [ "$overall_status" != "$PREV_OVERALL_STATUS" ] || 
           [ -z "$LAST_ISSUE_UPDATE" ] || 
           [ $((CHECK_COUNT % 5)) -eq 0 ]; then
            should_update=true
        fi
        
        if [ "$should_update" = true ]; then
            local status_emoji="⏳"
            case "$overall_status" in
                "SUCCESS") status_emoji="✅" ;;
                "FAILURE"|"ERROR") status_emoji="❌" ;;
                "PENDING"|"IN_PROGRESS") status_emoji="🔄" ;;
            esac
            
            local comment_body="$status_emoji **CI Status Update**

**PR:** #$PR_NUMBER  
**Overall Status:** $overall_status  
**Checked:** $current_time  
**Monitoring:** Check ${CHECK_COUNT}

$check_summary

*Automated CI monitoring by Team $TEAM_ID*"

            if gh issue comment "$ISSUE_NUMBER" --body "$comment_body" >/dev/null 2>&1; then
                LAST_ISSUE_UPDATE="$current_time"
            fi
        fi
    fi
}

# Main monitoring loop
while true; do
    CHECK_COUNT=$((CHECK_COUNT + 1))
    CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    
    status "Check #$CHECK_COUNT at $CURRENT_TIME"
    
    # Get CI status
    CI_CHECKS=$(gh pr checks "$PR_NUMBER" --json name,status,conclusion,startedAt,completedAt,detailsUrl 2>/dev/null || echo "[]")
    
    if [ "$CI_CHECKS" = "[]" ] || [ "$CI_CHECKS" = "null" ]; then
        warn "No CI checks found for PR #$PR_NUMBER"
        echo "This could mean:"
        echo "1. CI is not configured for this repository"
        echo "2. Checks haven't started yet"
        echo "3. PR was just created and checks are queuing"
        echo ""
        echo "Waiting ${CHECK_INTERVAL}s for checks to appear..."
        sleep "$CHECK_INTERVAL"
        continue
    fi
    
    # Parse check results
    TOTAL_CHECKS=$(echo "$CI_CHECKS" | jq '. | length')
    PENDING_CHECKS=$(echo "$CI_CHECKS" | jq '[.[] | select(.status == "in_progress" or .status == "queued" or .status == "pending")] | length')
    PASSED_CHECKS=$(echo "$CI_CHECKS" | jq '[.[] | select(.conclusion == "success")] | length')
    FAILED_CHECKS=$(echo "$CI_CHECKS" | jq '[.[] | select(.conclusion == "failure" or .conclusion == "error")] | length')
    CANCELLED_CHECKS=$(echo "$CI_CHECKS" | jq '[.[] | select(.conclusion == "cancelled" or .conclusion == "skipped")] | length')
    
    # Determine overall status
    OVERALL_STATUS="PENDING"
    if [ "$PENDING_CHECKS" -eq 0 ]; then
        if [ "$FAILED_CHECKS" -gt 0 ]; then
            OVERALL_STATUS="FAILURE"
        elif [ "$PASSED_CHECKS" -eq "$TOTAL_CHECKS" ]; then
            OVERALL_STATUS="SUCCESS"
        elif [ "$PASSED_CHECKS" -gt 0 ] && [ "$CANCELLED_CHECKS" -gt 0 ] && [ "$FAILED_CHECKS" -eq 0 ]; then
            OVERALL_STATUS="SUCCESS"  # Treat passed + cancelled as success
        else
            OVERALL_STATUS="UNKNOWN"
        fi
    fi
    
    # Display status summary
    echo "📊 CI Status Summary:"
    echo "   Total Checks: $TOTAL_CHECKS"
    echo "   ✅ Passed: $PASSED_CHECKS"
    echo "   ❌ Failed: $FAILED_CHECKS" 
    echo "   ⏳ Pending: $PENDING_CHECKS"
    echo "   ⏭️  Cancelled: $CANCELLED_CHECKS"
    echo "   🎯 Overall: $OVERALL_STATUS"
    echo ""
    
    # Show individual check details
    echo "📋 Individual Checks:"
    echo "$CI_CHECKS" | jq -r '.[] | "   \(.name): \(.status // "unknown") (\(.conclusion // "pending"))"' | while read -r line; do
        case "$line" in
            *"success"*) echo -e "   ✅ ${line/: */}: ${line/*: /}" ;;
            *"failure"*|*"error"*) echo -e "   ❌ ${line/: */}: ${line/*: /}" ;;
            *"cancelled"*|*"skipped"*) echo -e "   ⏭️  ${line/: */}: ${line/*: /}" ;;
            *) echo -e "   ⏳ ${line/: */}: ${line/*: /}" ;;
        esac
    done
    echo ""
    
    # Prepare check summary for issue updates
    CHECK_SUMMARY="**Check Details:**
$(echo "$CI_CHECKS" | jq -r '.[] | "- \(.name): \(.conclusion // .status // "pending")"')"
    
    # Update GitHub issue if needed
    update_issue_if_needed "$OVERALL_STATUS" "$CHECK_SUMMARY" "$CURRENT_TIME"
    
    # Check for completion conditions
    case "$OVERALL_STATUS" in
        "SUCCESS")
            success "🎉 All CI checks passed!"
            echo ""
            echo "✅ PR #$PR_NUMBER is ready for merge"
            echo "🔗 $PR_URL"
            echo ""
            echo "Next steps:"
            echo "1. Review the PR if code review is required"
            echo "2. Merge the PR when ready"
            echo "3. Run: ./complete-task.sh $TASK_ID"
            exit 0
            ;;
        "FAILURE")
            error "❌ CI checks failed!"
            echo ""
            echo "Failed checks need attention:"
            echo "$CI_CHECKS" | jq -r '.[] | select(.conclusion == "failure" or .conclusion == "error") | "- \(.name): \(.conclusion) (\(.detailsUrl // "no details"))"'
            echo ""
            echo "🔗 PR: $PR_URL"
            echo ""
            echo "Next steps:"
            echo "1. Review failed check details"
            echo "2. Fix issues and push new commits"
            echo "3. Re-run this monitor after fixes"
            exit 1
            ;;
    esac
    
    # Show progress if status changed
    if [ "$OVERALL_STATUS" != "$PREV_OVERALL_STATUS" ] || [ "$TOTAL_CHECKS" -ne "$PREV_CHECK_COUNT" ]; then
        if [ "$PENDING_CHECKS" -gt 0 ]; then
            log "Status changed: $PREV_OVERALL_STATUS → $OVERALL_STATUS ($PASSED_CHECKS/$TOTAL_CHECKS passed)"
        fi
    fi
    
    # Store previous state
    PREV_OVERALL_STATUS="$OVERALL_STATUS"
    PREV_CHECK_COUNT="$TOTAL_CHECKS"
    
    # Wait before next check
    if [ "$PENDING_CHECKS" -gt 0 ]; then
        log "Waiting ${CHECK_INTERVAL}s for next check... (Ctrl+C to stop)"
        sleep "$CHECK_INTERVAL"
        echo ""
    else
        # If no pending checks but not success/failure, wait a bit and recheck
        log "No pending checks but status unclear, waiting ${CHECK_INTERVAL}s..."
        sleep "$CHECK_INTERVAL"
        echo ""
    fi
done