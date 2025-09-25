# T.A.S.K.S: Tasks Are Sequenced Key Steps – LLM Execution Spec (v1, tool-free)

_This command makes the LLM simulate feature extraction → tasklist → deps → DAG (with transitive reduction) → waves (Kahn antichains) → sync points, with evidence + confidence and basic timeline stats._

## Mission

From a raw tech plan doc, produce a validated execution plan:
1. extract features → break into tasks
2. infer structural dependencies (no resource edges)
3. build an acyclic, reduced DAG
4. generate waves via Kahn layering and basic balancing
5. propose sync points with quality gates
6. output artifacts as JSON/Markdown

### Hard Rules

- No chain-of-thought in outputs. Do private reasoning; output only the artifacts.
- Grounding required. Each task and each dependency must cite at least one evidence snippet (quote or char offsets).
- Ban “resource” dependencies. Edges represent technical/sequential/infra/knowledge only.
- ID direction = prereq → dependent.
- Granularity target: 2–8h typical (cap 16h). Split/merge to hit it.
- Confidence: [0..1] for each edge; treat < 0.7 as speculative during reporting (keep them visible, exclude from DAG build unless explicitly included).

### Inputs

- PLAN_DOC (raw text/markdown).
- Optional: MIN_CONFIDENCE (default 0.7), MAX_WAVE_SIZE (default 30).

#### Required Outputs (exact file fences)
1. ---file:features.json
2. ---file:tasks.json
3. ---file:dag.json
4. ---file:waves.json
5. ---file:Plan.md

### Schemas

#### features.json

```
{
  "features": [
    {
      "id": "F001",
      "title": "short name",
      "description": "1-3 sentences",
      "priority": "critical|high|medium|low",
      "source_evidence": [{"quote":"...", "loc":{"start":123,"end":178}}]
    }
  ]
}
```

#### tasks.json

```
{
  "meta": { "min_confidence": 0.7, "notes": "assumptions if any" },
  "tasks": [
    {
      "id": "P1.T001",
      "feature_id": "F001",
      "title": "verb-first outcome",
      "description": "what artifact/contract/code is produced",
      "category": "foundation|implementation|integration|optimization",
      "skillsRequired": ["backend","node"],
      "duration": {"optimistic":2, "mostLikely":4, "pessimistic":8},
      "acceptance_checks": ["tests / contracts / docs"],
      "source_evidence": [{"quote":"...", "loc":{"start":200,"end":240}}],
      "contentHash": "<sha1(title+desc)>"
    }
  ],
  "dependencies": [
    {
      "from":"P1.T001","to":"P1.T002",
      "type":"technical|sequential|infrastructure|knowledge",
      "reason":"why T002 requires T001",
      "evidence":[{"type":"doc|code|human|history","reason":"...", "confidence":0.9}],
      "confidence":0.85,
      "isHard": true
    }
  ]
}
```

#### dag.json

```
{
  "ok": true,
  "errors": [],
  "warnings": [],
  "metrics": {
    "nodes": 84, "edges": 121, "density": 0.017,
    "width": 18, "longestPath": 7, "isolatedTasks": 0,
    "lowConfidenceEdgesExcluded": 6
  },
  "topo_order": ["P1.T005","P1.T001","..."],
  "reduced_edges_sample": [["P1.T001","P1.T010"], ["P1.T010","P1.T020"]]
}
```

#### waves.json

```
{
  "planId": "PLAN-YYYYMMDD",
  "config": {"maxWaveSize": 30, "barrier": {"kind":"quorum","quorum":0.95}},
  "waves": [
    {
      "waveNumber": 1,
      "tasks": ["P1.T005","P1.T001","..."],
      "estimates": {"p50Hours": 10.5, "p80Hours": 12.0, "p95Hours": 14.2},
      "barrier": {"kind":"quorum","quorum":0.95}
    }
  ]
}
```

#### Plan.md (sections required)

- Header metrics (nodes, edges, width, longest path, density)
- Wave list with barriers and P50/P80/P95
- Sync Points & Quality Gates (checklists)
- Low-confidence edges table for review

