#!/usr/bin/env bash
# Project Planning Command Implementation
# Transforms specifications into comprehensive execution frameworks

set -euo pipefail

# Default configuration
DEFAULT_MODE="auto"
DEFAULT_OUTPUTS="roadmap,tasks"
DEFAULT_PHASE="Phase 1"
DRY_RUN=false
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Utility functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

# Help function
show_help() {
    cat << EOF
Project Planning Command

Transform specification documents into comprehensive execution frameworks with 
GitHub integration, dependency analysis, and multiple execution strategies.

USAGE:
    claude plan-project [OPTIONS]

OPTIONS:
    Core Options:
        -s, --spec <file>           Input specification file (MD, PDF, TXT, JSON)
        -m, --mode <type>           Execution mode: solo, team, waves, auto [default: auto]
        -o, --output <formats>      Output formats: roadmap,issues,mermaid,dag,waves
        --github-project <repo>     GitHub repository for issue creation (owner/repo)

    Execution Modes:
        --solo                      Optimize for single developer execution
        --team <size>               Team mode with specified size [default: 3-5]
        --waves <count>             Wave-based execution with count
        --enterprise                Full enterprise mode with all integrations

    Customization:
        --phase <name>              Project phase identifier [default: "Phase 1"]
        --duration <weeks>          Target duration in weeks
        --priority <level>          Priority level: P0, P1, P2, P3 [default: P1]
        --template <type>           Template: web-app, api, cli-tool, library

    Output Control:
        --dry-run                   Generate plans without creating GitHub issues
        --verbose, -v               Detailed output with analysis explanations
        --format <type>             Output format: json, yaml, markdown [default: markdown]
        --output-dir <path>         Custom output directory [default: current]

    Help:
        -h, --help                  Show this help message

EXAMPLES:
    # Quick start - analyze current project
    claude plan-project

    # From specification file  
    claude plan-project --spec ./requirements.md --output roadmap,mermaid

    # Team planning with GitHub integration
    claude plan-project --spec ./spec.md --team 5 --github-project "myorg/repo"

    # Enterprise mode with full features
    claude plan-project --enterprise --spec ./enterprise-spec.pdf --waves 4

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--spec)
                SPEC_FILE="$2"
                shift 2
                ;;
            -m|--mode)
                EXECUTION_MODE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FORMATS="$2"
                shift 2
                ;;
            --github-project)
                GITHUB_REPO="$2"
                shift 2
                ;;
            --solo)
                EXECUTION_MODE="solo"
                shift
                ;;
            --team)
                EXECUTION_MODE="team"
                if [[ $# -gt 1 && $2 =~ ^[0-9]+$ ]]; then
                    TEAM_SIZE="$2"
                    shift 2
                else
                    TEAM_SIZE="4"
                    shift
                fi
                ;;
            --waves)
                EXECUTION_MODE="waves"
                if [[ $# -gt 1 && $2 =~ ^[0-9]+$ ]]; then
                    WAVE_COUNT="$2"
                    shift 2
                else
                    WAVE_COUNT="3"
                    shift
                fi
                ;;
            --enterprise)
                ENTERPRISE_MODE=true
                EXECUTION_MODE="waves"
                OUTPUT_FORMATS="roadmap,issues,mermaid,dag,waves"
                shift
                ;;
            --phase)
                PHASE_NAME="$2"
                shift 2
                ;;
            --duration)
                DURATION_WEEKS="$2"
                shift 2
                ;;
            --priority)
                PRIORITY_LEVEL="$2"
                shift 2
                ;;
            --template)
                PROJECT_TEMPLATE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information."
                exit 1
                ;;
        esac
    done
}

# Auto-detect specification file
auto_detect_spec() {
    local candidates=(
        "README.md"
        "requirements.md" 
        "REQUIREMENTS.md"
        "spec.md"
        "SPEC.md"
        "specification.md"
        "SPECIFICATION.md"
        "requirements.txt"
        "REQUIREMENTS.txt"
        "docs/requirements.md"
        "docs/specification.md"
    )
    
    for candidate in "${candidates[@]}"; do
        if [[ -f "$candidate" ]]; then
            log_info "Auto-detected specification: $candidate"
            echo "$candidate"
            return 0
        fi
    done
    
    return 1
}

