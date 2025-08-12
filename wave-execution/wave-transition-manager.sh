#!/usr/bin/env bash
# Wave Transition Manager - Automated sync detection and wave transitions
# Monitors filesystem sync and orchestrates wave transitions when all teams ready

set -euo pipefail

# Configuration
SYNC_BASE_DIR="${SYNC_BASE_DIR:-$HOME/claude-wave-workstream-sync}"
MAIN_REPO_DIR="${MAIN_REPO_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PROJECT_NAME="${PROJECT_NAME:-$(basename "$MAIN_REPO_DIR")}"
TRANSITION_LOG_DIR="${TRANSITION_LOG_DIR:-$HOME/.claude-wave-transitions}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    local msg="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${BLUE}[$timestamp] $msg${NC}" >&2
    echo "[$timestamp] $msg" >> "$TRANSITION_LOG_DIR/wave-transitions.log"
}

error() {
    local msg="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${RED}[ERROR $timestamp] $msg${NC}" >&2
    echo "[ERROR $timestamp] $msg" >> "$TRANSITION_LOG_DIR/wave-transitions.log"
}

success() {
    local msg="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${GREEN}[SUCCESS $timestamp] $msg${NC}" >&2
    echo "[SUCCESS $timestamp] $msg" >> "$TRANSITION_LOG_DIR/wave-transitions.log"
}

warn() {
    local msg="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${YELLOW}[WARNING $timestamp] $msg${NC}" >&2
    echo "[WARNING $timestamp] $msg" >> "$TRANSITION_LOG_DIR/wave-transitions.log"
}

# Initialize logging
init_logging() {
    mkdir -p "$TRANSITION_LOG_DIR"
    if [ ! -f "$TRANSITION_LOG_DIR/wave-transitions.log" ]; then
        echo "# Wave Transition Log - $(date)" > "$TRANSITION_LOG_DIR/wave-transitions.log"
    fi
}

# Get total waves from configuration
get_total_waves() {
    if [ ! -f "$MAIN_REPO_DIR/TASKS_WAVES.json" ]; then
        echo "3"  # Default fallback
        return
    fi
    
    jq -r '.metadata.total_waves // 3' "$MAIN_REPO_DIR/TASKS_WAVES.json"
}

