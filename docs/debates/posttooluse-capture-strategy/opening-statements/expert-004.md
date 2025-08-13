# Expert 004 Opening Statement: AI System Prompts and Information Presentation Optimization

## Problem Analysis from AI Systems Perspective

The core challenge is fundamentally about **information flow and cognitive load optimization** in human-AI interaction. From my expertise in AI system prompts and information presentation, the problem breaks down into three critical information architecture issues:

### 1. Information Persistence vs Working Memory Limitations

Claude operates with session-based working memory, not persistent state. The current approach relies on Claude parsing stderr messages and "remembering" capture paths - this creates a **fragile cognitive dependency** that inevitably fails due to:

- **Context window pressure** as conversations grow longer
- **Attention dilution** when multiple tools generate output simultaneously  
- **Memory decay** between tool invocations
- **Interference patterns** when stderr contains multiple file paths

### 2. Cognitive Load Distribution Problem

The current system places the burden of **discovery and state management** entirely on Claude's reasoning layer. This is suboptimal because:

- It requires Claude to actively parse, extract, and retain file paths
- It competes with the primary task focus (analyzing command output)
- It creates **dual-purpose attention splitting** between content analysis and metadata tracking
- It lacks **systematic reinforcement patterns** that would strengthen memory retention

### 3. Information Architecture Anti-Pattern

The current design exhibits a classic **"pull-based discovery"** anti-pattern where the consumer (Claude) must actively seek and maintain awareness of available resources, rather than having them **systematically presented** in the optimal cognitive format.

## Optimal Strategy: Context-Aware Information Injection

Based on AI system optimization principles, the solution should implement **proactive context enhancement** rather than reactive discovery:

### Core Strategy: PostToolUse Context Injection

**PostToolUse Hook Should Create Structured Metadata Supplements**

1. **Parse** `tool_response.stderr` for capture file paths
2. **Validate** capture file existence and readability  
3. **Generate** structured context blocks that will be **automatically visible** to Claude
4. **Inject** formatted metadata into the command output stream

### Implementation Framework

```bash
# PostToolUse Hook Pseudo-Implementation
if [[ "$tool_name" == "Bash" ]]; then
    # Extract capture paths from stderr
    capture_paths=$(echo "$stderr" | grep -o "Full output saved to: [^[:space:]]*" | cut -d' ' -f5-)
    
    if [[ -n "$capture_paths" ]]; then
        # Generate structured context block
        context_block="
═══════════════════════════════════════════════════════════════
🔄 CLAUDE-AUTO-TEE CAPTURE METADATA
═══════════════════════════════════════════════════════════════

CAPTURED OUTPUTS AVAILABLE:
$(format_capture_list "$capture_paths")

USAGE INSTRUCTIONS:
• Use 'Read' tool with these paths to access full output
• Files contain complete stdout/stderr (including truncated content)  
• Paths are absolute and immediately accessible

═══════════════════════════════════════════════════════════════
"
        # Append to tool output for guaranteed visibility
        echo "$context_block" >> "$session_metadata_file"
    fi
fi
```

### Why This Approach Optimizes AI Cognitive Patterns

1. **Visual Prominence**: Structured formatting with clear boundaries ensures information doesn't blend into output noise

2. **Cognitive Priming**: Context blocks activate the "file operation" reasoning pathway before Claude analyzes primary output

3. **Reduced Working Memory Load**: Eliminates need for Claude to parse, extract, and retain file paths

4. **Systematic Reinforcement**: Every capture generates consistent, formatted metadata that reinforces usage patterns

5. **Zero Discovery Overhead**: Information is **pushed** to Claude rather than requiring active discovery

### Information Presentation Optimization Principles

**Format Design for Maximum Cognitive Impact:**

- **High-contrast visual boundaries** (box characters, consistent spacing)
- **Semantic grouping** (paths, instructions, metadata separated)
- **Action-oriented language** ("Use 'Read' tool..." not "Files available...")
- **Context-aware sizing** (brief for single captures, detailed for multiple)
- **Progressive disclosure** (essential info first, details follow)

## Proposed Voting Options

Based on optimal information architecture principles:

**Option A: Context Injection Strategy**
- PostToolUse generates formatted context blocks
- Blocks appended to tool output for guaranteed visibility
- Standardized format optimizes Claude's file operation reasoning

**Option B: Environment Metadata Strategy**  
- PostToolUse writes structured metadata files
- Environment variables point Claude to metadata locations
- Requires explicit discovery but provides rich contextual data

**Option C: Hybrid Push-Pull Strategy**
- Immediate context injection for current captures
- Persistent registry for cross-session discovery
- Optimizes both immediate awareness and long-term accessibility

## Success Criteria from AI Systems Perspective

1. **Cognitive Load Reduction**: Claude should never need to parse stderr for file paths
2. **Attention Optimization**: File awareness should enhance, not compete with, primary task focus  
3. **Pattern Recognition**: Consistent information formatting should strengthen usage patterns over time
4. **Zero Cognitive Overhead**: Available captures should be immediately apparent without discovery effort
5. **Scalable Information Architecture**: Approach should work with 1 capture or 20 captures equally well

The optimal solution treats this as an **information presentation problem** rather than a state management problem, leveraging how AI systems naturally process structured context to achieve reliable awareness without cognitive burden.