# Validate specification file
validate_specification() {
    local spec_file="$1"
    
    if [[ ! -f "$spec_file" ]]; then
        log_error "Specification file not found: $spec_file"
        
        # Suggest alternatives
        log_info "Looking for alternative specification files..."
        if detected_spec=$(auto_detect_spec); then
            log_info "Found: $detected_spec"
            log_info "Use: claude plan-project --spec $detected_spec"
        else
            log_info "Create a specification file:"
            log_info "  echo '# Project Requirements' > requirements.md"
            log_info "  claude plan-project --spec requirements.md"
        fi
        return 1
    fi
    
    # Basic quality assessment
    local file_size=$(wc -l < "$spec_file")
    if [[ $file_size -lt 10 ]]; then
        log_warning "Specification file appears minimal ($file_size lines)"
        log_info "Consider adding more detail for better planning quality"
    fi
    
    log_success "Specification file validated: $spec_file"
    return 0
}

# Validate GitHub integration
validate_github() {
    local repo="$1"
    
    if [[ -n "$repo" ]]; then
        # Validate repository format
        if [[ ! "$repo" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
            log_error "Invalid repository format: $repo"
            log_info "Expected format: owner/repository"
            return 1
        fi
        
        # Check GitHub CLI availability
        if ! command -v gh &> /dev/null; then
            log_error "GitHub CLI (gh) not found"
            log_info "Install: brew install gh  # or visit https://cli.github.com/"
            return 1
        fi
        
        # Verify authentication
        if ! gh auth status &> /dev/null 2>&1; then
            log_error "GitHub CLI not authenticated"
            log_info "Run: gh auth login"
            return 1
        fi
        
        log_success "GitHub integration validated for: $repo"
    fi
    
    return 0
}

# Determine execution mode
determine_execution_mode() {
    local spec_file="$1"
    
    if [[ "$EXECUTION_MODE" == "auto" ]]; then
        # Auto-detect based on specification complexity
        local complexity_score=50
        
        # Increase complexity based on file size
        local file_size=$(wc -l < "$spec_file")
        if [[ $file_size -gt 100 ]]; then
            ((complexity_score += 20))
        fi
        
        # Increase complexity based on content indicators
        if grep -q -i "team\|collaboration\|multiple" "$spec_file"; then
            ((complexity_score += 15))
        fi
        
        if grep -q -i "enterprise\|large\|complex\|distributed" "$spec_file"; then
            ((complexity_score += 25))
        fi
        
        # Determine mode based on complexity
        if [[ $complexity_score -lt 40 ]]; then
            EXECUTION_MODE="solo"
            log_info "Auto-detected execution mode: solo (complexity: $complexity_score%)"
        elif [[ $complexity_score -lt 75 ]]; then
            EXECUTION_MODE="team"
            TEAM_SIZE=${TEAM_SIZE:-4}
            log_info "Auto-detected execution mode: team (complexity: $complexity_score%)"
        else
            EXECUTION_MODE="waves"
            WAVE_COUNT=${WAVE_COUNT:-3}
            log_info "Auto-detected execution mode: waves (complexity: $complexity_score%)"
        fi
    fi
    
    log_verbose "Final execution mode: $EXECUTION_MODE"
}

# Generate task analysis
generate_task_analysis() {
    local spec_file="$1"
    
    log_info "Analyzing specification and generating tasks..."
    
    # Create TASKS.md with comprehensive task breakdown
    cat > TASKS.md << EOF
# Project Implementation Tasks

**Phase:** $PHASE_NAME  
**Execution Mode:** $EXECUTION_MODE  
**Specification Source:** $spec_file  
**Generated:** $(date)

## Success Criteria

- [ ] All specification requirements implemented
- [ ] Quality gates met for production readiness
- [ ] Documentation completed and validated
- [ ] Testing coverage meets project standards

## Task Categories

### Core Implementation
EOF
    
    # Analyze specification content and generate relevant tasks
    local task_counter=1
    
    # Extract requirements from specification
    if grep -q -i "requirement\|feature\|functionality" "$spec_file"; then
        echo "" >> TASKS.md
        echo "### Requirements Implementation" >> TASKS.md
        
        # Generate tasks based on detected requirements
        while IFS= read -r line; do
            if [[ "$line" =~ ^[#-\*].*(requirement|feature|implement|build|create) ]]; then
                local task_title=$(echo "$line" | sed 's/^[#-\*[:space:]]*//' | head -c 80)
                printf "- [ ] T%03d %s\n" $task_counter "$task_title" >> TASKS.md
                ((task_counter++))
            fi
        done < "$spec_file"
    fi
    
    # Add standard task categories
    cat >> TASKS.md << EOF

### Testing & Quality Assurance
- [ ] T$(printf "%03d" $task_counter) Unit test coverage implementation
- [ ] T$(printf "%03d" $((task_counter + 1))) Integration testing setup
- [ ] T$(printf "%03d" $((task_counter + 2))) Performance testing validation
- [ ] T$(printf "%03d" $((task_counter + 3))) Security assessment and fixes

### Documentation
- [ ] T$(printf "%03d" $((task_counter + 4))) API documentation completion
- [ ] T$(printf "%03d" $((task_counter + 5))) User guide and examples
- [ ] T$(printf "%03d" $((task_counter + 6))) Deployment documentation
- [ ] T$(printf "%03d" $((task_counter + 7))) Troubleshooting guide

### Deployment & Operations
- [ ] T$(printf "%03d" $((task_counter + 8))) Production environment setup
- [ ] T$(printf "%03d" $((task_counter + 9))) CI/CD pipeline configuration
- [ ] T$(printf "%03d" $((task_counter + 10))) Monitoring and alerting setup
- [ ] T$(printf "%03d" $((task_counter + 11))) Release preparation and validation

EOF
    
    log_success "Generated task analysis: TASKS.md"
}

# Generate roadmap based on execution mode
generate_roadmap() {
    local mode="$1"
    local roadmap_file="ROADMAP-${mode}.md"
    
    log_info "Generating $mode roadmap..."
    
    case "$mode" in
        "solo")
            generate_solo_roadmap "$roadmap_file"
            ;;
        "team")
            generate_team_roadmap "$roadmap_file"
            ;;
        "waves")
            generate_waves_roadmap "$roadmap_file"
            ;;
    esac
    
    log_success "Generated roadmap: $roadmap_file"
}

# Generate solo developer roadmap
generate_solo_roadmap() {
    local output_file="$1"
    
    cat > "$output_file" << EOF
# Solo Developer Roadmap - $PHASE_NAME

**Execution Mode:** Solo Developer  
**Estimated Duration:** ${DURATION_WEEKS:-"2-3"} weeks  
**Generated:** $(date)

## Overview

Optimized execution path for a single developer with dependency-ordered tasks and minimal context switching.

## Week 1: Foundation & Core Features

### Days 1-2: Project Setup
- [ ] Development environment configuration
- [ ] Core architecture implementation
- [ ] Basic project structure setup

### Days 3-5: Core Implementation
- [ ] Primary feature development
- [ ] API endpoint implementation
- [ ] Data layer development

## Week 2: Features & Integration

### Days 6-8: Feature Development
- [ ] Secondary feature implementation
- [ ] Integration between components
- [ ] Error handling and validation

### Days 9-10: Testing & Quality
- [ ] Unit test implementation
- [ ] Integration testing
- [ ] Code quality improvements

## Week 3: Polish & Deployment (if needed)

### Days 11-12: Documentation
- [ ] API documentation
- [ ] User documentation
- [ ] Deployment guides

### Days 13-14: Final Preparation
- [ ] Production readiness review
- [ ] Performance optimization
- [ ] Security assessment

### Day 15: Release
- [ ] Final testing and validation
- [ ] Production deployment
- [ ] Post-launch monitoring setup

## Success Metrics
- All tasks completed within timeline
- Code quality gates met
- Documentation complete
- Production deployment successful

EOF

    log_verbose "Solo roadmap generated with dependency optimization"
}

# Generate team roadmap
generate_team_roadmap() {
    local output_file="$1"
    local team_size=${TEAM_SIZE:-4}
    
    cat > "$output_file" << EOF
# Team Roadmap - $PHASE_NAME

**Execution Mode:** Team ($team_size members)  
**Estimated Duration:** ${DURATION_WEEKS:-"2-4"} weeks  
**Generated:** $(date)

## Team Structure

### Core Team Roles
- **Tech Lead:** Architecture, code review, technical decisions
- **Frontend Developer:** UI/UX implementation, client-side logic
- **Backend Developer:** API, database, server-side logic
- **QA Engineer:** Testing, quality assurance, automation

## Sprint Structure (2-week sprints)

### Sprint 1: Foundation
**Week 1-2**

#### Team Member Assignments:
- **Tech Lead:** Architecture design, development environment setup
- **Frontend:** UI mockups, component library setup
- **Backend:** Database design, API specification
- **QA:** Test strategy, automation framework setup

### Sprint 2: Core Development
**Week 3-4**

#### Team Member Assignments:
- **Tech Lead:** Integration oversight, performance optimization
- **Frontend:** Core UI implementation, state management
- **Backend:** API implementation, business logic
- **QA:** Test implementation, continuous integration setup

## Collaboration Patterns

### Daily Standups (15 min)
- Progress updates
- Blocker identification
- Cross-team coordination

### Sprint Planning (2 hours)
- Task breakdown and estimation
- Sprint goal definition
- Capacity planning

### Sprint Review (1 hour)
- Demo completed features
- Stakeholder feedback
- Next sprint planning

## Success Metrics
- Sprint velocity consistency
- Code review turnaround <24 hours
- Cross-team dependencies resolved quickly
- Quality gates met for each sprint

EOF

    log_verbose "Team roadmap generated for $team_size members"
}

# Generate waves roadmap
generate_waves_roadmap() {
    local output_file="$1"
    local wave_count=${WAVE_COUNT:-3}
    
    cat > "$output_file" << EOF
# Waves Execution Roadmap - $PHASE_NAME

**Execution Mode:** Wave-based ($wave_count waves)  
**Estimated Duration:** ${DURATION_WEEKS:-"4-6"} weeks  
**Generated:** $(date)

## Wave Strategy

Large-scale execution with coordinated waves of parallel development streams.

### Wave 1: Foundation & Infrastructure (Weeks 1-2)
**Teams:** Infrastructure, Architecture, DevOps  
**Size:** 6-8 developers

#### Objectives:
- [ ] Core infrastructure setup
- [ ] Development environment standardization
- [ ] CI/CD pipeline establishment
- [ ] Architecture foundation implementation

#### Deliverables:
- Production-ready infrastructure
- Developer onboarding documentation
- Automated testing framework
- Code quality standards

### Wave 2: Core Features (Weeks 2-4)
**Teams:** Frontend, Backend, API  
**Size:** 8-12 developers

#### Objectives:
- [ ] Primary feature implementation
- [ ] API development and integration
- [ ] Database design and implementation
- [ ] User interface development

#### Deliverables:
- Core functionality complete
- API documentation
- Database migration scripts
- Frontend component library

### Wave 3: Integration & Quality (Weeks 4-6)
**Teams:** QA, Integration, Performance  
**Size:** 4-8 developers

#### Objectives:
- [ ] System integration testing
- [ ] Performance optimization
- [ ] Security assessment
- [ ] Documentation completion

#### Deliverables:
- Integrated system testing
- Performance benchmarks
- Security audit results
- Complete documentation set

## Cross-Wave Coordination

### Daily Sync Meetings
- **Wave Leads:** 30-minute alignment meeting
- **Cross-Dependencies:** Issue identification and resolution
- **Resource Allocation:** Dynamic team member assignment

### Weekly All-Hands
- **Progress Review:** Each wave presents progress
- **Blocker Resolution:** Cross-wave dependency issues
- **Next Week Planning:** Resource and timeline adjustments

## Success Metrics
- Wave delivery milestones met
- Cross-wave dependencies resolved quickly
- Resource utilization optimization
- Quality maintained across all waves

EOF

    log_verbose "Waves roadmap generated for $wave_count waves"
}

# Generate Mermaid diagrams
generate_mermaid_diagrams() {
    if [[ "$OUTPUT_FORMATS" == *"mermaid"* ]]; then
        log_info "Generating Mermaid dependency diagrams..."
        
        cat > DEPENDENCY_DIAGRAM.md << EOF
# Project Dependency Diagrams

## High-Level Project Flow

\`\`\`mermaid
graph TD
    A[Requirements Analysis] --> B[Architecture Design]
    B --> C[Core Implementation]
    C --> D[Feature Development]
    D --> E[Integration Testing]
    E --> F[Quality Assurance]
    F --> G[Documentation]
    G --> H[Deployment]
    
    style A fill:#e1f5fe
    style B fill:#f3e5f5
    style C fill:#e8f5e8
    style D fill:#fff3e0
    style E fill:#fce4ec
    style F fill:#f1f8e9
    style G fill:#e0f2f1
    style H fill:#fff8e1
\`\`\`

## Execution Mode: $EXECUTION_MODE

EOF

        case "$EXECUTION_MODE" in
            "solo")
                cat >> DEPENDENCY_DIAGRAM.md << EOF
\`\`\`mermaid
gantt
    title Solo Developer Timeline
    dateFormat  X
    axisFormat %w
    
    section Setup
    Environment Setup     :a1, 0, 2d
    Architecture Design   :a2, after a1, 2d
    
    section Development
    Core Features        :b1, after a2, 3d
    Secondary Features   :b2, after b1, 3d
    
    section Quality
    Testing             :c1, after b2, 2d
    Documentation       :c2, after c1, 1d
    
    section Release
    Deployment          :d1, after c2, 1d
\`\`\`
EOF
                ;;
            "team")
                cat >> DEPENDENCY_DIAGRAM.md << EOF
\`\`\`mermaid
gantt
    title Team Development Timeline
    dateFormat  X
    axisFormat %w
    
    section Sprint 1
    Architecture        :a1, 0, 5d
    Frontend Setup      :a2, 0, 3d
    Backend Setup       :a3, 0, 3d
    QA Framework       :a4, 0, 4d
    
    section Sprint 2
    Frontend Dev       :b1, after a2, 5d
    Backend Dev        :b2, after a3, 5d
    Integration        :b3, after a1, 5d
    Testing           :b4, after a4, 5d
\`\`\`
EOF
                ;;
            "waves")
                cat >> DEPENDENCY_DIAGRAM.md << EOF
\`\`\`mermaid
graph LR
    subgraph "Wave 1: Infrastructure"
        W1A[Infrastructure Setup]
        W1B[DevOps Pipeline]
        W1C[Architecture Foundation]
    end
    
    subgraph "Wave 2: Development"
        W2A[Frontend Development]
        W2B[Backend Development] 
        W2C[API Implementation]
    end
    
    subgraph "Wave 3: Quality"
        W3A[Integration Testing]
        W3B[Performance Testing]
        W3C[Documentation]
    end
    
    W1A --> W2A
    W1B --> W2B
    W1C --> W2C
    W2A --> W3A
    W2B --> W3B
    W2C --> W3C
\`\`\`
EOF
                ;;
        esac
        
        log_success "Generated Mermaid diagrams: DEPENDENCY_DIAGRAM.md"
    fi
}

# Create GitHub issues
create_github_issues() {
    local repo="$1"
    
    if [[ -n "$repo" && "$DRY_RUN" != "true" ]]; then
        log_info "Creating GitHub issues for repository: $repo"
        
        # Create issues from TASKS.md
        local issue_count=0
        while IFS= read -r line; do
            if [[ "$line" =~ ^\-.*\[.*\].*(T[0-9]+) ]]; then
                local task_id=$(echo "$line" | grep -o 'T[0-9][0-9][0-9]')
                local task_title=$(echo "$line" | sed 's/^-.*\[.*\][[:space:]]*//' | sed 's/T[0-9][0-9][0-9][[:space:]]*//')
                
                if [[ -n "$task_title" && "$task_title" != *"T"[0-9]* ]]; then
                    log_verbose "Creating issue: $task_id - $task_title"
                    
                    if gh issue create \
                        --repo "$repo" \
                        --title "[$PHASE_NAME] $task_id: $task_title" \
                        --body "Implementation task from project planning automation.\n\n**Phase:** $PHASE_NAME\n**Task ID:** $task_id\n**Execution Mode:** $EXECUTION_MODE\n\n**Description:**\n$task_title\n\n**Generated:** $(date)" \
                        --label "task,$PHASE_NAME,automated" \
                        > /dev/null 2>&1; then
                        ((issue_count++))
                    fi
                fi
            fi
        done < TASKS.md
        
        log_success "Created $issue_count GitHub issues"
    elif [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry run: Would create GitHub issues for tasks in TASKS.md"
        local task_count=$(grep -c "^\-.*\[.*\].*(T[0-9]" TASKS.md || echo "0")
        log_info "Would create approximately $task_count issues"
    fi
}

# Main execution function
main() {
    # Initialize variables with defaults
    SPEC_FILE=""
    EXECUTION_MODE="$DEFAULT_MODE"
    OUTPUT_FORMATS="$DEFAULT_OUTPUTS"
    GITHUB_REPO=""
    PHASE_NAME="$DEFAULT_PHASE"
    ENTERPRISE_MODE=false
    OUTPUT_DIR="."
    OUTPUT_FORMAT="markdown"
    TEAM_SIZE=""
    WAVE_COUNT=""
    DURATION_WEEKS=""
    PRIORITY_LEVEL="P1"
    PROJECT_TEMPLATE=""
    
    # Parse arguments
    parse_args "$@"
    
    # Show banner
    echo -e "${CYAN}🎯 Project Planning Command${NC}"
    echo -e "${CYAN}═══════════════════════════${NC}"
    echo ""
    
    # Auto-detect specification if not provided
    if [[ -z "$SPEC_FILE" ]]; then
        log_info "No specification file provided, auto-detecting..."
        if SPEC_FILE=$(auto_detect_spec); then
            log_success "Using specification: $SPEC_FILE"
        else
            log_error "No specification file found"
            log_info "Create a specification file or use --spec to specify one"
            exit 1
        fi
    fi
    
    # Validate inputs
    if ! validate_specification "$SPEC_FILE"; then
        exit 1
    fi
    
    if ! validate_github "${GITHUB_REPO:-}"; then
        exit 1
    fi
    
    # Determine execution mode
    determine_execution_mode "$SPEC_FILE"
    
    # Show planning summary
    echo ""
    log_info "Planning Summary:"
    log_info "  Specification: $SPEC_FILE"
    log_info "  Execution Mode: $EXECUTION_MODE"
    log_info "  Output Formats: $OUTPUT_FORMATS"
    if [[ -n "$GITHUB_REPO" ]]; then
        log_info "  GitHub Integration: $GITHUB_REPO"
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "  Mode: DRY RUN (no GitHub issues will be created)"
    fi
    echo ""
    
    # Generate outputs based on requested formats
    log_info "Generating project planning artifacts..."
    echo ""
    
    # Always generate task analysis
    generate_task_analysis "$SPEC_FILE"
    
    # Generate roadmap
    if [[ "$OUTPUT_FORMATS" == *"roadmap"* ]]; then
        generate_roadmap "$EXECUTION_MODE"
    fi
    
    # Generate Mermaid diagrams
    generate_mermaid_diagrams
    
    # Create GitHub issues if requested
    if [[ -n "$GITHUB_REPO" && "$OUTPUT_FORMATS" == *"issues"* ]]; then
        create_github_issues "$GITHUB_REPO"
    fi
    
    # Show completion summary
    echo ""
    log_success "Project planning completed successfully!"
    echo ""
    log_info "Generated files:"
    log_info "  • TASKS.md - Comprehensive task breakdown"
    
    if [[ "$OUTPUT_FORMATS" == *"roadmap"* ]]; then
        log_info "  • ROADMAP-${EXECUTION_MODE}.md - Execution roadmap"
    fi
    
    if [[ "$OUTPUT_FORMATS" == *"mermaid"* ]]; then
        log_info "  • DEPENDENCY_DIAGRAM.md - Visual dependency diagrams"
    fi
    
    echo ""
    log_info "Next steps:"
    log_info "  1. Review generated planning artifacts"
    log_info "  2. Customize tasks based on your specific requirements"
    if [[ -n "$GITHUB_REPO" ]]; then
        log_info "  3. Check GitHub issues at: https://github.com/$GITHUB_REPO/issues"
    fi
    log_info "  4. Begin execution following the $EXECUTION_MODE roadmap"
    echo ""
}

# Run main function with all arguments
main "$@"