# Input Validation & Error Handling System

## Specification File Validation

### Format Detection & Validation

```bash
# Auto-detect and validate specification formats
validate_spec_file() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        error "Specification file not found: $file"
        suggest_alternatives "$file"
        return 1
    fi
    
    # Detect format based on extension and content
    local format=$(detect_format "$file")
    local quality_score=$(analyze_spec_quality "$file" "$format")
    
    if [[ $quality_score -lt 60 ]]; then
        warning "Specification quality score: $quality_score%"
        suggest_improvements "$file" "$format"
    fi
    
    return 0
}
```

### Supported Input Patterns

#### Markdown Specifications
```markdown
# Valid patterns that increase quality score:

## Requirements (High Impact: +20%)
- Clear requirement statements
- Acceptance criteria
- User stories with scenarios

## Technical Specifications (High Impact: +25%)
- Architecture decisions
- Technology stack choices
- Performance requirements

## Success Criteria (Critical: +30%)
- Measurable outcomes
- Quality gates
- Completion definitions

## Dependencies (Medium Impact: +15%)
- External system dependencies
- Resource requirements
- Timeline constraints

## Risk Assessment (Medium Impact: +10%)
- Identified risks
- Mitigation strategies
- Contingency plans
```

#### JSON Structure Validation
```json
{
  "project": {
    "name": "string (required)",
    "description": "string (required)",
    "type": "web-app|api|cli-tool|library|enterprise",
    "duration": "number (weeks, optional)"
  },
  "requirements": [
    {
      "id": "string (required)",
      "title": "string (required)", 
      "description": "string (required)",
      "priority": "P0|P1|P2|P3",
      "complexity": "low|medium|high",
      "dependencies": ["string array (optional)"]
    }
  ],
  "constraints": {
    "timeline": "string (optional)",
    "resources": "string (optional)",
    "technology": ["string array (optional)"]
  },
  "success_criteria": [
    {
      "metric": "string (required)",
      "target": "string (required)",
      "measurement": "string (required)"
    }
  ]
}
```

### Quality Assessment Criteria

#### Content Completeness (0-100%)
- **Project Overview** (20%): Clear name, description, and context
- **Requirements** (30%): Detailed, measurable requirements
- **Success Criteria** (25%): Quantifiable success metrics
- **Technical Details** (15%): Architecture, stack, constraints
- **Dependencies** (10%): External dependencies and blockers

#### Content Quality Indicators
- **High Quality** (80-100%): Ready for immediate planning
- **Good Quality** (60-79%): Minor gaps, proceed with warnings
- **Fair Quality** (40-59%): Requires enhancement before planning
- **Poor Quality** (0-39%): Major gaps, planning not recommended

## Parameter Validation

### Mode Validation
```bash
validate_execution_mode() {
    local mode="$1"
    local team_size="$2"
    
    case "$mode" in
        "solo")
            if [[ -n "$team_size" && "$team_size" -gt 1 ]]; then
                warning "Team size ignored in solo mode"
            fi
            ;;
        "team")
            if [[ -z "$team_size" || "$team_size" -lt 2 ]]; then
                error "Team mode requires team size ≥ 2"
                return 1
            fi
            if [[ "$team_size" -gt 20 ]]; then
                warning "Large team size ($team_size). Consider waves mode."
            fi
            ;;
        "waves")
            if [[ -z "$team_size" || "$team_size" -lt 6 ]]; then
                error "Waves mode requires team size ≥ 6"
                return 1
            fi
            ;;
        "auto")
            # Auto-detect based on specification complexity
            local complexity=$(calculate_complexity "$spec_file")
            recommend_mode "$complexity"
            ;;
        *)
            error "Invalid mode: $mode. Valid options: solo, team, waves, auto"
            return 1
            ;;
    esac
    
    return 0
}
```

### GitHub Integration Validation
```bash
validate_github_integration() {
    local repo="$1"
    
    if [[ -n "$repo" ]]; then
        # Validate repository format
        if [[ ! "$repo" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
            error "Invalid repository format: $repo"
            echo "Expected format: owner/repository"
            return 1
        fi
        
        # Check GitHub CLI availability
        if ! command -v gh &> /dev/null; then
            error "GitHub CLI (gh) not found"
            echo "Install: brew install gh  # or visit https://cli.github.com/"
            return 1
        fi
        
        # Verify authentication
        if ! gh auth status &> /dev/null; then
            error "GitHub CLI not authenticated"
            echo "Run: gh auth login"
            return 1
        fi
        
        # Check repository access
        if ! gh repo view "$repo" &> /dev/null; then
            error "Cannot access repository: $repo"
            echo "Check repository exists and you have access"
            return 1
        fi
        
        # Verify issue creation permissions
        if ! gh issue create --repo "$repo" --title "Test" --body "Test" --dry-run &> /dev/null; then
            warning "May not have issue creation permissions for $repo"
        fi
    fi
    
    return 0
}
```

