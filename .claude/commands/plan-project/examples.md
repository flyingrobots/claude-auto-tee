# Project Planning Command Examples

## Quick Start Examples

### 1. Analyze Current Project
```bash
# Auto-detect specification from README.md or requirements.md
claude plan-project

# Output:
# ✓ Auto-detected specification: README.md
# ℹ Auto-detected execution mode: solo (complexity: 35%)
# ✓ Generated task analysis: TASKS.md
# ✓ Generated roadmap: ROADMAP-solo.md
```

### 2. Plan from Specification File
```bash
# Use specific specification file
claude plan-project --spec ./project-requirements.md

# With custom outputs
claude plan-project --spec ./spec.md --output roadmap,mermaid,tasks
```

### 3. Team Planning with GitHub Integration
```bash
# Team mode with GitHub issue creation
claude plan-project \
    --spec ./requirements.md \
    --team 5 \
    --github-project "myorg/awesome-project" \
    --output roadmap,issues,mermaid

# Output:
# ℹ Planning Summary:
#   Specification: ./requirements.md
#   Execution Mode: team
#   GitHub Integration: myorg/awesome-project
# ✓ Generated task analysis: TASKS.md
# ✓ Generated roadmap: ROADMAP-team.md
# ✓ Generated Mermaid diagrams: DEPENDENCY_DIAGRAM.md
# ✓ Created 23 GitHub issues
```

## Execution Mode Examples

### Solo Developer Mode
```bash
# Explicit solo mode
claude plan-project --solo --spec ./api-spec.md

# Auto-detected for small projects
claude plan-project --spec ./simple-cli-tool.md
# → Auto-detects solo mode for simple specifications
```

**Generated Output Structure:**
- Sequential task ordering optimized for single developer
- Minimal context switching between different work types
- Clear daily/weekly milestones
- Dependency-aware task progression

### Team Mode
```bash
# Team with specific size
claude plan-project --team 6 --spec ./web-app-requirements.md

# Team mode with role assignments
claude plan-project --team 8 --template web-app --spec ./requirements.md
```

**Generated Output Structure:**
- Role-based task assignments (Frontend, Backend, QA, DevOps)
- Sprint-based timeline with 2-week sprints
- Cross-team dependency management
- Collaborative workflow patterns

### Waves Mode
```bash
# Large project with wave execution
claude plan-project --waves 4 --spec ./enterprise-system.md

# Enterprise mode (auto-enables waves)
claude plan-project --enterprise --spec ./large-scale-spec.pdf
```

**Generated Output Structure:**
- Multiple parallel execution streams
- Wave-based resource allocation
- Cross-wave coordination protocols
- Scalable team management patterns

## Template Examples

### Web Application
```bash
claude plan-project --template web-app --spec ./webapp-requirements.md

# Automatically includes:
# - Frontend/Backend separation
# - Database design tasks
# - API development phases
# - UI/UX implementation
# - Performance optimization
# - Security considerations
```

### API Development
```bash
claude plan-project --template api --spec ./api-specification.yaml

# Automatically includes:
# - OpenAPI specification tasks
# - Authentication implementation
# - Rate limiting setup
# - Documentation generation
# - Testing strategies
# - Deployment automation
```

### CLI Tool
```bash
claude plan-project --template cli-tool --spec ./cli-requirements.md

# Automatically includes:
# - Argument parsing implementation
# - Configuration management
# - Error handling and user feedback
# - Cross-platform compatibility
# - Package distribution setup
# - Man page generation
```

### Library Development
```bash
claude plan-project --template library --spec ./library-design.md

# Automatically includes:
# - API design and documentation
# - Unit testing strategy
# - Integration examples
# - Performance benchmarking
# - Packaging and distribution
# - Versioning strategy
```

## Input Format Examples

### Markdown Specification
```markdown
# Project Requirements

## Overview
Modern web application for task management with real-time collaboration.

## Core Features
- User authentication and authorization
- Real-time task synchronization
- Team collaboration tools
- Mobile-responsive design
- Offline capability

## Technical Requirements
- React frontend with TypeScript
- Node.js backend with Express
- PostgreSQL database
- WebSocket for real-time features
- PWA capabilities

## Success Criteria
- Support 1000+ concurrent users
- <2s page load times
- 99.9% uptime SLA
- Mobile app store approval
```

### JSON Specification
```json
{
  "project": {
    "name": "TaskFlow API",
    "description": "RESTful API for task management system",
    "type": "api",
    "duration": 6
  },
  "requirements": [
    {
      "id": "AUTH001",
      "title": "User Authentication",
      "description": "JWT-based authentication with refresh tokens",
      "priority": "P0",
      "complexity": "medium",
      "dependencies": ["DATABASE001"]
    },
    {
      "id": "DATABASE001", 
      "title": "Database Design",
      "description": "PostgreSQL schema for users, tasks, projects",
      "priority": "P0",
      "complexity": "high"
    }
  ],
  "constraints": {
    "timeline": "6 weeks maximum",
    "resources": "2-3 developers",
    "technology": ["Node.js", "PostgreSQL", "Redis"]
  },
  "success_criteria": [
    {
      "metric": "Response Time",
      "target": "<200ms average",
      "measurement": "API monitoring"
    },
    {
      "metric": "Availability", 
      "target": "99.9% uptime",
      "measurement": "Uptime monitoring"
    }
  ]
}
```

