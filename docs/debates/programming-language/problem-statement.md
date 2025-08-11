# Programming Language Choice for Claude Auto-Tee

## Context and Background

Claude Auto-Tee is a bash command hook that automatically injects `tee` into bash commands to save full output while showing filtered results. This prevents expensive command re-runs by preserving complete output.

**Previous Expert Decision**: The activation strategy debate concluded with 4-1 consensus for **pure pipe-only detection** using AST-based parsing rather than regex pattern matching.

**Current Implementation**: Node.js with bash-parser library (hybrid strategy - to be replaced)

**Integration Context**: Claude Code pre-tool hook system that intercepts bash commands via JSON interface

## Specific Decision Points

**Primary Question**: What programming language should we use to implement claude-auto-tee?

**Available Options**:
1. **Node.js + bash-parser**: JavaScript with mature AST parsing library
2. **C/C++**: Native system language for maximum performance  
3. **Rust**: Systems language with memory safety and performance
4. **Go**: Compiled language with good JSON handling and cross-platform support
5. **Python**: Rapid development with potential bash parsing libraries

**Key Technical Requirements** (from activation strategy debate):
- AST-based bash command parsing (not regex)
- Cross-platform compatibility (Windows, Mac, Linux, containers) 
- Integration with Claude Code's JSON hook interface
- Pure pipe-only detection (simple activation strategy)
- Cross-platform temp file path generation
- Performance-critical (expert identified 25,000x performance difference)

## Success Criteria

The chosen language must:
- Support robust AST parsing of bash commands
- Handle JSON input/output for Claude Code integration
- Provide cross-platform file system operations
- Deliver optimal performance for pipe detection
- Enable reliable deployment across all target platforms
- Support the expert-recommended pure pipe-only activation strategy

## Constraints and Requirements

**Performance Requirements**:
- Previous tests showed pattern matching caused 25,000x performance degradation
- Pure pipe detection must be highly optimized
- Hook execution must be near-instantaneous

**Integration Requirements**:
- Must integrate with Claude Code's pre-tool hook system
- JSON input/output handling for hook data
- Cross-platform executable distribution

**Parsing Requirements**:
- AST-based bash parsing (expert consensus against regex)
- Handle complex shell constructs (pipes, redirections, command substitution)
- Reliable parsing across different shell variants

**Deployment Requirements**:
- Work across Windows, macOS, Linux, containers, CI/CD
- Simple installation and distribution model
- Minimal external dependencies

## Impact Assessment

**High Impact Decision**: This affects:
- Performance of every bash command that Claude Code users run
- Reliability of bash parsing across platforms
- Ease of installation and deployment
- Long-term maintainability of the codebase
- Ability to implement expert-recommended pure pipe-only detection

**Previous Context**: The activation strategy debate already established the importance of:
- Cross-platform reliability (Expert 004)
- Performance optimization (Expert 002)
- Security through simplicity (Expert 001)
- User experience predictability (Expert 003)
- Architectural maintainability (Expert 005)