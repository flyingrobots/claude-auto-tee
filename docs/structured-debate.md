# Structured Expert Debate System

A sophisticated multi-agent consultation framework for making complex technical decisions through structured debate, polling, and rationale-based voting.

## Overview

The Structured Expert Debate System allows Claude to consult multiple specialized sub-agents to make informed technical decisions. Each expert brings domain expertise and engages in structured rounds of debate with dynamic extension mechanisms and transparent voting.

## Procedure

### 1. Setup Phase
Create debate directory structure:
```
docs/debates/{topic}/
├── problem-statement.md
├── debate-setup.md
├── opening-statements/
├── round-1/
├── round-N/
├── final-statements/
├── vote/
├── closing-statements/
└── conclusion.md
```

### 2. Problem Statement
Write a clear problem statement in `docs/debate/problem-statement.md` including:
- Context and background
- Specific decision points  
- Success criteria
- Constraints or requirements

### 3. Expert Selection & Anonymous Assignment
Claude selects appropriate experts from available sub-agents based on the problem domain. Requirements:
- Minimum 3 experts, maximum 7 experts
- Must be an odd number (3, 5, 7) to prevent ties
- No duplicate expert types
- Choose experts with relevant domain expertise for the specific problem

Create `docs/debate/debate-setup.md` with anonymous expert assignments:
```
# Debate Setup

## Expert Assignments
- **Expert 001**: [actual-subagent-type] - [brief domain description]
- **Expert 002**: [actual-subagent-type] - [brief domain description]  
- **Expert 003**: [actual-subagent-type] - [brief domain description]
- **Expert 004**: [actual-subagent-type] - [brief domain description]
- **Expert 005**: [actual-subagent-type] - [brief domain description]

## Debate Order
Randomized presentation order: Expert 003, Expert 001, Expert 005, Expert 002, Expert 004

## Rules
- Experts identify only by number (001, 002, etc.) during debate
- Domain expertise revealed only in setup document
- Arguments evaluated on merit, not authority
```

### 4. Opening Statements Phase
**⚠️ CRITICAL: Launch ALL experts simultaneously in a SINGLE message**

Create opening statement prompt template:
```
You are Expert [ID] participating in a structured technical debate.

DEBATE RULES:
- You are Expert [ID] - use only this identifier throughout
- This is the Opening Statements phase
- Provide your initial perspective based on your domain expertise
- Do not read other expert statements (none exist yet)
- Include proposed voting options if you have suggestions

QUESTION: [Problem statement content]

Your expertise areas: [Domain-specific concerns from debate-setup.md]

Provide your opening statement as a structured markdown document.
```

Launch all experts in ONE function_calls block using the Task tool.

### 5. Regular Rounds (with Extension Voting)
Each regular round follows this pattern:

**Round Prompt Template:**
```
You are Expert [ID] in Round [N] of a structured technical debate.

DEBATE RULES:
- You are Expert [ID] - use only this identifier
- Read ALL statements from round [N-1] before responding
- Provide your perspective considering other expert input
- Include extension vote: YES (continue debate) or NO (proceed to finals)
- Include brief reason for extension vote
- Propose voting options if you have suggestions

REQUIRED READING: [List all files from previous round]

QUESTION: [Problem statement content]

Your Round [N] response must include:
## My Perspective
[Your argument]

## Extension Vote
**Continue Debate**: [YES/NO]
**Reason**: [Brief explanation]

## Proposed Voting Options (if any)
- Option A: [Description]
- Option B: [Description]
```

**Extension Logic**: Continue to next round if MAJORITY of experts vote YES. Proceed to finals when majority votes NO. If tied, Claude the moderator casts the deciding vote with recorded rationale.

### 6. Final Statements Phase
**No extension voting allowed in this phase**

**Final Statement Prompt Template:**
```
You are Expert [ID] providing your Final Statement in a structured technical debate.

DEBATE RULES:
- You are Expert [ID] - use only this identifier
- Read ALL statements from ALL previous rounds
- Provide your final perspective and recommendation
- NO extension voting (this is the final argument phase)
- Synthesize key points from the entire debate

REQUIRED READING: [List all files from all rounds]

QUESTION: [Problem statement content]

Provide your final statement considering the complete debate history.
```

### 7. Vote Phase
**Vote Prompt Template:**
```
You are Expert [ID] voting in a structured technical debate.

DEBATE RULES:
- You are Expert [ID] - use only this identifier
- Read ALL final statements from ALL experts first
- Vote for your preferred option with detailed rationale
- Explain key factors that influenced your decision
- Reference other experts' arguments that swayed you

REQUIRED READING: [List all final statement files]

VOTING OPTIONS:
[List synthesized options from all rounds]

Your vote must include:
## Vote
**Choice**: [Selected option]
**Rationale**: [Detailed reasoning considering all expert input]
**Key Factors**: 
- [Factor 1]
- [Factor 2]
- [Factor 3]
```

If the vote results in a tie, Claude the moderator casts the deciding vote with recorded rationale.

### 8. Closing Statements Phase
**Closing Statement Prompt Template:**
```
You are Expert [ID] providing your Closing Statement in a structured technical debate.

DEBATE RULES:
- You are Expert [ID] - use only this identifier
- The vote has concluded with [RESULT]
- This is your opportunity to make final remarks for the record
- Particularly important for dissenting opinions
- Read the vote results and winning rationale first

REQUIRED READING: [List all vote files and results]

Provide your closing statement reflecting on:
- The debate process and outcome
- Key insights gained from other experts
- Final thoughts on the winning/losing positions
- Any concerns or endorsements for the record
```

