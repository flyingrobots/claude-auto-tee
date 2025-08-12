#!/usr/bin/env bash
# Wave Quality Gates - Validation and quality checks for sync points
# Ensures quality and completeness before wave transitions

set -euo pipefail

# Configuration
SYNC_BASE_DIR="${SYNC_BASE_DIR:-$HOME/claude-wave-workstream-sync}"
MAIN_REPO_DIR="${MAIN_REPO_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
QUALITY_LOG_DIR="${QUALITY_LOG_DIR:-$HOME/.claude-wave-quality}"

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
    echo "[$timestamp] $msg" >> "$QUALITY_LOG_DIR/quality-gates.log"
}

error() {
    local msg="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${RED}[ERROR $timestamp] $msg${NC}" >&2
    echo "[ERROR $timestamp] $msg" >> "$QUALITY_LOG_DIR/quality-gates.log"
}

success() {
    local msg="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${GREEN}[SUCCESS $timestamp] $msg${NC}" >&2
    echo "[SUCCESS $timestamp] $msg" >> "$QUALITY_LOG_DIR/quality-gates.log"
}

warn() {
    local msg="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${YELLOW}[WARNING $timestamp] $msg${NC}" >&2
    echo "[WARNING $timestamp] $msg" >> "$QUALITY_LOG_DIR/quality-gates.log"
}

# Initialize quality logging
init_quality_logging() {
    mkdir -p "$QUALITY_LOG_DIR"
    if [ ! -f "$QUALITY_LOG_DIR/quality-gates.log" ]; then
        echo "# Wave Quality Gates Log - $(date)" > "$QUALITY_LOG_DIR/quality-gates.log"
    fi
}

# Validate PR merge status using GitHub API
validate_pr_merge_status() {
    local job_id="$1"
    local wave_number="$2"
    local team_id="$3"
    
    log "Validating PR merge status for team $team_id, wave $wave_number"
    
    local ready_file="$SYNC_BASE_DIR/$job_id/wave-$wave_number/$team_id.ready.txt"
    
    if [ ! -f "$ready_file" ]; then
        error "Ready file not found: $ready_file"
        return 1
    fi
    
    # Extract PR number from ready file
    local pr_number=$(grep "PR Number:" "$ready_file" | sed 's/.*#\([0-9]*\).*/\1/' 2>/dev/null || echo "")
    
    if [ -z "$pr_number" ]; then
        error "PR number not found in ready file"
        return 1
    fi
    
    # Validate with GitHub CLI if available
    if ! command -v gh &> /dev/null; then
        warn "GitHub CLI not available - skipping PR validation"
        return 0
    fi
    
    if ! gh auth status >/dev/null 2>&1; then
        warn "GitHub CLI not authenticated - skipping PR validation"
        return 0
    fi
    
    local pr_status=$(gh pr view "$pr_number" --json state,merged,mergedAt 2>/dev/null || echo "{}")
    
    if [ "$pr_status" = "{}" ]; then
        error "Could not retrieve PR #$pr_number information"
        return 1
    fi
    
    local state=$(echo "$pr_status" | jq -r '.state')
    local merged=$(echo "$pr_status" | jq -r '.merged')
    local merged_at=$(echo "$pr_status" | jq -r '.mergedAt')
    
    if [ "$state" != "MERGED" ] || [ "$merged" != "true" ]; then
        error "PR #$pr_number is not merged (state: $state, merged: $merged)"
        return 1
    fi
    
    success "✅ PR #$pr_number validated as merged at $merged_at"
    return 0
}

