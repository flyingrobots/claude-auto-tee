# Conclusion: PostToolUse Hook Strategy for Claude Auto-Tee

## Executive Summary

The expert panel achieved strong consensus that **PostToolUse hooks fundamentally change the solution architecture** for claude-auto-tee. Rather than relying on Claude to parse stderr messages, PostToolUse enables a robust hybrid architecture combining structured persistence with immediate context injection.

## Core Consensus: Hybrid Architecture

All five experts converged on a three-layer solution:

### Layer 1: Structured Capture Registry (PostToolUse)
- **Parse tool_response** to extract tee output paths from stderr
- **Write to JSON registry** at `~/.claude/captures.json`
- **Include metadata**: timestamp, command, size, hash, dependencies
- **Set environment variable** pointing to latest captures

### Layer 2: Immediate Context Injection  
- **Generate formatted context blocks** that appear in next Claude interaction
- **Visual delimiters** for cognitive optimization
- **Action-oriented prompts**: "Use `cat /tmp/xyz.log` for full output"
- **Automatic injection** via CLAUDE_CONTEXT or similar mechanism

### Layer 3: Intelligent Lifecycle Management
- **Track temporal validity** of captured output
- **Dependency tracking** between commands
- **Confidence scoring** based on age and system changes
- **Automatic invalidation** when dependencies change

## Implementation Strategy

### Phase 1: Minimum Viable Implementation (Week 1)
```bash
# PostToolUse hook pseudocode
1. Parse tool_response for "Full output saved to: PATH"
2. Extract PATH and metadata
3. Append to ~/.claude/captures.json
4. Set CLAUDE_LAST_CAPTURE=PATH
5. Generate context block for next interaction
```

### Phase 2: Enhanced Reliability (Week 2)
- Add structured stderr markers in PreToolUse
- Implement robust JSON registry with rotation
- Add visual context blocks with formatting
- Test cross-platform compatibility

### Phase 3: Intelligence Layer (Week 3+)
- Add dependency tracking
- Implement freshness scoring
- Create invalidation rules
- Add semantic enhancement

## Key Technical Insights

### 1. PostToolUse Changes Everything
**Expert 001**: "PostToolUse provides the missing piece - reliable post-execution processing with full access to tool_response, eliminating the fragile stderr parsing requirement."

### 2. Context Injection > Discovery
**Expert 004**: "Claude shouldn't have to discover captures - they should be immediately visible in context, making captured output feel more accessible than re-running."

### 3. Temporal Intelligence Critical
**Expert 005**: "Static captures become misleading over time. We must track dependencies and freshness to prevent Claude from using stale data."

### 4. Reliability Through Simplicity
**Expert 003**: "Start with bulletproof basics - file persistence and environment variables - before adding semantic layers."

### 5. Cognitive Optimization Matters
**Expert 002**: "Format captured output as 'enhanced context' that feels superior to raw command output, incentivizing reuse."

## Recommended Architecture

```
┌─────────────────┐
│  PreToolUse     │
│  (Inject tee)   │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  Command Exec   │
│  (With capture) │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  PostToolUse    │──> Parse stderr
│  (Process)      │──> Update registry
└────────┬────────┘──> Set env vars
         │           └─> Generate context
         v
┌─────────────────┐
│  Next Claude    │
│  Interaction    │<── Auto-injected context
└─────────────────┘<── Registry available
                    <── Env vars set
```

## Success Metrics

- **Primary**: 100% Claude awareness of captures (vs current 10% failure rate)
- **Secondary**: Zero unnecessary command re-runs
- **Tertiary**: <100ms overhead per capture
- **Operational**: Automatic cleanup of stale captures

## Risk Mitigation

### Technical Risks
- **Registry corruption**: Use atomic writes with backup
- **Context injection failure**: Fallback to environment variables
- **PostToolUse hook failure**: Graceful degradation to current behavior

### Operational Risks  
- **Disk space**: Implement rotation and cleanup
- **Stale context**: Freshness scoring and invalidation
- **Cross-platform issues**: Extensive testing matrix

## Final Recommendation

**Implement the hybrid architecture in three phases**, starting with PostToolUse registry management (Phase 1) to achieve immediate 100% capture awareness, then adding context injection (Phase 2) for cognitive optimization, and finally intelligence layers (Phase 3) for long-term reliability.

The availability of PostToolUse hooks transforms this from a "best effort" notification problem into a deterministic state management solution. The expert consensus strongly supports leveraging this capability for a robust, user-friendly implementation that eliminates command re-runs while maintaining operational reliability.

## Implementation Checklist

- [ ] Modify PostToolUse hook to parse tool_response
- [ ] Implement JSON registry at ~/.claude/captures.json  
- [ ] Add environment variable export (CLAUDE_CAPTURES)
- [ ] Create context injection mechanism
- [ ] Add visual formatting for context blocks
- [ ] Implement cleanup and rotation
- [ ] Add dependency tracking
- [ ] Create freshness scoring
- [ ] Test cross-platform compatibility
- [ ] Document for users

This solution leverages PostToolUse's capabilities to create a superior user experience where Claude always knows about captured output and actively prefers using it over re-running commands.