## Error Categories & Resolution

### Category 1: Input File Errors

#### File Not Found
```bash
# Error: Specification file not found
suggest_alternatives() {
    local missing_file="$1"
    local dir=$(dirname "$missing_file")
    
    echo "Suggestion: Check these common specification files:"
    find "$dir" -name "README.md" -o -name "requirements.md" -o -name "REQUIREMENTS.txt" -o -name "spec.md" 2>/dev/null | head -5
    
    echo ""
    echo "Or create a specification file:"
    echo "  echo '# Project Requirements' > requirements.md"
    echo "  claude plan-project --spec requirements.md"
}
```

#### Invalid Format
```bash
# Error: Unsupported file format
suggest_format_fix() {
    local file="$1"
    local detected_issues="$2"
    
    echo "Issues found in $file:"
    echo "$detected_issues"
    echo ""
    echo "Quick fixes:"
    echo "  • Add project description section"
    echo "  • Define clear requirements with acceptance criteria"
    echo "  • Include success criteria or quality gates"
    echo "  • Specify technical constraints"
}
```

### Category 2: GitHub Integration Errors

#### Authentication Issues
```bash
handle_github_auth_error() {
    echo "GitHub authentication required:"
    echo ""
    echo "1. Install GitHub CLI:"
    echo "   • macOS: brew install gh"
    echo "   • Linux: Check https://cli.github.com/"
    echo "   • Windows: winget install GitHub.cli"
    echo ""
    echo "2. Authenticate:"
    echo "   gh auth login"
    echo ""
    echo "3. Verify access:"
    echo "   gh auth status"
}
```

#### Repository Access Issues
```bash
handle_repo_access_error() {
    local repo="$1"
    
    echo "Repository access error: $repo"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Verify repository exists: gh repo view $repo"
    echo "2. Check your access: gh repo list --owner ${repo%/*}"
    echo "3. Verify permissions for issue creation"
    echo ""
    echo "Alternative: Use --dry-run to generate plans without GitHub integration"
}
```

### Category 3: Configuration Errors

#### Invalid Team Configuration
```bash
handle_team_config_error() {
    local mode="$1"
    local team_size="$2"
    
    case "$mode" in
        "team")
            if [[ "$team_size" -lt 2 ]]; then
                echo "Team mode requires at least 2 team members"
                echo "Suggestion: Use --mode solo for single developer"
            fi
            ;;
        "waves")
            if [[ "$team_size" -lt 6 ]]; then
                echo "Waves mode requires at least 6 team members"
                echo "Suggestion: Use --mode team with --team-size $team_size"
            fi
            ;;
    esac
}
```

## Intelligent Error Recovery

### Auto-Correction Strategies
```bash
apply_auto_corrections() {
    local spec_file="$1"
    local errors="$2"
    
    # Auto-fix common markdown issues
    if echo "$errors" | grep -q "missing project description"; then
        if grep -q "^# " "$spec_file"; then
            local title=$(grep "^# " "$spec_file" | head -1 | sed 's/^# //')
            suggest_description_template "$title"
        fi
    fi
    
    # Auto-suggest requirements structure
    if echo "$errors" | grep -q "no clear requirements"; then
        suggest_requirements_template
    fi
    
    # Auto-detect technology stack
    if echo "$errors" | grep -q "missing technical details"; then
        auto_detect_tech_stack
    fi
}
```

### Progressive Enhancement
```bash
enhance_specification() {
    local spec_file="$1"
    local quality_score="$2"
    
    if [[ $quality_score -lt 80 ]]; then
        echo "Enhancing specification quality..."
        
        # Add missing sections interactively
        prompt_for_missing_sections "$spec_file"
        
        # Suggest improvements based on project type
        suggest_type_specific_enhancements "$spec_file"
        
        # Validate enhanced specification
        local new_score=$(analyze_spec_quality "$spec_file")
        echo "Quality improved: $quality_score% → $new_score%"
    fi
}
```

## User Experience Patterns

### Progressive Disclosure
- Start with minimal required information
- Progressively request additional details for higher quality output
- Provide clear value proposition for each additional input

### Helpful Defaults
- Auto-detect project context from existing files
- Provide sensible defaults based on project type
- Learn from user preferences over time

### Clear Feedback Loops
- Real-time validation feedback during input
- Progress indicators for long-running analysis
- Clear success/failure states with actionable next steps

### Error Prevention
- Input format examples and templates
- Interactive specification builders
- Pre-flight checks before expensive operations

This validation system ensures robust error handling while maintaining a smooth developer experience, automatically correcting common issues and providing clear guidance for complex problems.