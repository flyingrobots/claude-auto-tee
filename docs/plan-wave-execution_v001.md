# Plan Wave Execution v001 - MVP

**Simple dependency-driven project planning with wave-based execution**

## What This Does

Transforms project requirements into executable plans using:
1. **Dependency Analysis** - Build task dependency graph from requirements
2. **Wave Generation** - Group tasks into dependency levels (waves)  
3. **Execution Strategy** - Teams work independently within waves, sync between waves
4. **GitHub Integration** - Create structured issues with implementation guides

## Core Value Proposition

- **80% less coordination overhead** - Only sync between waves, not constantly
- **Linear team scaling** - More people = faster waves (no Brooks' Law penalty)
- **Dependency-driven** - Technical reality drives timeline, not arbitrary sprints
- **Immediately actionable** - Generate GitHub issues with clear acceptance criteria

## The Wave Model

```
Wave 1: Foundation (0 dependencies)
├── Research platform requirements
├── Set up development environment  
├── Design core architecture
└── Create project scaffolding

    ▼ SYNC POINT 1 ▼
    All teams complete Wave 1 before ANY team starts Wave 2

Wave 2: Implementation (depends only on Wave 1)
├── Implement core features
├── Write unit tests
├── Create basic documentation
└── Set up CI/CD pipeline

    ▼ SYNC POINT 2 ▼
    All teams complete Wave 2 before ANY team starts Wave 3

Wave 3: Integration (depends on Wave 1 + 2)
├── Integration testing
├── Performance optimization
├── Final documentation
└── Deployment preparation
```

## Command Interface

```bash
# Basic usage - analyze current project
claude /plan-wave-execution

# With specification file
claude /plan-wave-execution --spec requirements.md

# Team-specific planning
claude /plan-wave-execution --spec requirements.md --team-size 5

# With GitHub integration
claude /plan-wave-execution --spec requirements.md --github --project myorg/myrepo
```

## Input Format

**Accepts:**
- Markdown task lists with checkboxes
- Requirements documents with user stories
- Project specifications with acceptance criteria
- Plain text feature descriptions

**Requirements for good results:**
- 20-100 concrete tasks/features
- Clear acceptance criteria where possible
- Mention of technical dependencies
- Team size and timeline constraints

## Output Deliverables

1. **Dependency Graph** (`TASKS_WAVES.json`)
   - Task nodes with clear identifiers
   - Dependency edges with rationale
   - Wave assignments with timing estimates

2. **Execution Plan** (`ROADMAP_WAVES.md`)
   - Wave-by-wave breakdown
   - Team coordination points
   - Timeline estimates and critical path

3. **GitHub Issues** (optional)
   - One issue per task with implementation guide
   - Proper labeling and project assignment
   - Dependency linking between issues

4. **Visual Diagrams** (Mermaid)
   - Dependency graph visualization
   - Wave execution timeline
   - Critical path highlighting

## Algorithm (Simplified)

```
1. Parse tasks from specification
2. Infer dependencies from task descriptions and technical logic
3. Build directed acyclic graph (DAG) of dependencies
4. Generate waves using topological sort:
   - Wave 1: Tasks with 0 dependencies
   - Wave 2: Tasks depending only on Wave 1
   - Wave 3: Tasks depending only on Wave 1+2
   - etc.
5. Balance wave sizes for optimal team utilization
6. Generate timeline estimates using simple heuristics
7. Create execution artifacts and GitHub integration
```

## Example Workflow

**Input:** `requirements.md` with 42 tasks
```markdown
## Authentication System
- [ ] Design user schema
- [ ] Implement login/logout endpoints  
- [ ] Add password hashing
- [ ] Create session management
- [ ] Write authentication tests

## API Development  
- [ ] Design REST API structure
- [ ] Implement user CRUD operations
- [ ] Add input validation
- [ ] Create API documentation
- [ ] Write integration tests
```

**Output:** 3 waves, 6-day timeline
- **Wave 1 (2 days):** Schema design, API structure design
- **Wave 2 (3 days):** Implementation, validation, hashing  
- **Wave 3 (1 day):** Testing, documentation

**Coordination:** 2 sync points total instead of daily standups

## Team Scaling Examples

| Team Size | Wave Duration | Total Timeline | Coordination |
|-----------|---------------|----------------|--------------|
| Solo (1) | Varies | 10-15 days | None needed |
| Small (3-5) | 2-3 days/wave | 6-9 days | 2 sync points |
| Medium (6-10) | 1-2 days/wave | 3-6 days | 2 sync points |
| Large (10+) | 1 day/wave | 3-4 days | 2 sync points |

## Guardrails

**What this approach works well for:**
- Software development projects (20-200 tasks)
- Projects with clear technical dependencies
- Teams comfortable with upfront planning
- Need for predictable timelines

**What to avoid:**
- Exploratory research projects (too much uncertainty)
- Very small projects (<20 tasks) 
- Rapidly changing requirements
- Teams preferring continuous delivery over batched releases

## Success Metrics

**Coordination Efficiency:**
- Meeting time reduced by 70-90%
- Developer interruptions reduced by 80%
- Context switching minimized

**Delivery Predictability:**
- Timeline accuracy within 10-20% of estimates
- Scope completion rate >90%
- Technical debt accumulation minimal

**Team Satisfaction:**
- Less time in coordination meetings
- Clearer individual task ownership
- Predictable handoff points

## Implementation Notes

**Dependency Inference:**
- Keywords: "requires", "depends on", "needs", "after"
- Technical patterns: testing depends on implementation
- Infrastructure patterns: deployment depends on code completion

**Wave Balancing:**
- Target 5-20 tasks per wave
- Avoid single-task waves (merge with adjacent)
- Balance complexity across waves when possible

**Error Handling:**
- Circular dependencies → suggest task splitting
- Unbalanced waves → recommend task rebalancing  
- Missing dependencies → flag for human review

## Getting Started

1. **Prepare your specification:**
   - List concrete tasks with clear outcomes
   - Include acceptance criteria where possible
   - Mention known technical dependencies

2. **Run the command:**
   ```bash
   claude /plan-wave-execution --spec your-requirements.md --team-size 5
   ```

3. **Review the generated plan:**
   - Validate dependencies make technical sense
   - Adjust wave boundaries if needed
   - Confirm team assignments work for your context

4. **Execute wave by wave:**
   - Start Wave 1 with all assigned teams
   - Complete ALL Wave 1 tasks before starting Wave 2
   - Use sync points for quality checks and planning adjustments

## Common Patterns

**Research → Implementation → Testing:**
```
Wave 1: Research, design, planning
Wave 2: Core implementation, basic testing
Wave 3: Integration, documentation, deployment
```

**Infrastructure → Features → Polish:**
```
Wave 1: Platform setup, tooling, architecture
Wave 2: Feature development, unit testing
Wave 3: Integration testing, performance, docs
```

**Frontend/Backend Parallel:**
```
Wave 1: API design, UI mockups (can parallelize)
Wave 2: Backend implementation, Frontend implementation  
Wave 3: Integration, end-to-end testing
```

---

**Ready to try it?** Prepare a requirements document with 20-100 concrete tasks and run:
```bash
claude /plan-wave-execution --spec requirements.md
```