## Algorithm (the model must simulate these steps)

### 1) Feature extraction

- Pull 5–25 features from PLAN_DOC: user-visible capabilities + enabling infrastructure.
- Each: title, 1–3 sentence description, priority, at least one evidence snippet.

### 2) Task breakdown (MECE)

- For each feature, create tasks (2–8h typical; cap 16h).
- Each task: skillsRequired[], PERT durations {a,m,b}, acceptance checks.
- Ensure MECE ownership (no overlap). If overlap detected, refactor and note in tasks.json.meta.notes.

### 3) Dependency discovery (structural only)

- Classify edges as:
	- technical (interfaces/artifacts/contracts required),
	- sequential (information/order),
	- infrastructure (env/tools),
	- knowledge (research/learning).
- Edge direction = prereq → dependent.
- Add reason, evidence[], and confidence ∈ [0,1].
- Keep speculative edges (confidence < min_confidence) in output, but they’ll be excluded from the built DAG.

### 4) DAG build + transitive reduction

- Filter edges: include only confidence ≥ min_confidence for the graph.
- Cycle check: If cycles exist, rewrite by splitting tasks or inserting intermediate artifacts; repeat until acyclic.
- Topological order: Kahn’s algorithm.
- Transitive reduction: remove edge (u,v) if another path u -> ... -> v exists (keep minimal edges).
- Compute metrics: nodes, edges, density = edges / (nodes*(nodes-1)), width (max antichain size), longest path length, isolated tasks.
- Heuristics: density < 0.05 → likely missing deps (warn). > 0.5 → over-constrained (warn).

### 5) Wave generation (Kahn antichains + balancing)

- Layering: Iteratively select zero-in-degree nodes → that set is Wave k; remove them; repeat.
- Balance:
	- If a wave has > MAX_WAVE_SIZE, split by (a) category mix and (b) “priority” = longest path distance to any sink (higher first).
	- If a wave has < 5 tasks and the next wave’s tasks have no extra prereqs, merge waves.
- Wave duration estimates (no Monte Carlo): For each task:
	- PERT mean μ = (a + 4m + b)/6, std σ = (b - a)/6.
	- Wave p50 ≈ max_i μ_i
	- Wave p80 ≈ max_i (μ_i + 0.84·σ_i)
	- Wave p95 ≈ max_i (μ_i + 1.65·σ_i)

(We’re approximating the max of independent task durations—good enough for planning.)

### 6) Sync points & gates
- Between each wave k → k+1 define a barrier:
- Default: quorum with quorum = 0.95 (95% of wave tasks done).
- Use full barrier only if interfaces are tightly coupled.
- Quality gate checklist (machine-checkable where possible). Example:
	- ✅ Unit/integ tests green (thresholds)
	- ✅ Contracts/API docs published
	- ✅ Lint/static analysis passing
	- ✅ Perf baseline captured (if applicable)
	- ✅ Security scan clean or waivers recorded

## Output Procedure (model must follow in one pass)

1.	Emit features.json.
2.	Emit tasks.json (with all deps, including low-confidence).
3.	Build DAG in-model using only edges with confidence ≥ min_confidence; resolve cycles; compute metrics; emit dag.json.
4.	Generate waves per algorithm; emit waves.json.
5.	Emit Plan.md:
	- Summary metrics
	- Waves with P50/P80/P95 and barrier kind
	- Sync Points & Quality Gates (short, specific checklists)
	- Table of low-confidence edges (from tasks.json.dependencies with confidence < min_confidence), to review.

## System Prompt (paste this as system)

```
You are a planning engine that simulates a project planning CLI.
Produce ONLY the requested artifacts (JSON/Markdown) in file fences.
Do not reveal intermediate reasoning or chain-of-thought.
All tasks and edges must include evidence from the source document.
Edges must be structural (technical, sequential, infrastructure, knowledge); resource constraints are disallowed.
Enforce dependency direction as prereq → dependent.
Target task granularity 2–8h (cap 16h); split/merge as needed.
Use min_confidence (default 0.7) to exclude low-confidence edges from the built DAG, but list them for human review.
Generate waves using Kahn layering; apply simple balancing; compute wave P50/P80/P95 using PERT approximations.
```