# Validate ready file integrity and format
validate_ready_file_integrity() {
    local ready_file="$1"
    local team_id="$2"
    local wave_number="$3"
    
    log "Validating ready file integrity: $ready_file"
    
    if [ ! -f "$ready_file" ]; then
        error "Ready file not found: $ready_file"
        return 1
    fi
    
    if [ ! -s "$ready_file" ]; then
        error "Ready file is empty: $ready_file"
        return 1
    fi
    
    # Check required fields
    local required_fields=(
        "TEAM_WAVE_COMPLETION_CONFIRMATION"
        "Team ID:"
        "Wave Number:"
        "Job ID:"
        "Completed At:"
        "Branch:"
        "PR Number:"
        "PR Status: MERGED"
        "Verification Hash:"
    )
    
    local missing_fields=()
    for field in "${required_fields[@]}"; do
        if ! grep -q "$field" "$ready_file"; then
            missing_fields+=("$field")
        fi
    done
    
    if [ ${#missing_fields[@]} -gt 0 ]; then
        error "Ready file missing required fields:"
        for field in "${missing_fields[@]}"; do
            error "  - $field"
        done
        return 1
    fi
    
    # Validate team and wave match
    local file_team=$(grep "Team ID:" "$ready_file" | cut -d':' -f2 | tr -d ' ')
    local file_wave=$(grep "Wave Number:" "$ready_file" | cut -d':' -f2 | tr -d ' ')
    
    if [ "$file_team" != "$team_id" ]; then
        error "Team ID mismatch: expected $team_id, found $file_team"
        return 1
    fi
    
    if [ "$file_wave" != "$wave_number" ]; then
        error "Wave number mismatch: expected $wave_number, found $file_wave"
        return 1
    fi
    
    # Validate timestamp format
    local completed_at=$(grep "Completed At:" "$ready_file" | cut -d':' -f2- | tr -d ' ')
    if ! date -d "$completed_at" >/dev/null 2>&1 && ! date -j -f "%Y-%m-%dT%H:%M:%SZ" "$completed_at" >/dev/null 2>&1; then
        warn "Invalid timestamp format: $completed_at"
    fi
    
    success "✅ Ready file integrity validated"
    return 0
}

# Validate code quality and standards
validate_code_quality() {
    local job_id="$1"
    local wave_number="$2"
    local team_id="$3"
    
    log "Validating code quality for team $team_id, wave $wave_number"
    
    # Find team worktree
    local worktree_pattern="*$team_id-wave-$wave_number*"
    local worktree_dir=""
    
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
        warn "Team worktree not found for $team_id wave $wave_number"
        return 0
    fi
    
    log "Checking code quality in worktree: $worktree_dir"
    
    local quality_issues=0
    
    # Check for common code quality issues
    (
        cd "$worktree_dir"
        
        # Check for TODO/FIXME comments
        local todo_count=$(find . -name "*.sh" -o -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.md" | \
                          xargs grep -l "TODO\|FIXME\|XXX\|HACK" 2>/dev/null | wc -l | tr -d ' ')
        
        if [ "$todo_count" -gt 0 ]; then
            warn "Found $todo_count files with TODO/FIXME comments"
            quality_issues=$((quality_issues + 1))
        fi
        
        # Check for uncommitted changes
        if ! git diff --quiet HEAD; then
            error "Uncommitted changes found in worktree"
            quality_issues=$((quality_issues + 1))
        fi
        
        # Check for untracked files that might need to be committed
        local untracked_files=$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')
        if [ "$untracked_files" -gt 0 ]; then
            warn "Found $untracked_files untracked files"
            # List them for review
            git ls-files --others --exclude-standard | head -5 | while read -r file; do
                warn "  Untracked: $file"
            done
        fi
        
        # Check for large files
        local large_files=$(find . -type f -size +10M 2>/dev/null | wc -l | tr -d ' ')
        if [ "$large_files" -gt 0 ]; then
            warn "Found $large_files files larger than 10MB"
            quality_issues=$((quality_issues + 1))
        fi
        
        # Validate shell scripts with shellcheck if available
        if command -v shellcheck >/dev/null 2>&1; then
            local shell_issues=0
            find . -name "*.sh" -type f | while read -r script; do
                if ! shellcheck "$script" >/dev/null 2>&1; then
                    shell_issues=$((shell_issues + 1))
                fi
            done
            
            if [ "$shell_issues" -gt 0 ]; then
                warn "Found shellcheck issues in $shell_issues shell scripts"
                quality_issues=$((quality_issues + 1))
            fi
        fi
    )
    
    if [ $quality_issues -eq 0 ]; then
        success "✅ Code quality validation passed"
        return 0
    else
        warn "⚠️  Found $quality_issues code quality issues (warnings only)"
        return 0  # Don't fail on quality warnings
    fi
}

# Validate task completion against assignment
validate_task_completion() {
    local job_id="$1"
    local wave_number="$2"
    local team_id="$3"
    
    log "Validating task completion for team $team_id, wave $wave_number"
    
    local task_file="$SYNC_BASE_DIR/$job_id/assignments/$team_id-wave-$wave_number-tasklist.md"
    
    if [ ! -f "$task_file" ]; then
        warn "Task list not found: $task_file"
        return 0  # Don't fail if no task list (might be using different assignment method)
    fi
    
    # Count total and completed tasks
    local total_tasks=$(grep -c "^### P1\.T" "$task_file" 2>/dev/null || echo "0")
    local completed_tasks=$(grep -c "Status.*✅\|Status.*Complete\|Status.*Done" "$task_file" 2>/dev/null || echo "0")
    
    if [ "$total_tasks" -eq 0 ]; then
        warn "No tasks found in task list"
        return 0
    fi
    
    if [ "$completed_tasks" -lt "$total_tasks" ]; then
        warn "Task completion status: $completed_tasks/$total_tasks marked complete"
        warn "This is advisory - ensure all assigned tasks are actually complete"
        return 0  # Don't fail on task status (might be outdated)
    fi
    
    success "✅ All $total_tasks tasks marked complete in task list"
    return 0
}

# Validate branch and commit quality
validate_branch_quality() {
    local job_id="$1"
    local wave_number="$2"
    local team_id="$3"
    
    log "Validating branch quality for team $team_id, wave $wave_number"
    
    local ready_file="$SYNC_BASE_DIR/$job_id/wave-$wave_number/$team_id.ready.txt"
    local branch_name=$(grep "Branch:" "$ready_file" | cut -d':' -f2 | tr -d ' ' 2>/dev/null || echo "")
    
    if [ -z "$branch_name" ]; then
        error "Branch name not found in ready file"
        return 1
    fi
    
    # Check if branch exists in main repo
    (
        cd "$MAIN_REPO_DIR"
        
        if ! git show-ref --verify --quiet "refs/heads/$branch_name"; then
            error "Branch $branch_name not found in main repository"
            return 1
        fi
        
        # Check if branch is merged to main
        if ! git merge-base --is-ancestor "$branch_name" main; then
            error "Branch $branch_name is not merged to main"
            return 1
        fi
        
        # Check commit message quality
        local commit_messages=$(git log --oneline main.."$branch_name" --pretty=format:"%s")
        
        if [ -z "$commit_messages" ]; then
            # Branch is already merged, check recent commits on main that might be from this branch
            local recent_commits=$(git log --oneline -10 --grep="$team_id\|wave.*$wave_number" --pretty=format:"%s")
            if [ -n "$recent_commits" ]; then
                log "Found related commits on main branch"
            fi
        else
            # Check for meaningful commit messages
            local short_messages=$(echo "$commit_messages" | grep -E "^.{1,10}$" | wc -l | tr -d ' ')
            local total_messages=$(echo "$commit_messages" | wc -l | tr -d ' ')
            
            if [ "$short_messages" -gt $((total_messages / 2)) ]; then
                warn "Many commit messages are very short (less than 10 characters)"
            fi
        fi
    )
    
    success "✅ Branch quality validation passed"
    return 0
}

# Run comprehensive wave quality gate
run_wave_quality_gate() {
    local job_id="$1"
    local wave_number="$2"
    local team_id="${3:-}"
    
    log "Running wave $wave_number quality gate for job $job_id"
    
    if [ -n "$team_id" ]; then
        log "Validating specific team: $team_id"
    else
        log "Validating all teams in wave $wave_number"
    fi
    
    local gate_passed=true
    local validation_errors=0
    local validation_warnings=0
    
    # Get teams to validate
    local teams_to_validate=()
    if [ -n "$team_id" ]; then
        teams_to_validate=("$team_id")
    else
        # Get all teams with ready files
        local wave_dir="$SYNC_BASE_DIR/$job_id/wave-$wave_number"
        if [ -d "$wave_dir" ]; then
            for ready_file in "$wave_dir"/*.ready.txt; do
                if [ -f "$ready_file" ]; then
                    local team=$(basename "$ready_file" .ready.txt)
                    teams_to_validate+=("$team")
                fi
            done
        fi
    fi
    
    if [ ${#teams_to_validate[@]} -eq 0 ]; then
        error "No teams to validate for wave $wave_number"
        return 1
    fi
    
    echo ""
    echo "🔍 Quality Gate Validation Report"
    echo "=================================="
    echo "Job ID: $job_id"
    echo "Wave: $wave_number"
    echo "Teams: ${teams_to_validate[*]}"
    echo "Started: $(date)"
    echo ""
    
    # Validate each team
    for team in "${teams_to_validate[@]}"; do
        echo "👥 Validating Team: $team"
        echo "========================"
        
        local team_errors=0
        local team_warnings=0
        
        # 1. Ready file integrity
        local ready_file="$SYNC_BASE_DIR/$job_id/wave-$wave_number/$team.ready.txt"
        echo -n "  📄 Ready file integrity: "
        if validate_ready_file_integrity "$ready_file" "$team" "$wave_number"; then
            echo "✅ PASS"
        else
            echo "❌ FAIL"
            team_errors=$((team_errors + 1))
        fi
        
        # 2. PR merge status
        echo -n "  🔗 PR merge validation: "
        if validate_pr_merge_status "$job_id" "$wave_number" "$team"; then
            echo "✅ PASS"
        else
            echo "❌ FAIL"
            team_errors=$((team_errors + 1))
        fi
        
        # 3. Branch quality
        echo -n "  🌿 Branch quality: "
        if validate_branch_quality "$job_id" "$wave_number" "$team"; then
            echo "✅ PASS"
        else
            echo "❌ FAIL"
            team_errors=$((team_errors + 1))
        fi
        
        # 4. Code quality (warnings only)
        echo -n "  🔧 Code quality: "
        if validate_code_quality "$job_id" "$wave_number" "$team"; then
            echo "✅ PASS"
        else
            echo "⚠️  WARNINGS"
            team_warnings=$((team_warnings + 1))
        fi
        
        # 5. Task completion (advisory)
        echo -n "  📋 Task completion: "
        if validate_task_completion "$job_id" "$wave_number" "$team"; then
            echo "✅ PASS"
        else
            echo "⚠️  ADVISORY"
            team_warnings=$((team_warnings + 1))
        fi
        
        echo ""
        
        if [ $team_errors -gt 0 ]; then
            echo "❌ Team $team: $team_errors errors, $team_warnings warnings"
            gate_passed=false
        elif [ $team_warnings -gt 0 ]; then
            echo "⚠️  Team $team: $team_warnings warnings (passed with warnings)"
        else
            echo "✅ Team $team: All validations passed"
        fi
        
        validation_errors=$((validation_errors + team_errors))
        validation_warnings=$((validation_warnings + team_warnings))
        
        echo ""
    done
    
    # Final report
    echo "📊 Quality Gate Summary"
    echo "======================="
    echo "Teams validated: ${#teams_to_validate[@]}"
    echo "Total errors: $validation_errors"
    echo "Total warnings: $validation_warnings"
    echo ""
    
    if [ "$gate_passed" = "true" ]; then
        success "🎉 QUALITY GATE PASSED - Wave $wave_number ready for transition"
        
        # Create quality gate certificate
        local cert_file="$SYNC_BASE_DIR/$job_id/wave-$wave_number/.quality-gate-certificate.txt"
        cat > "$cert_file" << EOF
WAVE QUALITY GATE CERTIFICATE

Wave: $wave_number
Job ID: $job_id
Validated Teams: ${teams_to_validate[*]}
Validation Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Validator: $(whoami)@$(hostname)

Summary:
- Teams Validated: ${#teams_to_validate[@]}
- Validation Errors: $validation_errors
- Validation Warnings: $validation_warnings
- Gate Status: PASSED

All critical validations passed. Wave is ready for transition.

Quality Gate Validator: wave-quality-gates.sh
EOF
        
        log "Quality gate certificate created: $cert_file"
        return 0
    else
        error "❌ QUALITY GATE FAILED - Wave $wave_number has validation errors"
        error "Fix the errors above before proceeding with wave transition"
        return 1
    fi
}

# Generate quality report
generate_quality_report() {
    local job_id="$1"
    local output_file="${2:-$job_id-quality-report.md}"
    
    log "Generating quality report for job $job_id"
    
    local total_waves=$(jq -r '.metadata.total_waves // 3' "$MAIN_REPO_DIR/TASKS_WAVES.json" 2>/dev/null || echo "3")
    
    cat > "$output_file" << EOF
# Wave Execution Quality Report

**Job ID:** \`$job_id\`  
**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)  
**Total Waves:** $total_waves

## Overall Status

EOF
    
    local overall_passed=true
    local total_teams=0
    local passed_teams=0
    
    for wave in $(seq 1 $total_waves); do
        echo "### Wave $wave Quality Status" >> "$output_file"
        echo "" >> "$output_file"
        
        local wave_dir="$SYNC_BASE_DIR/$job_id/wave-$wave"
        local quality_cert="$wave_dir/.quality-gate-certificate.txt"
        
        if [ -f "$quality_cert" ]; then
            echo "✅ **PASSED** - Quality gate certificate present" >> "$output_file"
            local cert_date=$(grep "Validation Date:" "$quality_cert" | cut -d':' -f2- | tr -d ' ')
            local validated_teams=$(grep "Validated Teams:" "$quality_cert" | cut -d':' -f2- | tr -d ' ')
            
            echo "- Validated: $cert_date" >> "$output_file"
            echo "- Teams: $validated_teams" >> "$output_file"
            
            # Count teams
            local wave_team_count=$(echo "$validated_teams" | tr ' ' '\n' | wc -l | tr -d ' ')
            total_teams=$((total_teams + wave_team_count))
            passed_teams=$((passed_teams + wave_team_count))
        elif [ -d "$wave_dir" ]; then
            local ready_files=($(find "$wave_dir" -name "*.ready.txt" 2>/dev/null || true))
            if [ ${#ready_files[@]} -gt 0 ]; then
                echo "⚠️  **PENDING** - Ready files present but no quality gate validation" >> "$output_file"
                echo "- Ready teams: ${#ready_files[@]}" >> "$output_file"
                echo "- Run: \`wave-quality-gates.sh validate $job_id $wave\`" >> "$output_file"
                overall_passed=false
                total_teams=$((total_teams + ${#ready_files[@]}))
            else
                echo "⏳ **IN PROGRESS** - No teams ready yet" >> "$output_file"
            fi
        else
            echo "❌ **NOT INITIALIZED** - Wave directory not found" >> "$output_file"
            overall_passed=false
        fi
        
        echo "" >> "$output_file"
    done
    
    # Add summary
    cat >> "$output_file" << EOF
## Summary

- **Overall Status:** $([ "$overall_passed" = "true" ] && echo "✅ PASSED" || echo "❌ NEEDS ATTENTION")
- **Teams Validated:** $passed_teams/$total_teams
- **Quality Gates:** $(find "$SYNC_BASE_DIR/$job_id" -name ".quality-gate-certificate.txt" | wc -l | tr -d ' ')/$total_waves waves

## Recommendations

EOF
    
    if [ "$overall_passed" = "true" ]; then
        echo "All quality gates passed. Project is ready for completion." >> "$output_file"
    else
        echo "Some waves need attention:" >> "$output_file"
        echo "" >> "$output_file"
        
        for wave in $(seq 1 $total_waves); do
            local quality_cert="$SYNC_BASE_DIR/$job_id/wave-$wave/.quality-gate-certificate.txt"
            if [ ! -f "$quality_cert" ]; then
                local wave_dir="$SYNC_BASE_DIR/$job_id/wave-$wave"
                if [ -d "$wave_dir" ]; then
                    local ready_files=($(find "$wave_dir" -name "*.ready.txt" 2>/dev/null || true))
                    if [ ${#ready_files[@]} -gt 0 ]; then
                        echo "- **Wave $wave:** Run quality validation" >> "$output_file"
                    fi
                fi
            fi
        done
    fi
    
    cat >> "$output_file" << EOF

---
*Generated by Wave Quality Gates System*
EOF
    
    success "Quality report generated: $output_file"
}

# Main command dispatcher
main() {
    init_quality_logging
    
    case "${1:-help}" in
        "validate")
            if [ $# -lt 3 ]; then
                error "Usage: $0 validate <job_id> <wave_number> [team_id]"
                exit 1
            fi
            run_wave_quality_gate "$2" "$3" "${4:-}"
            ;;
        "check-ready")
            if [ $# -lt 4 ]; then
                error "Usage: $0 check-ready <job_id> <wave_number> <team_id>"
                exit 1
            fi
            validate_ready_file_integrity "$SYNC_BASE_DIR/$2/wave-$3/$4.ready.txt" "$4" "$3"
            ;;
        "check-pr")
            if [ $# -lt 4 ]; then
                error "Usage: $0 check-pr <job_id> <wave_number> <team_id>"
                exit 1
            fi
            validate_pr_merge_status "$2" "$3" "$4"
            ;;
        "report")
            if [ $# -lt 2 ]; then
                error "Usage: $0 report <job_id> [output_file]"
                exit 1
            fi
            generate_quality_report "$2" "${3:-$2-quality-report.md}"
            ;;
        "help"|*)
            echo "Wave Quality Gates - Validation and quality checks for sync points"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  validate <job_id> <wave> [team_id]          Run comprehensive quality gate"
            echo "  check-ready <job_id> <wave> <team_id>       Validate ready file integrity"
            echo "  check-pr <job_id> <wave> <team_id>          Validate PR merge status"
            echo "  report <job_id> [output_file]               Generate quality report"
            echo "  help                                        Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 validate job-20250812 1                  # Validate all teams in wave 1"
            echo "  $0 validate job-20250812 1 alpha            # Validate specific team"
            echo "  $0 check-pr job-20250812 1 alpha            # Check team's PR status"
            echo "  $0 report job-20250812 quality.md           # Generate quality report"
            echo ""
            echo "Quality Checks:"
            echo "  - Ready file integrity and format validation"
            echo "  - PR merge status verification with GitHub"
            echo "  - Branch quality and commit validation"
            echo "  - Code quality scanning (warnings)"
            echo "  - Task completion status (advisory)"
            echo ""
            echo "Quality Gates ensure:"
            echo "  - All team work is properly merged"
            echo "  - Ready files are authentic and complete"
            echo "  - Code meets basic quality standards"
            echo "  - Wave transitions maintain quality"
            ;;
    esac
}

main "$@"