## Advanced Usage Examples

### Enterprise Mode with Full Integration
```bash
claude plan-project \
    --enterprise \
    --spec ./enterprise-requirements.pdf \
    --phase "Phase 1: Core Platform" \
    --duration 12 \
    --github-project "enterprise/platform-core" \
    --output roadmap,issues,mermaid,dag,waves \
    --verbose

# Generates comprehensive enterprise planning:
# - ROADMAP-waves.md with 4-wave execution
# - TASKS.md with 80+ detailed tasks
# - DEPENDENCY_DIAGRAM.md with Mermaid visualizations
# - TASKS_WAVES.json with wave coordination data
# - 80+ GitHub issues with proper labeling
# - Detailed progress tracking and success metrics
```

### Multi-Phase Project Planning
```bash
# Phase 1: MVP Development
claude plan-project \
    --spec ./mvp-requirements.md \
    --phase "Phase 1: MVP" \
    --duration 4 \
    --team 4 \
    --priority P0

# Phase 2: Feature Expansion
claude plan-project \
    --spec ./phase2-requirements.md \
    --phase "Phase 2: Features" \
    --duration 6 \
    --waves 2 \
    --priority P1
```

### Dry Run and Validation
```bash
# Test planning without creating issues
claude plan-project \
    --spec ./requirements.md \
    --github-project "myorg/project" \
    --dry-run \
    --verbose

# Output includes:
# - Planning validation results  
# - Specification quality assessment
# - Estimated issue count
# - Resource allocation preview
# - Timeline feasibility analysis
```

## Integration Workflow Examples

### Git Workflow Integration
```bash
# Plan feature branch work
git checkout -b feature/user-authentication
claude plan-project --spec ./auth-requirements.md --solo

# Plan release preparation
git checkout develop  
claude plan-project --spec ./release-checklist.md --team 3 --phase "Release 2.1"
```

### CI/CD Pipeline Integration
```bash
# In .github/workflows/planning.yml
name: Project Planning
on:
  push:
    paths: ['requirements/**', 'specs/**']

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Generate Project Plan
        run: |
          claude plan-project \
            --spec requirements/current-phase.md \
            --github-project ${{ github.repository }} \
            --dry-run \
            --output roadmap,mermaid
      - name: Update Planning Documents
        run: git add *.md && git commit -m "Update project planning"
```

### IDE Integration Example
```bash
# Generate VS Code tasks
claude plan-project --spec ./requirements.md --format json > .vscode/tasks.json

# Create development workspace
claude plan-project --template web-app --spec ./spec.md
code . # Opens with generated project structure
```

## Troubleshooting Examples

### Common Issues and Solutions

#### Missing Specification File
```bash
$ claude plan-project --spec ./missing-file.md
✗ Specification file not found: ./missing-file.md
ℹ Looking for alternative specification files...
ℹ Found: README.md
ℹ Use: claude plan-project --spec README.md

# Solution: Use auto-detection or create specification
$ claude plan-project  # Auto-detects README.md
```

#### GitHub Authentication Issues
```bash
$ claude plan-project --github-project "myorg/repo" --spec ./requirements.md  
✗ GitHub CLI not authenticated
ℹ Run: gh auth login

# Solution: Authenticate with GitHub CLI
$ gh auth login
$ claude plan-project --github-project "myorg/repo" --spec ./requirements.md
```

#### Large Specification Processing
```bash
$ claude plan-project --spec ./huge-requirements.pdf
⚠ Large specification detected (500+ requirements)
ℹ Consider using --waves mode for better organization
ℹ This may take 2-3 minutes to process...

# Auto-switches to waves mode for complex specifications
ℹ Auto-detected execution mode: waves (complexity: 85%)
```

## Performance and Scaling Examples

### Optimizing for Large Projects
```bash
# Use waves mode for 50+ tasks
claude plan-project --waves 5 --spec ./large-project.md

# Break into phases for very large projects  
claude plan-project --phase "Phase 1: Core" --spec ./phase1.md
claude plan-project --phase "Phase 2: Features" --spec ./phase2.md
```

### Customizing Output for Different Audiences
```bash
# Executive summary format
claude plan-project --spec ./requirements.md --format json | jq '.summary'

# Developer-focused output
claude plan-project --spec ./requirements.md --output roadmap,dag --verbose

# Stakeholder presentation
claude plan-project --spec ./requirements.md --output mermaid,waves --format markdown
```

These examples demonstrate the flexibility and power of the project planning command while maintaining simplicity for common use cases.