## User Prompt Template

```
MIN_CONFIDENCE: {0.7 or custom}
MAX_WAVE_SIZE: {30 or custom}

INPUT DOCUMENT:
<<<
{PLAN_DOC}
>>>

Produce artifacts in this order and format:
---file:features.json
{...}
---file:tasks.json
{...}
---file:dag.json
{...}
---file:waves.json
{...}
---file:Plan.md
(markdown)
```


## Sanity Checklist (the model should self-verify before emitting)

- No cycles; dag.json.ok == true.
- No “resource” edges.
- ≥70% tasks have durations; no task mean > 16h unless justified.
- Wave 1 width > 1 unless problem is inherently serial.
- Each wave has a barrier; defaults to quorum 95%.
- Low-confidence edges table present in Plan.md.

## Scoring Rubric + Evaluator Spec

Use this to auto-check outputs and reject bad runs. It’s strict where it should be, flexible where it matters.

### Simulated-Planctl Evaluator (v1)

What it judges

Artifacts expected from the model:

- features.json
- tasks.json
- dag.json
- waves.json
- Plan.md

If any are missing → auto-reject.

### Hard fails (auto-reject, no debate)

1.	Cycles present: dag.json.ok != true or errors contains “cycle”.
2.	Resource edges used anywhere.
3.	Edge direction wrong (any dep where from == dependent or obvious invert).
4.	< 50% tasks have PERT durations.
5.	No evidence on any task or any dependency.
6.	Wave violations: a wave with > maxWaveSize and no split, or zero waves.

If any of the above hits → grade REJECT with reasons.

### Scoring rubric (100 points)

| Category | Weight | How to score |
|----------|--------|--------------|
| A. Structural Validity | 20 | +20 if acyclic, edges all structural (tech/sequential/infra/knowledge), no resource edges, from→to correct. Deduct 5 for each violation (min 0). |
| B. Coverage & Granularity | 15 | % tasks with durations (≥70% = full 5, 50–69% = 2, <50% = 0); median PERT mean in 2–8h (5 points if true; 2 if slight drift); outliers resolved (≥90% within 0.5–16h = 5, else 0–3). |
| C. Evidence & Confidence | 15 | Tasks with evidence (≥95% = 5, 80–94% = 3, else 0); deps with evidence (same scale, 5); low-confidence table present in Plan.md and min_confidence applied in DAG (5). |
| D. DAG Quality | 15 | Density in [0.05, 0.5] (5 if yes; 2 if warned but justified; 0 if egregious). Width > 1 in Wave 1 (5 if yes; 0 if inherently serial but not explained; 3 if explained). Longest path vs wave count plausible (5). |
| E. Wave Construction | 15 | Kahn layering respected (5), splits/merges sensible vs maxWaveSize (5), per-wave P50/P80/P95 present and monotonic (5). |
| F. Sync Points & Gates | 10 | Each boundary has barrier kind (quorum default 95% unless justified) (5), gate checklist is specific & machine-checkable (5). |
| G. MECE & Naming | 10 | No duplicate/overlapping tasks (5), verb-first titles and non-vague names (5). |

### Passing bands
- Excellent (90–100): Ship it.
- Good (80–89): Minor edits.
- Needs Work (70–79): Return with specific fixes.
- Reject (<70): Re-run generation.

## Metrics the evaluator should compute
- Durations coverage: count(tasks with duration)/count(tasks).
- PERT mean per task: (a + 4m + b)/6; median and outlier counts (<0.5h or >16h).
- Dependency sanity:
	- Count by type; ensure none are resource.
	- Evidence presence rate (tasks, deps).
	- Confidence distribution; count of < min_confidence.
- Graph stats (from dag.json or recomputed if needed):
	- nodes, edges, density edges/(n*(n-1)), width (max antichain), longest path, isolated tasks.
- Wave checks:
	- wave sizes vs config.maxWaveSize.
	- P50 ≤ P80 ≤ P95 for every wave.
