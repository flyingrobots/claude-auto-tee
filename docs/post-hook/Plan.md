# PostToolUse Hook Implementation Plan

## Summary Metrics

- **Total Tasks**: 19
- **Total Dependencies**: 14 (hard edges in DAG)
- **Width (Max Parallelism)**: 6 tasks
- **Critical Path Length**: 3 phases
- **Edge Density**: 0.041 (well-structured, not over-constrained)
- **Verb-First Compliance**: 95%
- **Isolated Tasks**: 2 (P2.T001, P2.T006 - can start independently)

## Phase Distribution

- **Phase 1 (MVP)**: 7 tasks (P1.T001-P1.T007)
- **Phase 2 (Enhanced)**: 6 tasks (P2.T001-P2.T006)
- **Phase 3 (Intelligence)**: 6 tasks (P3.T001-P3.T006)

## Wave Schedule

### Wave 1: Foundation Components (Multi-Phase)
**Tasks**: 9 parallel tasks across all phases
- P1.T001: Implement capture path parser (Phase 1)
- P1.T002: Create registry schema (Phase 1)
- P1.T004: Implement environment exporter (Phase 1)
- P1.T005: Design basic context format (Phase 1)
- P2.T001: Add PreToolUse markers (Phase 2)
- P2.T006: Handle Unicode paths (Phase 2)
- P3.T001: Design dependency schema (Phase 3)
- P3.T003: Implement freshness scorer (Phase 3)
- P3.T005: Build semantic extractor (Phase 3)

**Duration Estimates** (hours):
- P50: 5.0
- P80: 6.7
- P95: 8.8

**Barrier**: Quorum 95% (W1→W2-q95)
- Timeout: 480 minutes
- Fallback: deferOptional

### Wave 2: Core Implementation
**Tasks**: 6 parallel tasks
- P1.T003: Build registry manager (Phase 1)
- P1.T006: Build context generator (Phase 1)
- P2.T002: Implement file locking (Phase 2)
- P2.T003: Add registry compression (Phase 2)
- P2.T004: Enhance visual formatting (Phase 2)
- P3.T002: Build dependency tracker (Phase 3)

**Duration Estimates** (hours):
- P50: 6.0
- P80: 7.0
- P95: 8.3

**Barrier**: Quorum 95% (W2→W3-q95)
- Timeout: 480 minutes
- Fallback: deferOptional

### Wave 3: Integration Layer
**Tasks**: 2 parallel tasks
- P1.T007: Create PostToolUse hook handler (Phase 1 - PRIMARY INTEGRATION)
- P3.T006: Create search index (Phase 3)

**Duration Estimates** (hours):
- P50: 5.0
- P80: 6.3
- P95: 8.0

**Barrier**: Quorum 95% (W3→W4-q95)
- Timeout: 300 minutes
- Fallback: deferOptional

### Wave 4: Validation & Intelligence
**Tasks**: 2 parallel tasks
- P2.T005: Test cross-platform paths (Phase 2)
- P3.T004: Create invalidation rules (Phase 3)

**Duration Estimates** (hours):
- P50: 5.0
- P80: 5.8
- P95: 7.0

**Barrier**: Full 100% (W4-final)
- Timeout: 420 minutes
- Fallback: halt

## Sync Points & Quality Gates

### Wave 1 → Wave 2 Gate
✅ **Parser functional**: `npm test -- parser` >= 95% pass rate
✅ **Schema defined**: `schemas/registry.json` exists
✅ **Environment vars work**: `test -n "$CLAUDE_LAST_CAPTURE"` succeeds
✅ **Context format documented**: `docs/context-format.md` exists
✅ **Dependency schema ready**: `schemas/dependency.json` exists

### Wave 2 → Wave 3 Gate
✅ **Registry operational**: `npm test -- registry` >= 95% pass rate
✅ **Context generation working**: `npm test -- context` >= 95% pass rate
✅ **File locking tested**: Concurrent write safety <= 100
✅ **Compression effective**: Compression ratio <= 0.5
✅ **Dependency tracking functional**: `npm test -- dependency` >= 95% pass rate

### Wave 3 → Wave 4 Gate
✅ **Integration complete**: `npm test -- integration` >= 95% pass rate
✅ **PostToolUse handler stable**: All Phase 1 interfaces integrated
✅ **Search index operational**: Search latency <= 50ms
✅ **Core MVP functional**: Phase 1 complete and tested

### Wave 4 → Complete Gate
✅ **Cross-platform validated**: `npm test -- platform` 100% pass rate
✅ **Unicode support verified**: `npm test -- unicode` 100% pass rate
✅ **Invalidation rules active**: `npm test -- invalidation` >= 95% pass rate
✅ **Freshness accuracy achieved**: >= 90% accuracy metric
✅ **All phases complete**: P1, P2, P3 features operational

## Low-Confidence Dependencies

The following dependency was excluded from the DAG due to confidence < 0.7:

| From | To | Type | Confidence | Reason |
|------|-----|------|------------|---------|
| P2.T001 | P1.T001 | knowledge | 0.6 | Markers inform parser design but not required |

This knowledge dependency indicates that PreToolUse markers (P2.T001) could inform parser design (P1.T001), but both can proceed independently in Wave 1.

## Parallelizable/Soft Dependencies

The following soft dependencies (isHard=false) allow parallel execution:

| From | To | Type | Confidence | Reason |
|------|-----|------|------------|---------|
| P1.T003 | P2.T002 | technical | 0.85 | File locking enhances registry manager |
| P1.T003 | P2.T003 | technical | 0.8 | Compression enhances registry manager |
| P1.T005 | P2.T004 | sequential | 0.75 | Enhanced formatting builds on basic format |

These represent optional enhancements:
- File locking (P2.T002) and compression (P2.T003) improve the registry but aren't required
- Enhanced formatting (P2.T004) extends basic format but both can proceed independently

## Phase Completion Milestones

### Phase 1 Complete (End of Wave 3)
- Core PostToolUse handler operational
- Registry persistence working
- Environment variables set
- Basic context injection functional
- **Deliverable**: MVP with 100% capture awareness

### Phase 2 Complete (End of Wave 4)
- Cross-platform validation passed
- File locking and compression active
- Enhanced visual formatting
- Unicode support verified
- **Deliverable**: Production-ready with robustness

### Phase 3 Complete (End of Wave 4)
- Dependency tracking operational
- Freshness scoring active
- Invalidation rules enforced
- Semantic search available
- **Deliverable**: Intelligent lifecycle management

## Risk Mitigation

### Technical Risks
1. **Integration complexity** (P1.T007)
   - Isolated in Wave 3 after dependencies ready
   - All required interfaces available from Wave 2

2. **Cross-platform issues** (P2.T005)
   - Dedicated testing in Wave 4
   - Platform-specific handlers in P2.T006

3. **Performance overhead**
   - Compression (P2.T003) mitigates registry size
   - Search index (P3.T006) optimizes lookups

### Schedule Risks
1. **Phase interdependencies**
   - Phases can progress in parallel
   - Only P1.T007 blocks Phase 2 testing

2. **Intelligence layer complexity**
   - Phase 3 tasks isolated from core functionality
   - Can be deferred if needed without breaking MVP

## Auto-Normalization Actions

No auto-normalization was required. All tasks fall within the 2-8 hour target range, properly distributed across three implementation phases.