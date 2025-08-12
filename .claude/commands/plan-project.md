# Project Planning Command

Transform specification documents into comprehensive execution frameworks with GitHub integration, dependency analysis, and multiple execution strategies.

## Usage

```bash
# Basic usage - analyze current project
claude plan-project

# From specification file
claude plan-project --spec ./requirements.md

# Generate specific outputs
claude plan-project --spec ./requirements.md --output roadmap,issues,mermaid

# Team-specific planning
claude plan-project --mode team --waves 3 --spec ./project-spec.md

# Enterprise mode with full integration
claude plan-project --enterprise --github-project "myorg/myrepo" --spec ./requirements.md
```

## Parameters

### Core Options
- `--spec, -s <file>`: Input specification file (MD, PDF, TXT, or JSON)
- `--mode, -m <type>`: Execution mode (`solo`, `team`, `waves`) [default: `auto`]
- `--output, -o <formats>`: Output formats (comma-separated): `roadmap`, `issues`, `mermaid`, `dag`, `waves`
- `--github-project <repo>`: GitHub repository for issue creation (format: `owner/repo`)

### Execution Modes
- `--solo`: Optimize for single developer execution with dependency ordering
- `--team <size>`: Team mode with specified team size [default: 3-5]
- `--waves <count>`: Wave-based execution with specified wave count
- `--enterprise`: Full enterprise mode with all integrations

### Customization
- `--phase <name>`: Project phase identifier [default: "Phase 1"]
- `--duration <weeks>`: Target duration in weeks [default: auto-calculate]
- `--priority <level>`: Priority level (`P0`, `P1`, `P2`, `P3`) [default: `P1`]
- `--template <type>`: Use predefined template (`web-app`, `api`, `cli-tool`, `library`)

### Output Control
- `--dry-run`: Generate plans without creating GitHub issues
- `--verbose, -v`: Detailed output with analysis explanations
- `--format <type>`: Output format (`json`, `yaml`, `markdown`) [default: `markdown`]
- `--output-dir <path>`: Custom output directory [default: current directory]

## Input Formats

### Supported File Types
- **Markdown** (`.md`): Requirements, specifications, feature lists
- **PDF** (`.pdf`): Design documents, requirement docs
- **Text** (`.txt`): Simple requirement lists
- **JSON** (`.json`): Structured specifications
- **YAML** (`.yml`, `.yaml`): Configuration-based specs

### Auto-Detection
The command automatically detects project context from:
- `README.md` - Project overview and goals
- `package.json` / `Cargo.toml` / `requirements.txt` - Technology stack
- `.github/ISSUE_TEMPLATE/` - Existing issue patterns
- `docs/` directory - Additional specification documents

## Output Artifacts

### Standard Outputs
- `ROADMAP-<mode>.md` - Execution roadmap for specified mode
- `TASKS.md` - Detailed task breakdown with success criteria
- `TASKS_DAG.json` - Dependency graph in JSON format
- `DEPENDENCY_ANALYSIS.md` - Critical path and bottleneck analysis

### GitHub Integration
- Creates properly labeled issues with implementation guides
- Sets up project boards with dependency tracking
- Links related issues and creates epic structures
- Generates milestone structure based on waves/phases

### Visual Documentation
- Mermaid diagrams for dependency visualization
- Gantt charts for timeline planning
- Critical path highlighting
- Resource allocation charts

## Examples

### Quick Start - Analyze Current Project
```bash
# Auto-detect specifications and generate solo roadmap
claude plan-project
# → Analyzes README.md, creates ROADMAP-solo.md and TASKS.md
```

### Web Application Planning
```bash
# Plan a new web application from requirements
claude plan-project --spec ./requirements.md --template web-app --mode team --github-project "myorg/webapp"
# → Creates team roadmap, GitHub issues, and dependency analysis
```

### Enterprise Project Setup
```bash
# Full enterprise mode with custom phases
claude plan-project --enterprise --spec ./enterprise-spec.pdf --phase "MVP Development" --duration 8 --waves 4
# → Comprehensive planning with all integrations and visual documentation
```

### Library Development
```bash
# Open source library planning
claude plan-project --spec ./DESIGN.md --template library --mode solo --output roadmap,mermaid,dag
# → Solo developer roadmap with visual dependency analysis
```

## Configuration

### Global Defaults
Set global defaults in `~/.claude/config.yaml`:

```yaml
project-planning:
  default-mode: solo
  default-outputs: [roadmap, tasks, mermaid]
  github-integration: true
  template-preferences:
    web-app: team
    library: solo
    enterprise: waves
```

### Project-Specific Config
Override in `.claude/project-config.yaml`:

```yaml
planning:
  template: web-app
  team-size: 5
  default-phase-duration: 2 weeks
  custom-task-prefixes: ["FEAT", "BUG", "INFRA", "DOCS"]
```

## Integration Patterns

### Git Workflow
- Automatically detects current branch and project structure
- Suggests branch strategies based on execution mode
- Creates commit templates for task completion

### IDE Integration
- Generates VS Code tasks for major milestones
- Creates IDE-specific project configurations
- Sets up debugging configurations for different phases

### CI/CD Integration
- Suggests CI pipeline stages based on task dependencies
- Creates GitHub Actions workflows for automated validation
- Sets up deployment pipelines aligned with wave structure

## Error Handling

### Input Validation
- Clear error messages for unsupported file formats
- Suggestions for fixing malformed specifications
- Auto-correction for common specification patterns

### GitHub Integration Errors
- Graceful fallback when GitHub API is unavailable
- Permission checking with helpful resolution steps
- Rate limiting with intelligent retry strategies

### Dependency Resolution
- Circular dependency detection and resolution suggestions
- Missing prerequisite identification
- Resource conflict detection and mitigation

## Success Metrics

### Quality Gates
- Specification completeness score (0-100%)
- Dependency graph complexity metrics
- Estimated accuracy confidence levels
- Risk assessment for critical path items

### Validation Checks
- Task granularity optimization (not too big/small)
- Resource allocation balance
- Timeline feasibility analysis
- Success criteria clarity assessment

## Advanced Features

### AI-Enhanced Analysis
- Automatic gap detection in specifications
- Risk prediction based on task complexity
- Resource optimization recommendations
- Historical project pattern matching

### Collaboration Features
- Multi-stakeholder review workflows
- Expert domain assignment suggestions
- Capacity planning across team members
- Progress tracking integration

### Extensibility
- Custom task analyzers for domain-specific projects
- Plugin system for industry-specific templates
- Integration hooks for external project management tools
- Custom output format generators

---

*This command transforms your sophisticated project planning workflow into an accessible, powerful developer tool that reduces friction while maintaining all the intelligence and automation you've built.*