- Barriers present and reasonable.

## Evaluator output schema

```
{
  "grade": "EXCELLENT | GOOD | NEEDS_WORK | REJECT",
  "score": 0,
  "reasons": ["short bullets of key issues"],
  "category_scores": {
    "A": 20, "B": 15, "C": 15, "D": 15, "E": 15, "F": 10, "G": 10
  },
  "metrics": {
    "tasks": 0,
    "durationsCoveragePct": 0,
    "pertMedian": 0,
    "outliersLow": 0,
    "outliersHigh": 0,
    "depsTotal": 0,
    "depsLowConfidence": 0,
    "evidenceCoverageTasksPct": 0,
    "evidenceCoverageDepsPct": 0,
    "dag": { "nodes":0, "edges":0, "density":0, "width":0, "longestPath":0, "isolated":0 },
    "waves": [
      {"waveNumber":1,"count":0,"p50":0,"p80":0,"p95":0,"barrier":"quorum","quorum":0.95}
    ]
  },
  "autoReject": false,
  "autoRejectReasons": []
}
```

## Evaluator steps (pseudo-logic)

1.	Presence check: all 5 artifacts exist → else REJECT.
2.	Parse JSON; basic schema checks (ids present, arrays, types).
3.	Hard-fail scan:
	- dag.json.ok !== true or “cycle” in errors → reject.
	- Any dep type resource or “resource” in reason/type → reject.
	- Durations coverage < 50% → reject.
	- Missing evidence in any task or any dependency → reject.
	- Wave count == 0, or any wave size > maxWaveSize without split → reject.
4.	Compute metrics (see above).
5.	Category scoring using the rubric; clamp each to [0, weight].
6.	Total score; assign band; include top 5 reasons (bullets).
7.	Return evaluation.json per schema.

## Quick heuristics the evaluator should use
- Verb-first titles: starts with a verb (regex-ish): 
```
/^(add|build|create|define|design|document|enable|export|generate|implement|integrate|migrate|publish|refactor|remove|rename|setup|test|upgrade)\b/i.
```
- Score partially if ≥80% pass.
- Overlap sniff: two tasks with >80% token overlap in titles → warn; if same feature_id and similar titles → deduct in G.
- Low-confidence table required: Plan.md must contain a section listing confidence < min_confidence edges. If absent but such edges exist in tasks.json → deduct in C.
- Density sanity:
	- < 0.05 → warn “likely missing deps”.
	- > 0.5 → warn “over-constrained”.
- Waves monotonicity: for each wave, check p50 ≤ p80 ≤ p95; else deduct in E.

## Minimal evaluator prompt (for an LLM judge)

### System
```
You are an exacting project plan evaluator. Read the five artifacts, compute the rubric scores, and output only evaluation.json per the schema. Do not include chain-of-thought. Be strict on hard fail rules.
```

### User

```
Artifacts:
---file:features.json
{...}
---file:tasks.json
{...}
---file:dag.json
{...}
---file:waves.json
{...}
---file:Plan.md
(markdown here)

Constraints:
- min_confidence default 0.7 unless meta overrides
- maxWaveSize default 30 unless config overrides

Now evaluate using the rubric and return a single JSON object:
(evaluation.json as per schema)
```


## Acceptance gates (use these in CI)
- Merge gate: grade ∈ {EXCELLENT, GOOD} and score ≥ 80.
- Soft gate (allow override): NEEDS_WORK with score ∈ [70,79] and no Hard fails.
- Fail: anything else.

## Common fix suggestions (auto-generate from failures)
- Cycles → “Split large tasks by artifact boundary; insert interface contracts as separate tasks; ensure direction prereq→dependent.”
- Sparse density → “Add explicit interface or infra deps; avoid hand-wavy sequencing.”
- Low durations coverage → “Add PERT durations to at least 70% of tasks; keep means 2–8h.”
- Evidence gaps → “Attach quoted spans (or offsets) for each task/edge; set confidence accordingly.”
- Waves too big → “Split by category and by longest-path priority; enforce maxWaveSize.”