### 9. Conclusion Phase
Analyze all votes, rationales, and closing statements to create `docs/debate/conclusion.md`:
- Vote tally and winning option
- Any tie-breaking votes cast by Claude the moderator
- Summary of key arguments from each expert (by ID)
- Synthesis of rationales and closing statements
- Final recommendation with implementation notes

## ⚠️ Critical Rules

### Parallel Agent Execution
**YOU MUST LAUNCH ALL AGENTS IN A SINGLE MESSAGE FOR PARALLEL EXECUTION**

Never launch agents sequentially:
```
❌ Launch Agent 1... wait for response
❌ Launch Agent 2... wait for response  
❌ Launch Agent 3... wait for response
```

Always launch all agents simultaneously:
```
✅ Single function_calls block with N Task tool invocations (where N = number of experts)
```

### Anonymous Expert Protocol
- Experts identify only by assigned numbers (Expert 001, Expert 002, etc.)
- Domain expertise revealed only in `debate-setup.md`
- No expert may reference their actual sub-agent type during debate
- Arguments evaluated on merit, not authority

### File Management
- Each expert writes to their own file per phase using their assigned ID
- No file collisions or overwrites
- Directory structure prevents conflicts
- All files preserved for transparency

### Reading Requirements  
- Opening: No required reading
- Round N: Must read ALL files from round N-1
- Finals: Must read ALL files from ALL previous rounds
- Vote: Must read ALL final statements
- Closing: Must read vote results and all vote rationales

### Extension Voting & Tie-Breaking
- Required in regular rounds only
- MAJORITY of experts voting YES continues debate
- Majority voting NO proceeds to finals
- If extension vote tied: Claude the moderator decides with recorded rationale
- If final vote tied: Claude the moderator decides with recorded rationale
- Claude may ONLY participate to break ties - no other debate participation allowed

### Moderator Tie-Breaking Protocol
When Claude must cast a tie-breaking vote, the decision must be recorded in a separate file:
```
# Moderator Tie-Breaking Decision

## Context
[Description of the tied vote]

## Vote Breakdown
[Show the tied results]

## Moderator Decision
**Choice**: [Selected option]
**Rationale**: [Detailed reasoning for the decision]
**Key Factors Considered**: [List main decision factors]
```

## Example File Naming
```
docs/debates/activation-strategy/opening-statements/expert-001.md
docs/debates/activation-strategy/round-1/expert-002.md
docs/debates/activation-strategy/final-statements/expert-003.md
docs/debates/activation-strategy/vote/expert-004.md
docs/debates/activation-strategy/closing-statements/expert-005.md
docs/debates/activation-strategy/moderator-tiebreak.md (if needed)
```

## Command Interface

### Basic Usage
```bash
/structured-debate "How should claude-auto-tee activation strategy work?"
```

### Advanced Usage with Flags
```bash
/structured-debate "How should claude-auto-tee work?" --experts=5 --include=security-auditor,performance-engineer --exclude=frontend-developer
```

### Interactive Mode
```bash
/structured-debate
# Claude responds: "What technical decision do you need expert consultation on?"
# User: "How should claude-auto-tee activation work?"
# Claude: "I suggest 5 experts: security-auditor, performance-engineer, devops-troubleshooter, architect-reviewer, javascript-pro. Proceed? (y/n/customize)"
```

### Command Parameters

| Flag | Purpose | Example |
|------|---------|---------|
| `--experts=N` | Force specific number (3,5,7) | `--experts=7` |
| `--include=X,Y` | Force specific expert types | `--include=security-auditor,performance-engineer` |  
| `--exclude=X,Y` | Exclude specific expert types | `--exclude=frontend-developer` |
| `--auto` | Skip confirmation, start immediately | `--auto` |
| `--dry-run` | Show proposed experts, don't start | `--dry-run` |

### Question Validation by Claude the Moderator

**Claude should validate the question and either:**

1. **Accept & Proceed**: Question is clear and technical
2. **Clarify**: "Your question is vague. Are you asking about [A] or [B]?"  
3. **Reject**: "This isn't a technical decision requiring expert debate. Consider a simpler approach."
4. **Refine**: "I understand you want X. Let me reframe this as: 'Should we implement X using approach A, B, or C?'"

### Example Interactions

```bash
# GOOD
/structured-debate "Should claude-auto-tee activate on all pipe commands or use pattern matching?"
# Claude: "Clear technical decision. Starting debate with 5 experts..."

# NEEDS CLARIFICATION  
/structured-debate "How should this work?"
# Claude: "Please specify what 'this' refers to and what specific decision needs expert input."

# REJECTED
/structured-debate "What's the best JavaScript framework?"
# Claude: "This is too broad for a structured debate. Could you ask about a specific technical decision for your project?"

# WITH FLAGS
/structured-debate "API design approach?" --experts=3 --include=backend-architect
# Claude: "Starting focused debate with 3 experts including backend-architect..."
```

### Recommended Command Evolution

**V1**: `/structured-debate "question"` - Claude picks everything  
**V2**: Add `--experts=N` flag for control  
**V3**: Add `--include`/`--exclude` for expert selection  
**V4**: Add interactive mode with confirmations  

## Command Integration
This system can be triggered via the `/structured-debate` command that:
1. Creates directory structure in `docs/debates/{topic}/`
2. Writes problem statement
3. Creates expert assignments with anonymous IDs
4. Executes the full debate protocol with all phases
5. Produces final conclusion and recommendation

## Phase Sequence Summary
```
Problem Statement → Expert Assignment → Opening Statements → 
Round 1 (with extension vote) → Round 2 (if majority extends) → 
... → Final Statements → Vote (with tie-break if needed) → 
Closing Statements → Conclusion
```