# Get expected teams for a job/wave (from assignment files)
get_expected_teams() {
    local job_id="$1"
    local wave_number="$2"
    
    local assignment_dir="$SYNC_BASE_DIR/$job_id/assignments"
    if [ ! -d "$assignment_dir" ]; then
        warn "No assignment directory found for job $job_id"
        echo ""
        return
    fi
    
    # Extract team names from assignment files
    local teams=()
    for task_file in "$assignment_dir"/*-wave-$wave_number-tasklist.md; do
        if [ -f "$task_file" ]; then
            local filename=$(basename "$task_file")
            local team_name="${filename%-wave-$wave_number-tasklist.md}"
            teams+=("$team_name")
        fi
    done
    
    # Join array with commas
    local IFS=','
    echo "${teams[*]}"
}

# Check if wave sync is complete
check_wave_complete() {
    local job_id="$1"
    local wave_number="$2"
    local expected_teams="$3"
    
    local wave_dir="$SYNC_BASE_DIR/$job_id/wave-$wave_number"
    
    if [ ! -d "$wave_dir" ]; then
        return 1
    fi
    
    if [ -z "$expected_teams" ]; then
        warn "No expected teams specified for wave $wave_number validation"
        return 1
    fi
    
    # Check each expected team has ready file
    IFS=',' read -ra TEAMS <<< "$expected_teams"
    for team in "${TEAMS[@]}"; do
        local ready_file="$wave_dir/$team.ready.txt"
        if [ ! -f "$ready_file" ]; then
            return 1
        fi
        
        # Validate ready file integrity
        if ! grep -q "TEAM_WAVE_COMPLETION_CONFIRMATION" "$ready_file"; then
            warn "Invalid ready file format for team $team"
            return 1
        fi
        
        # Check PR merge status
        if ! grep -q "PR Status: MERGED" "$ready_file"; then
            warn "Team $team ready file indicates PR not merged"
            return 1
        fi
    done
    
    return 0
}

# Create wave transition notification
create_transition_notification() {
    local job_id="$1"
    local from_wave="$2"
    local to_wave="$3"
    local teams="$4"
    
    local transition_file="$SYNC_BASE_DIR/$job_id/wave-$to_wave/.transition-notification.md"
    
    cat > "$transition_file" << EOF
# Wave Transition Complete: $from_wave → $to_wave

**Job ID:** \`$job_id\`
**Transition:** Wave $from_wave → Wave $to_wave
**Completed At:** $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Teams Ready:** $teams

## Wave $from_wave Completion Summary

All teams have successfully completed wave $from_wave:

EOF
    
    IFS=',' read -ra TEAM_ARRAY <<< "$teams"
    for team in "${TEAM_ARRAY[@]}"; do
        local ready_file="$SYNC_BASE_DIR/$job_id/wave-$from_wave/$team.ready.txt"
        if [ -f "$ready_file" ]; then
            local completion_time=$(grep "Completed At:" "$ready_file" | cut -d' ' -f3-)
            local pr_number=$(grep "PR Number:" "$ready_file" | cut -d' ' -f3)
            
            echo "- ✅ **Team $team**" >> "$transition_file"
            echo "  - Completed: $completion_time" >> "$transition_file"
            echo "  - PR: $pr_number" >> "$transition_file"
            echo "" >> "$transition_file"
        fi
    done
    
    cat >> "$transition_file" << EOF

## Wave $to_wave Ready

Teams can now begin wave $to_wave work:

1. ✅ All wave $from_wave tasks completed and PRs merged
2. ✅ Sync verification complete
3. ✅ Wave $to_wave task assignments available
4. ✅ Team worktrees ready for wave $to_wave

## Next Steps for Teams

1. Update your worktrees to latest main branch
2. Review wave $to_wave task assignments
3. Begin wave $to_wave development work
4. Follow same completion protocol when ready

## Monitoring

Monitor wave $to_wave progress:
\`\`\`bash
wave-sync-coordinator.sh monitor $job_id $to_wave "$teams"
\`\`\`

---
*Generated by Wave Transition Manager at $(date)*
EOF
    
    success "Transition notification created: $transition_file"
}

# Update GitHub issue with transition status
update_github_issue() {
    local job_id="$1"
    local wave_number="$2"
    local status="$3"  # "complete" or "ready"
    
    if ! command -v gh &> /dev/null; then
        warn "GitHub CLI not available - skipping issue update"
        return
    fi
    
    local issue_title="Wave $wave_number Coordination - Job $job_id"
    
    # Find issue by title
    local issue_number=$(gh issue list --search "in:title \"$issue_title\"" --json number --jq '.[0].number' 2>/dev/null || echo "")
    
    if [ -z "$issue_number" ] || [ "$issue_number" = "null" ]; then
        warn "GitHub issue not found for wave $wave_number coordination"
        return
    fi
    
    local comment_body=""
    case "$status" in
        "complete")
            comment_body="🎉 **Wave $wave_number COMPLETE!**

All teams have completed their assigned tasks and merged their PRs.

**Transition Status:** ✅ Ready for Wave $((wave_number + 1))
**Verified At:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

All team ready files verified with PR merge confirmation.

---
*Automated update by Wave Transition Manager*"
            ;;
        "ready")
            comment_body="🚀 **Wave $((wave_number + 1)) READY TO START**

Wave $wave_number sync complete. Teams can now begin wave $((wave_number + 1)) work.

**Next Wave:** $((wave_number + 1))
**Started At:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

Teams should update their worktrees and review new task assignments.

---
*Automated update by Wave Transition Manager*"
            ;;
    esac
    
    if [ -n "$comment_body" ]; then
        log "Updating GitHub issue #$issue_number with $status status"
        gh issue comment "$issue_number" --body "$comment_body" || warn "Failed to update GitHub issue"
    fi
}

# Execute wave transition
execute_wave_transition() {
    local job_id="$1"
    local current_wave="$2"
    local expected_teams="$3"
    
    local next_wave=$((current_wave + 1))
    local total_waves=$(get_total_waves)
    
    log "Executing wave transition: $current_wave → $next_wave"
    
    # Validate current wave completion
    if ! check_wave_complete "$job_id" "$current_wave" "$expected_teams"; then
        error "Wave $current_wave not complete - cannot transition"
        return 1
    fi
    
    success "Wave $current_wave verified complete for all teams: $expected_teams"
    
    # Create transition notification
    create_transition_notification "$job_id" "$current_wave" "$next_wave" "$expected_teams"
    
    # Update GitHub issues
    update_github_issue "$job_id" "$current_wave" "complete"
    
    if [ $next_wave -le $total_waves ]; then
        update_github_issue "$job_id" "$next_wave" "ready"
        success "Wave $next_wave is ready to begin"
        
        # Create next wave GitHub issue if it doesn't exist
        local next_issue_title="Wave $next_wave Coordination - Job $job_id"
        local existing_issue=$(gh issue list --search "in:title \"$next_issue_title\"" --json number --jq '.[0].number' 2>/dev/null || echo "")
        
        if [ -z "$existing_issue" ] || [ "$existing_issue" = "null" ]; then
            log "Creating GitHub issue for wave $next_wave"
            ./git-worktree-manager.sh issue "$next_wave" "$job_id" || warn "Failed to create wave $next_wave issue"
        fi
    else
        success "🎉 ALL WAVES COMPLETE! Project finished successfully."
        
        # Create final completion notification
        cat > "$SYNC_BASE_DIR/$job_id/.project-complete.md" << EOF
# 🎉 Project Complete!

**Job ID:** \`$job_id\`
**Completed:** $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Total Waves:** $total_waves
**Final Wave:** $current_wave

## Summary

All $total_waves waves have been completed successfully:

EOF
        
        for wave in $(seq 1 $current_wave); do
            echo "- ✅ Wave $wave: Complete" >> "$SYNC_BASE_DIR/$job_id/.project-complete.md"
        done
        
        cat >> "$SYNC_BASE_DIR/$job_id/.project-complete.md" << EOF

## Teams

All teams have successfully contributed:
$expected_teams

## Next Steps

1. ✅ Final integration testing
2. ✅ Release preparation
3. ✅ Documentation finalization
4. ✅ Project delivery

Congratulations on completing the wave-based execution!

---
*Generated by Wave Transition Manager*
EOF
    fi
    
    return 0
}

# Monitor multiple waves for transitions
monitor_wave_transitions() {
    local job_id="$1"
    local check_interval="${2:-60}"
    local total_waves=$(get_total_waves)
    
    log "Starting wave transition monitor for job $job_id"
    echo "🔄 Checking every $check_interval seconds"
    echo "🌊 Total waves: $total_waves"
    echo "🛑 Press Ctrl+C to stop monitoring"
    echo ""
    
    local iteration=0
    while true; do
        iteration=$((iteration + 1))
        echo "🔍 Transition Check #$iteration - $(date '+%H:%M:%S')"
        echo "============================================="
        
        local transitions_occurred=false
        
        # Check each wave for potential transitions
        for wave in $(seq 1 $((total_waves - 1))); do
            local expected_teams=$(get_expected_teams "$job_id" "$wave")
            
            if [ -n "$expected_teams" ]; then
                echo "🌊 Checking wave $wave completion..."
                
                if check_wave_complete "$job_id" "$wave" "$expected_teams"; then
                    # Check if we've already transitioned this wave
                    local transition_file="$SYNC_BASE_DIR/$job_id/wave-$((wave + 1))/.transition-notification.md"
                    
                    if [ ! -f "$transition_file" ]; then
                        echo "🚀 Wave $wave ready for transition!"
                        
                        if execute_wave_transition "$job_id" "$wave" "$expected_teams"; then
                            success "✅ Wave $wave → $((wave + 1)) transition complete"
                            transitions_occurred=true
                        else
                            error "❌ Wave $wave transition failed"
                        fi
                    else
                        echo "✅ Wave $wave already transitioned"
                    fi
                else
                    echo "⏳ Wave $wave not yet complete (teams: $expected_teams)"
                fi
            else
                echo "⚠️  No team assignments found for wave $wave"
            fi
            echo ""
        done
        
        # Check if final wave is complete
        local final_expected_teams=$(get_expected_teams "$job_id" "$total_waves")
        if [ -n "$final_expected_teams" ] && check_wave_complete "$job_id" "$total_waves" "$final_expected_teams"; then
            if [ ! -f "$SYNC_BASE_DIR/$job_id/.project-complete.md" ]; then
                execute_wave_transition "$job_id" "$total_waves" "$final_expected_teams"
                echo "🎉 PROJECT COMPLETE! All waves finished."
                break
            fi
        fi
        
        if [ "$transitions_occurred" = "true" ]; then
            echo "🔄 Transitions occurred - rechecking immediately..."
            continue
        fi
        
        echo "⏳ Next check in $check_interval seconds..."
        echo ""
        sleep "$check_interval"
    done
}

# Generate transition status report
generate_status_report() {
    local job_id="$1"
    local total_waves=$(get_total_waves)
    
    echo "📊 Wave Transition Status Report"
    echo "================================="
    echo "🆔 Job ID: $job_id"
    echo "📅 Report Time: $(date -u +%Y-%m-%dT%H:%M:%SZ')"
    echo "🌊 Total Waves: $total_waves"
    echo ""
    
    for wave in $(seq 1 $total_waves); do
        echo "🌊 Wave $wave Status"
        echo "-------------------"
        
        local expected_teams=$(get_expected_teams "$job_id" "$wave")
        local wave_dir="$SYNC_BASE_DIR/$job_id/wave-$wave"
        
        if [ ! -d "$wave_dir" ]; then
            echo "❌ Not initialized"
            echo ""
            continue
        fi
        
        if [ -n "$expected_teams" ]; then
            echo "👥 Expected teams: $expected_teams"
            
            if check_wave_complete "$job_id" "$wave" "$expected_teams"; then
                echo "✅ Status: COMPLETE"
                
                local transition_file="$SYNC_BASE_DIR/$job_id/wave-$((wave + 1))/.transition-notification.md"
                if [ -f "$transition_file" ] || [ $wave -eq $total_waves ]; then
                    echo "🚀 Transition: Complete"
                else
                    echo "⏳ Transition: Pending"
                fi
            else
                echo "⏳ Status: IN PROGRESS"
                
                # Show which teams are ready
                IFS=',' read -ra TEAMS <<< "$expected_teams"
                for team in "${TEAMS[@]}"; do
                    if [ -f "$wave_dir/$team.ready.txt" ]; then
                        echo "   ✅ $team: Ready"
                    else
                        echo "   ⏳ $team: Working"
                    fi
                done
            fi
        else
            echo "⚠️  No team assignments found"
        fi
        echo ""
    done
    
    # Overall project status
    if [ -f "$SYNC_BASE_DIR/$job_id/.project-complete.md" ]; then
        echo "🎉 PROJECT STATUS: COMPLETE"
    else
        echo "🚧 PROJECT STATUS: IN PROGRESS"
    fi
}

# Main command dispatcher
main() {
    init_logging
    
    case "${1:-help}" in
        "monitor")
            if [ $# -lt 2 ]; then
                error "Usage: $0 monitor <job_id> [check_interval]"
                exit 1
            fi
            monitor_wave_transitions "$2" "${3:-60}"
            ;;
        "transition")
            if [ $# -lt 4 ]; then
                error "Usage: $0 transition <job_id> <wave_number> <expected_teams>"
                exit 1
            fi
            execute_wave_transition "$2" "$3" "$4"
            ;;
        "status")
            if [ $# -lt 2 ]; then
                error "Usage: $0 status <job_id>"
                exit 1
            fi
            generate_status_report "$2"
            ;;
        "check")
            if [ $# -lt 4 ]; then
                error "Usage: $0 check <job_id> <wave_number> <expected_teams>"
                exit 1
            fi
            if check_wave_complete "$2" "$3" "$4"; then
                success "Wave $3 is complete for all teams: $4"
                exit 0
            else
                warn "Wave $3 is not yet complete"
                exit 1
            fi
            ;;
        "help"|*)
            echo "Wave Transition Manager - Automated sync detection and transitions"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  monitor <job_id> [interval]                    Monitor and auto-transition waves"
            echo "  transition <job_id> <wave> <teams>             Execute specific wave transition"
            echo "  status <job_id>                                Generate transition status report"
            echo "  check <job_id> <wave> <teams>                  Check if wave is complete"
            echo "  help                                           Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 monitor job-20250812 60                     # Monitor with 60s intervals"
            echo "  $0 transition job-20250812 1 'alpha,beta'      # Transition wave 1 to 2"
            echo "  $0 status job-20250812                         # Show overall status"
            echo "  $0 check job-20250812 1 'alpha,beta,gamma'     # Check wave 1 completion"
            echo ""
            echo "Features:"
            echo "  - Automatic wave transition detection"
            echo "  - GitHub issue integration and updates"
            echo "  - Comprehensive logging and audit trails"
            echo "  - Real-time monitoring with configurable intervals"
            echo "  - Safety validation before transitions"
            ;;
    esac
}

main "$@"