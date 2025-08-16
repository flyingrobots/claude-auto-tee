---
expert_id: 001
phase: opening
mode: BLIND
timestamp_utc: 2025-01-13T15:50:00Z
sha256: [SHA_PENDING]
research_used: rr1-only
anonymity_rules_broken: false
---

**Position: PreToolUse hooks SHOULD include predicted capture paths with token-based coordination**

The evidence from existing implementations strongly supports path prediction in PreToolUse hooks. The current `pretooluse-markers.sh` already demonstrates sophisticated path prediction logic that mirrors the main script's timestamp-based generation, proving this approach is technically viable and actively implemented.

**Key Arguments:**

1. **Performance Optimization**: Early path prediction enables immediate resource allocation and validation. The current system already validates pipe detection, temp directory access, and file permissions during PreToolUse - extending this to full path prediction eliminates redundant work in PostToolUse hooks.

2. **State Consistency**: Token-based coordination solves the prediction accuracy problem. By embedding process IDs and timestamps (`enriched_path="${temp_file_path}#${process_id}#${timestamp}"`), the system maintains coordination between Pre and Post phases even when paths differ from predictions.

3. **Concurrent Execution Safety**: The existing `inject_concurrent_safe_marker()` function demonstrates that path prediction works reliably under rapid concurrent executions - a critical constraint for this system.

4. **Security Validation**: PreToolUse path prediction allows early security validation of capture destinations before execution begins, preventing potential injection attacks through malicious temp directories.

**Risk Mitigation:**
The main risk is prediction mismatches, but the existing cleanup mechanisms (`clean_concurrent_path()`) and fallback logic already handle this gracefully. The system degrades elegantly to PostToolUse-only behavior when predictions fail.

**Implementation Blueprint:**
Extend the existing marker enrichment pattern to include predicted paths while maintaining the current token-based coordination for mismatch recovery. This leverages proven architectural patterns already in production.

The codebase evidence shows this isn't theoretical - it's a working enhancement to existing infrastructure that addresses real performance and security requirements.