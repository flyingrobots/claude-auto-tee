# Claude Auto-Tee Activation Strategy Problem Statement

## Context and Background

Claude Auto-Tee is a bash command hook that automatically injects `tee` into bash commands to save full output while showing filtered results. This solves the common problem where users run expensive commands (like `npm run build | tail -10`), don't find what they need, and have to re-run the expensive command again.

**Current Implementation**: AST-based parser using bash-parser library with hybrid activation strategy

**Core Value Proposition**: Prevent expensive command re-runs by auto-saving complete output

## Specific Decision Points

**Primary Question**: What activation strategy should claude-auto-tee use?

**Available Options**:
1. **Pipe-Only Detection**: Activate on ANY command that contains pipes (e.g., `cmd | tail`, `cmd | grep`, `cmd | head`)
2. **Pattern Matching**: Activate only on specific command patterns (e.g., build tools, test runners, long-running processes)
3. **Hybrid Approach**: Combine both - pipes + pattern matching for optimal coverage

**Key Considerations**:
- Platform compatibility (Windows, Mac, Linux, containers, CI/CD)
- Performance impact of AST parsing
- User experience and transparency
- Edge cases and potential breaking scenarios
- Storage implications of auto-tee files

## Success Criteria

The chosen strategy must:
- Work reliably across all platforms where Claude Code operates
- Not break existing user workflows
- Provide clear value by preventing expensive re-runs
- Handle edge cases gracefully
- Be transparent to users (they should understand what's happening)

## Constraints and Requirements

- Must use AST parsing (not regex) for robust shell command analysis
- Must generate cross-platform temp file paths (`os.tmpdir()` not hardcoded `/tmp`)
- Must not interfere with interactive commands or shell sessions
- Must not activate in CI/CD environments where auto-fixing is inappropriate
- Must handle complex pipe chains and command substitutions correctly
- Should minimize false positives (unnecessary tee injection)
- Should minimize false negatives (missing valuable commands)

## Impact Assessment

**High Impact Decision**: This affects every bash command that Claude Code users run. Wrong choice could:
- Break user workflows
- Cause platform-specific failures  
- Create performance bottlenecks
- Generate unnecessary storage overhead
- Reduce user trust in the tool

**Timeline**: This is a foundational architectural decision that will be difficult to change once users adopt the tool.