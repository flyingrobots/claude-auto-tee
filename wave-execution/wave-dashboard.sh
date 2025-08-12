#!/usr/bin/env bash
# Wave Dashboard - Real-time monitoring and progress visibility
# Provides comprehensive visual status of wave execution across all teams

set -euo pipefail

# Configuration
SYNC_BASE_DIR="${SYNC_BASE_DIR:-$HOME/claude-wave-workstream-sync}"
MAIN_REPO_DIR="${MAIN_REPO_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
DASHBOARD_REFRESH="${DASHBOARD_REFRESH:-10}"

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'
BOLD='\033[1m'

# Unicode symbols
CHECKMARK="✅"
CROSS="❌"
WARNING="⚠️"
CLOCK="⏳"
ROCKET="🚀"
WAVE="🌊"
TEAM="👥"
PR="🔗"
GEAR="⚙️"

# Clear screen and position cursor
clear_screen() {
    clear
    tput cup 0 0
}

# Get terminal dimensions
get_terminal_size() {
    COLS=$(tput cols)
    ROWS=$(tput lines)
}

# Draw a horizontal line
draw_line() {
    local char="${1:-=}"
    local width="${2:-$COLS}"
    printf "%*s\n" "$width" | tr ' ' "$char"
}

# Center text in terminal
center_text() {
    local text="$1"
    local width="${2:-$COLS}"
    local padding=$(( (width - ${#text}) / 2 ))
    printf "%*s%s\n" "$padding" "" "$text"
}

# Format duration from seconds
format_duration() {
    local seconds="$1"
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if [ $hours -gt 0 ]; then
        printf "%02d:%02d:%02d" "$hours" "$minutes" "$secs"
    else
        printf "%02d:%02d" "$minutes" "$secs"
    fi
}

# Get time since file creation
get_time_since() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "N/A"
        return
    fi
    
    local file_time
    if command -v stat >/dev/null 2>&1; then
        # macOS
        file_time=$(stat -f %m "$file" 2>/dev/null) || file_time=$(stat -c %Y "$file" 2>/dev/null) || file_time=""
    else
        # Linux
        file_time=$(stat -c %Y "$file" 2>/dev/null) || file_time=""
    fi
    
    if [ -n "$file_time" ]; then
        local now=$(date +%s)
        local diff=$((now - file_time))
        format_duration "$diff"
    else
        echo "N/A"
    fi
}

# Get wave configuration
get_wave_config() {
    local wave_number="$1"
    
    if [ ! -f "$MAIN_REPO_DIR/TASKS_WAVES.json" ]; then
        echo "null"
        return
    fi
    
    jq -r ".waves.Wave_$wave_number // null" "$MAIN_REPO_DIR/TASKS_WAVES.json"
}

# Get total waves
get_total_waves() {
    if [ ! -f "$MAIN_REPO_DIR/TASKS_WAVES.json" ]; then
        echo "3"
        return
    fi
    
    jq -r '.metadata.total_waves // 3' "$MAIN_REPO_DIR/TASKS_WAVES.json"
}

# Get expected teams for a wave
get_expected_teams() {
    local job_id="$1"
    local wave_number="$2"
    
    local assignment_dir="$SYNC_BASE_DIR/$job_id/assignments"
    if [ ! -d "$assignment_dir" ]; then
        echo ""
        return
    fi
    
    local teams=()
    for task_file in "$assignment_dir"/*-wave-$wave_number-tasklist.md; do
        if [ -f "$task_file" ]; then
            local filename=$(basename "$task_file")
            local team_name="${filename%-wave-$wave_number-tasklist.md}"
            teams+=("$team_name")
        fi
    done
    
    local IFS=','
    echo "${teams[*]}"
}

# Get team PR status
get_team_pr_status() {
    local team_id="$1"
    local job_id="$2"
    local wave_number="$3"
    
    # Try to find team worktree
    local worktree_pattern="*$team_id-wave-$wave_number*"
    local worktree_dir=""
    
    # Look for worktree in common locations
    for base_dir in "$HOME/claude-wave-worktrees"/*; do
        if [ -d "$base_dir" ]; then
            for team_dir in "$base_dir"/$worktree_pattern; do
                if [ -d "$team_dir" ] && [ -f "$team_dir/.team-metadata.json" ]; then
                    worktree_dir="$team_dir"
                    break 2
                fi
            done
        fi
    done
    
    if [ -z "$worktree_dir" ]; then
        echo "NO_WORKTREE"
        return
    fi
    
    # Check if GitHub CLI is available
    if ! command -v gh &> /dev/null; then
        echo "NO_GH_CLI"
        return
    fi
    
    # Get PR status from worktree
    (
        cd "$worktree_dir"
        if ! gh auth status >/dev/null 2>&1; then
            echo "NO_AUTH"
            return
        fi
        
        local pr_info=$(gh pr status --json state,number 2>/dev/null || echo "{}")
        local current_branch_pr=$(echo "$pr_info" | jq -r ".currentBranch // {}")
        
        if [ "$current_branch_pr" = "{}" ] || [ "$current_branch_pr" = "null" ]; then
            echo "NO_PR"
        else
            local pr_state=$(echo "$current_branch_pr" | jq -r '.state')
            local pr_number=$(echo "$current_branch_pr" | jq -r '.number')
            echo "${pr_state}:${pr_number}"
        fi
    )
}

# Generate wave status line
generate_wave_status() {
    local job_id="$1"
    local wave_number="$2"
    local width="$3"
    
    local wave_dir="$SYNC_BASE_DIR/$job_id/wave-$wave_number"
    local expected_teams=$(get_expected_teams "$job_id" "$wave_number")
    
    if [ ! -d "$wave_dir" ]; then
        printf "%-${width}s" "$WAVE Wave $wave_number: NOT INITIALIZED"
        return
    fi
    
    if [ -z "$expected_teams" ]; then
        printf "%-${width}s" "$WAVE Wave $wave_number: NO TEAMS ASSIGNED"
        return
    fi
    
    # Count ready teams
    local ready_count=0
    local total_teams=0
    local team_status=""
    
    IFS=',' read -ra TEAMS <<< "$expected_teams"
    for team in "${TEAMS[@]}"; do
        total_teams=$((total_teams + 1))
        local ready_file="$wave_dir/$team.ready.txt"
        
        if [ -f "$ready_file" ]; then
            ready_count=$((ready_count + 1))
            team_status="$team_status$CHECKMARK"
        else
            # Check PR status
            local pr_status=$(get_team_pr_status "$team" "$job_id" "$wave_number")
            case "$pr_status" in
                "MERGED:"*)
                    team_status="$team_status$WARNING"  # PR merged but no ready file
                    ;;
                "OPEN:"*)
                    team_status="$team_status$CLOCK"    # PR open
                    ;;
                "NO_PR"|"NO_WORKTREE"|"NO_GH_CLI"|"NO_AUTH")
                    team_status="$team_status$GEAR"     # Working
                    ;;
                *)
                    team_status="$team_status$CROSS"    # Unknown/error
                    ;;
            esac
        fi
    done
    
    local status_text="$WAVE Wave $wave_number: $ready_count/$total_teams ready [$team_status]"
    
    # Check if wave is complete
    if [ $ready_count -eq $total_teams ] && [ $total_teams -gt 0 ]; then
        local next_wave=$((wave_number + 1))
        local transition_file="$SYNC_BASE_DIR/$job_id/wave-$next_wave/.transition-notification.md"
        if [ -f "$transition_file" ] || [ $wave_number -eq $(get_total_waves) ]; then
            status_text="$CHECKMARK Wave $wave_number: COMPLETE ($ready_count/$total_teams) [$team_status]"
        else
            status_text="$ROCKET Wave $wave_number: READY FOR TRANSITION ($ready_count/$total_teams) [$team_status]"
        fi
    fi
    
    printf "%-${width}s" "$status_text"
}

# Generate team detail view
generate_team_details() {
    local job_id="$1"
    local wave_number="$2"
    local width="$3"
    
    local expected_teams=$(get_expected_teams "$job_id" "$wave_number")
    
    if [ -z "$expected_teams" ]; then
        printf "%-${width}s\n" "  No teams assigned to wave $wave_number"
        return
    fi
    
    IFS=',' read -ra TEAMS <<< "$expected_teams"
    for team in "${TEAMS[@]}"; do
        local wave_dir="$SYNC_BASE_DIR/$job_id/wave-$wave_number"
        local ready_file="$wave_dir/$team.ready.txt"
        local team_line="  $TEAM $team: "
        
        if [ -f "$ready_file" ]; then
            local ready_since=$(get_time_since "$ready_file")
            local pr_number=$(grep "PR Number:" "$ready_file" | cut -d'#' -f2 | tr -d ' ' 2>/dev/null || echo "N/A")
            team_line="$team_line${GREEN}READY${NC} (${ready_since} ago, PR #${pr_number})"
        else
            local pr_status=$(get_team_pr_status "$team" "$job_id" "$wave_number")
            case "$pr_status" in
                "MERGED:"*)
                    local pr_num="${pr_status#*:}"
                    team_line="$team_line${YELLOW}PR MERGED${NC} (PR #${pr_num}) - Ready file pending"
                    ;;
                "OPEN:"*)
                    local pr_num="${pr_status#*:}"
                    team_line="$team_line${BLUE}PR OPEN${NC} (PR #${pr_num}) - Awaiting merge"
                    ;;
                "CLOSED:"*)
                    local pr_num="${pr_status#*:}"
                    team_line="$team_line${RED}PR CLOSED${NC} (PR #${pr_num}) - Needs attention"
                    ;;
                "NO_PR")
                    team_line="$team_line${GRAY}WORKING${NC} - No PR created yet"
                    ;;
                "NO_WORKTREE")
                    team_line="$team_line${RED}NO WORKTREE${NC} - Setup needed"
                    ;;
                *)
                    team_line="$team_line${GRAY}STATUS UNKNOWN${NC}"
                    ;;
            esac
        fi
        
        printf "%-${width}s\n" "$team_line"
    done
}

# Main dashboard display
display_dashboard() {
    local job_id="$1"
    local detailed="${2:-false}"
    
    clear_screen
    get_terminal_size
    
    # Header
    echo -e "${BOLD}${BLUE}"
    center_text "CLAUDE AUTO-TEE WAVE EXECUTION DASHBOARD"
    echo -e "${NC}"
    draw_line "=" "$COLS"
    
    # Job info
    local job_start_time="N/A"
    local job_metadata="$SYNC_BASE_DIR/$job_id/.job-metadata.json"
    if [ -f "$job_metadata" ]; then
        job_start_time=$(jq -r '.initialized_at // "N/A"' "$job_metadata")
    fi
    
    echo -e "${BOLD}Job ID:${NC} $job_id"
    echo -e "${BOLD}Started:${NC} $job_start_time"
    echo -e "${BOLD}Updated:${NC} $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    # Emergency stop check
    if [ -f "$SYNC_BASE_DIR/$job_id/.EMERGENCY_STOP" ]; then
        echo ""
        echo -e "${RED}${BOLD}⚠️  EMERGENCY STOP ACTIVE ⚠️${NC}"
        echo -e "${RED}All wave transitions are halted${NC}"
        local stop_reason=$(grep "Stop Reason:" "$SYNC_BASE_DIR/$job_id/.EMERGENCY_STOP" | cut -d':' -f2- | sed 's/^ *//')
        echo -e "${RED}Reason: $stop_reason${NC}"
    fi
    
    echo ""
    draw_line "-" "$COLS"
    
    # Wave status overview
    local total_waves=$(get_total_waves)
    echo -e "${BOLD}Wave Execution Status${NC}"
    echo ""
    
    local completed_waves=0
    local active_wave=0
    
    for wave in $(seq 1 $total_waves); do
        local wave_status_line=$(generate_wave_status "$job_id" "$wave" "$((COLS - 2))")
        echo "$wave_status_line"
        
        # Determine active wave
        local expected_teams=$(get_expected_teams "$job_id" "$wave")
        if [ -n "$expected_teams" ]; then
            local wave_dir="$SYNC_BASE_DIR/$job_id/wave-$wave"
            local ready_count=0
            local total_teams=0
            
            IFS=',' read -ra TEAMS <<< "$expected_teams"
            for team in "${TEAMS[@]}"; do
                total_teams=$((total_teams + 1))
                if [ -f "$wave_dir/$team.ready.txt" ]; then
                    ready_count=$((ready_count + 1))
                fi
            done
            
            if [ $ready_count -eq $total_teams ] && [ $total_teams -gt 0 ]; then
                completed_waves=$((completed_waves + 1))
            elif [ $ready_count -gt 0 ] || [ $active_wave -eq 0 ]; then
                active_wave=$wave
            fi
        fi
    done
    
    echo ""
    
    # Project progress
    local progress_percent=$((completed_waves * 100 / total_waves))
    echo -e "${BOLD}Overall Progress:${NC} $completed_waves/$total_waves waves complete (${progress_percent}%)"
    
    if [ $completed_waves -eq $total_waves ]; then
        echo -e "${GREEN}${BOLD}🎉 PROJECT COMPLETE! 🎉${NC}"
    elif [ $active_wave -gt 0 ]; then
        echo -e "${BOLD}Active Wave:${NC} $active_wave"
    fi
    
    # Detailed view
    if [ "$detailed" = "true" ]; then
        echo ""
        draw_line "-" "$COLS"
        echo -e "${BOLD}Team Details${NC}"
        echo ""
        
        for wave in $(seq 1 $total_waves); do
            local expected_teams=$(get_expected_teams "$job_id" "$wave")
            if [ -n "$expected_teams" ]; then
                echo -e "${BOLD}Wave $wave Teams:${NC}"
                generate_team_details "$job_id" "$wave" "$((COLS - 2))"
                echo ""
            fi
        done
    fi
    
    # Footer
    draw_line "-" "$COLS"
    echo -e "${GRAY}Dashboard auto-refreshes every ${DASHBOARD_REFRESH}s | Press Ctrl+C to exit | Add --detailed for team view${NC}"
    
    # Show shortcuts
    echo -e "${GRAY}Commands: wave-sync-coordinator.sh status $job_id | wave-transition-manager.sh monitor $job_id${NC}"
}

# Live dashboard with auto-refresh
live_dashboard() {
    local job_id="$1"
    local detailed="${2:-false}"
    
    # Validate job exists
    if [ ! -d "$SYNC_BASE_DIR/$job_id" ]; then
        echo "Error: Job $job_id not found in $SYNC_BASE_DIR"
        echo "Available jobs:"
        ls -1 "$SYNC_BASE_DIR" 2>/dev/null || echo "  No jobs found"
        exit 1
    fi
    
    echo "Starting live dashboard for job: $job_id"
    echo "Press Ctrl+C to exit"
    sleep 2
    
    # Trap Ctrl+C for clean exit
    trap 'echo -e "\n\nDashboard stopped."; exit 0' INT
    
    while true; do
        display_dashboard "$job_id" "$detailed"
        sleep "$DASHBOARD_REFRESH"
    done
}

# Generate static HTML dashboard
generate_html_dashboard() {
    local job_id="$1"
    local output_file="${2:-$job_id-dashboard.html}"
    
    local html_content=$(cat << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Claude Auto-Tee Wave Dashboard</title>
    <style>
        body { font-family: 'Monaco', 'Consolas', monospace; background: #1e1e1e; color: #d4d4d4; margin: 20px; }
        .header { text-align: center; border-bottom: 2px solid #444; padding-bottom: 10px; margin-bottom: 20px; }
        .job-info { background: #2d2d30; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .wave-status { background: #252526; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .wave-item { margin: 10px 0; padding: 10px; border-left: 4px solid #007acc; background: #1e1e1e; }
        .wave-complete { border-left-color: #4ec9b0; }
        .wave-active { border-left-color: #ffcc02; }
        .team-details { background: #252526; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .team-item { margin: 5px 0; padding: 8px; background: #1e1e1e; border-radius: 3px; }
        .status-ready { color: #4ec9b0; }
        .status-working { color: #ffcc02; }
        .status-error { color: #f14c4c; }
        .footer { text-align: center; color: #808080; margin-top: 20px; border-top: 1px solid #444; padding-top: 10px; }
        .refresh-time { text-align: right; color: #808080; font-size: 0.9em; }
    </style>
    <script>
        function updateTime() {
            document.getElementById('current-time').textContent = new Date().toISOString();
        }
        setInterval(updateTime, 1000);
        window.onload = updateTime;
    </script>
</head>
<body>
    <div class="header">
        <h1>🌊 Claude Auto-Tee Wave Execution Dashboard</h1>
        <div class="refresh-time">Last updated: <span id="current-time"></span></div>
    </div>
    
    <div class="job-info">
        <h2>Job Information</h2>
        <p><strong>Job ID:</strong> JOB_ID_PLACEHOLDER</p>
        <p><strong>Started:</strong> JOB_START_PLACEHOLDER</p>
        <p><strong>Total Waves:</strong> TOTAL_WAVES_PLACEHOLDER</p>
        <p><strong>Completed Waves:</strong> COMPLETED_WAVES_PLACEHOLDER</p>
    </div>
    
    <div class="wave-status">
        <h2>Wave Status</h2>
        WAVE_STATUS_PLACEHOLDER
    </div>
    
    <div class="team-details">
        <h2>Team Details</h2>
        TEAM_DETAILS_PLACEHOLDER
    </div>
    
    <div class="footer">
        <p>Generated by Claude Auto-Tee Wave Dashboard</p>
        <p>Refresh page for latest status</p>
    </div>
</body>
</html>
EOF
)
    
    # Generate wave status HTML
    local wave_status_html=""
    local team_details_html=""
    local total_waves=$(get_total_waves)
    local completed_waves=0
    
    for wave in $(seq 1 $total_waves); do
        local expected_teams=$(get_expected_teams "$job_id" "$wave")
        local wave_dir="$SYNC_BASE_DIR/$job_id/wave-$wave"
        
        if [ ! -d "$wave_dir" ] || [ -z "$expected_teams" ]; then
            wave_status_html="$wave_status_html<div class=\"wave-item\">Wave $wave: Not initialized</div>"
            continue
        fi
        
        local ready_count=0
        local total_teams=0
        
        IFS=',' read -ra TEAMS <<< "$expected_teams"
        for team in "${TEAMS[@]}"; do
            total_teams=$((total_teams + 1))
            if [ -f "$wave_dir/$team.ready.txt" ]; then
                ready_count=$((ready_count + 1))
            fi
        done
        
        local wave_class="wave-item"
        local wave_status="$ready_count/$total_teams ready"
        
        if [ $ready_count -eq $total_teams ] && [ $total_teams -gt 0 ]; then
            wave_class="wave-item wave-complete"
            wave_status="COMPLETE ($ready_count/$total_teams)"
            completed_waves=$((completed_waves + 1))
        elif [ $ready_count -gt 0 ]; then
            wave_class="wave-item wave-active"
            wave_status="IN PROGRESS ($ready_count/$total_teams)"
        fi
        
        wave_status_html="$wave_status_html<div class=\"$wave_class\">🌊 Wave $wave: $wave_status</div>"
        
        # Team details
        team_details_html="$team_details_html<h3>Wave $wave Teams</h3>"
        for team in "${TEAMS[@]}"; do
            local ready_file="$wave_dir/$team.ready.txt"
            local team_class="team-item"
            local team_status=""
            
            if [ -f "$ready_file" ]; then
                team_class="team-item"
                team_status="<span class=\"status-ready\">✅ READY</span>"
            else
                team_class="team-item"
                team_status="<span class=\"status-working\">⏳ WORKING</span>"
            fi
            
            team_details_html="$team_details_html<div class=\"$team_class\">👥 $team: $team_status</div>"
        done
    done
    
    # Get job start time
    local job_start_time="N/A"
    local job_metadata="$SYNC_BASE_DIR/$job_id/.job-metadata.json"
    if [ -f "$job_metadata" ]; then
        job_start_time=$(jq -r '.initialized_at // "N/A"' "$job_metadata")
    fi
    
    # Replace placeholders
    html_content="${html_content//JOB_ID_PLACEHOLDER/$job_id}"
    html_content="${html_content//JOB_START_PLACEHOLDER/$job_start_time}"
    html_content="${html_content//TOTAL_WAVES_PLACEHOLDER/$total_waves}"
    html_content="${html_content//COMPLETED_WAVES_PLACEHOLDER/$completed_waves}"
    html_content="${html_content//WAVE_STATUS_PLACEHOLDER/$wave_status_html}"
    html_content="${html_content//TEAM_DETAILS_PLACEHOLDER/$team_details_html}"
    
    echo "$html_content" > "$output_file"
    echo "HTML dashboard generated: $output_file"
}

# Main command dispatcher
main() {
    case "${1:-help}" in
        "live")
            if [ $# -lt 2 ]; then
                echo "Usage: $0 live <job_id> [--detailed]"
                exit 1
            fi
            live_dashboard "$2" "${3:-false}"
            ;;
        "show")
            if [ $# -lt 2 ]; then
                echo "Usage: $0 show <job_id> [--detailed]"
                exit 1
            fi
            display_dashboard "$2" "${3:-false}"
            ;;
        "html")
            if [ $# -lt 2 ]; then
                echo "Usage: $0 html <job_id> [output_file]"
                exit 1
            fi
            generate_html_dashboard "$2" "${3:-$2-dashboard.html}"
            ;;
        "help"|*)
            echo "Wave Dashboard - Real-time monitoring and progress visibility"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  live <job_id> [--detailed]          Live auto-refreshing dashboard"
            echo "  show <job_id> [--detailed]          Single snapshot view"
            echo "  html <job_id> [output_file]         Generate HTML dashboard"
            echo "  help                                Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 live job-20250812                # Live dashboard"
            echo "  $0 live job-20250812 --detailed     # Live with team details"
            echo "  $0 show job-20250812                # One-time snapshot"
            echo "  $0 html job-20250812 report.html    # Generate HTML report"
            echo ""
            echo "Features:"
            echo "  - Real-time wave and team status"
            echo "  - PR status integration"
            echo "  - Progress visualization"
            echo "  - Emergency stop detection"
            echo "  - HTML report generation"
            echo ""
            echo "Environment Variables:"
            echo "  DASHBOARD_REFRESH=10                # Refresh interval (seconds)"
            ;;
    esac
}

main "$@"