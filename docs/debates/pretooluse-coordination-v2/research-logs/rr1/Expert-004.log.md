---
expert_id: 004
round: rr1
timestamp: 2025-01-13T15:45:00Z
sha256: [SHA_PENDING]
---

# Research Log: PreToolUse Coordination with Predicted Capture Paths

## Query Plan

### Primary searches I would execute:
- `grep -rn "predict.*path\|path.*prediction" src/markers/` - Analyze current prediction implementation
- `grep -rn "temp.*file.*path\|timestamp.*generation" src/claude-auto-tee.sh` - Study main script path generation logic  
- `find test/ -name "*marker*" -o -name "*path*"` - Examine test coverage for path prediction accuracy
- `grep -rn "concurrent\|race.*condition\|atomic" src/` - Investigate concurrency handling mechanisms
- `rg "PostToolUse.*coordination|coordination.*PostToolUse" docs/` - Review existing coordination strategies

### Secondary investigations:
- Cross-platform timestamp generation differences (macOS vs Linux vs BSD)
- Marker injection failure modes and error handling
- File system race conditions between PreToolUse prediction and actual creation
- Impact of rapid concurrent executions on path uniqueness

## Expected Findings

### Path prediction algorithm analysis:
- Current implementation uses timestamp + random padding for uniqueness
- Cross-platform compatibility through `gdate` detection and fallbacks
- Normalization via `normalize_path()` for consistency
- Same logic replicated between PreToolUse markers and main script

### Coordination mechanisms:
- PreToolUse injects `# CAPTURE_START: <predicted_path>` to stderr
- Main script creates actual temp file with matching path generation
- PostToolUse processes actual path from `tool_response` parsing
- Legacy support for backward compatibility with existing markers

### Risk factors:
- Timestamp collision potential under high concurrency
- Cross-platform path normalization inconsistencies  
- Race conditions between prediction and file creation
- Marker injection failures due to stderr capture issues

## Key Takeaways

• **Path prediction is already implemented and functional** - The `predict_capture_path()` function in `pretooluse-markers.sh` replicates the main script's timestamp-based generation logic with cross-platform support

• **Coordination mechanism exists but is fragile** - PreToolUse predicts paths and injects markers, but relies on identical logic execution between prediction and actual creation, creating potential race conditions

• **Concurrency handling is limited** - While process ID and timestamp enrichment exists for concurrent safety, the core path prediction doesn't guarantee uniqueness under rapid concurrent execution

• **Cross-platform complexity is significant** - Different timestamp generation methods (`gdate`, `date +%s%3N`, fallback with `RANDOM`) create platform-specific behavior that could cause prediction mismatches

• **PostToolUse dependency creates coordination requirement** - Since PostToolUse processes actual paths from `tool_response`, any mismatch between predicted and actual paths breaks the coordination chain

## Concise Citations

1. **Existing Implementation**: `src/markers/pretooluse-markers.sh:78-113` - `predict_capture_path()` function implementing cross-platform timestamp-based path generation with normalization
2. **Coordination Pattern**: `src/markers/pretooluse-markers.sh:312-323` - PreToolUse marker injection using predicted paths with pipe detection and security validation  
3. **PostToolUse Context**: `docs/debates/posttooluse-capture-strategy/conclusion.md:125` - Implementation checklist showing PostToolUse hook parsing `tool_response` for actual paths, requiring coordination with PreToolUse predictions