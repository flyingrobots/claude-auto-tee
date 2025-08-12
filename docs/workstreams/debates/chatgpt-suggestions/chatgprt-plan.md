GitHub-Native Wave Coordination — Implementation Spec

Scope: Build a zero-friction, auditable, GitHub-only system to coordinate dependency-driven waves of work.
Core idea: One Wave Coordination Issue per wave; teams signal via slash commands; a bot validates readiness (tasks closed via merged PRs + checks green), updates a pinned JSON state block, and announces the transition when all teams are ready.
No emojis. No sidecar infra. No local ready.txt.

⸻

Why this works
	•	Single source of truth: GitHub issues/PRs, comments, and checks are canonical + auditable.
	•	Low noise: One pinned JSON state block edited in place + concise bot comments.
	•	Deterministic gates: Readiness is validated, not self-declared.
	•	Scales linearly: Add teams, not meetings.

⸻

1) Glossary
	•	Plan: A set of waves (e.g., “Phase 1”) tracked in tasks.yaml.
	•	Wave n: A dependency frontier executed in parallel by multiple teams.
	•	Team: A named group: alpha, beta, gamma (configured).
	•	Task: A GitHub issue with task_id (e.g., P1.T024) owned by a team and assigned to a wave.
	•	Coordination Issue: A single GH issue per wave used as the hub (commands, status, announcements).
	•	Coordinator: The bot (GitHub App/Action) that validates and updates status. Humans don’t flip state.

⸻

2) Architecture (High level)
	•	Source of truth: tasks.yaml checked into the repo (wave, team, acceptance criteria, steps).
	•	Artifacts:
	•	A Wave Coordination Issue titled Wave {n} · {plan_id} · Coordination.
	•	Team task issues (P1.T###) with labels wave:{n}, team:{name}, status:*.
	•	PRs that close task issues (use “Closes #XYZ”).
	•	A pinned comment (or issue body section) containing canonical JSON of wave status.
	•	Automation:
	•	Slash commands: /ready wave-1, /blocked reason:"...", /unready.
	•	Validation: All team tasks for wave are closed by merged PRs with required checks green.
	•	Transition: When all teams ready, bot posts announcement, flips a custom check-run (“Wave Gate: Wave {n}”) to ✅, and (optionally) opens next-wave issues.

⸻

3) Repository layout & config

.github/
  workflows/
    wave-coordinator.yml        # handles slash commands + validation + status updates
    wave-sweeper.yml            # optional: periodic reconcile (hourly)
  wave/
    tasks.yaml                  # canonical plan, tasks, wave/team mapping
    teams.yaml                  # team → members, CODEOWNERS groups
  ISSUE_TEMPLATE/
    task.md                     # template for task issues
    wave_coordination.md        # template for coordination issues
PULL_REQUEST_TEMPLATE.md        # requires Task ID + "Closes #"

tasks.yaml (example)

plan: phase-1
tz: UTC
waves:
  - number: 1
    teams:
      alpha: [P1.T001, P1.T013, P1.T024, P1.T037, P1.T049, P1.T061]
      beta:  [P1.T005, P1.T017, P1.T028, P1.T041, P1.T053, P1.T065]
      gamma: [P1.T021, P1.T029, P1.T033, P1.T037, P1.T049, P1.T061]
tasks:
  - id: P1.T001
    title: Cross-platform temp directory detection
    wave: 1
    team: alpha
    steps: 4
    acceptance:
      - CI green on linux/macos/windows
      - Docs updated
      - Unit tests ≥ 90% for module

Label taxonomy
	•	wave:{n} — e.g., wave:1
	•	team:{name} — e.g., team:alpha
	•	status:in-progress|blocked|ready|done
	•	risk:low|med|high (optional)
	•	coordination (for the coordination issue)

⸻

4) Security & Permissions (required)
	•	GitHub App (preferred) with:
	•	Read: contents, metadata, pull requests, issues, checks
	•	Write: issues, issue comments, checks
	•	(Optional) deployments if you later gate via deployments
	•	Branch protections: required checks, required reviews (CODEOWNERS), squash merges, signed commits or DCO.
	•	CI permissions: permissions: contents:read, pull-requests:read, checks:write, issues:write.

⸻

5) Coordination Issue Template

Title: Wave {n} · {plan_id} · Coordination
Labels: coordination, wave:{n}

Body (top):

## Wave {n} Status

<!-- wave-state:DO-NOT-EDIT -->
```json
{
  "plan": "phase-1",
  "wave": 1,
  "tz": "UTC",
  "teams": {
    "alpha": {"status":"in_progress"},
    "beta":  {"status":"in_progress"},
    "gamma": {"status":"in_progress"}
  },
  "updated_at": "2025-08-12T00:00:00Z"
}

<!-- /wave-state -->


**Commands:**

/ready wave-1
/blocked reason:“awaiting review on PR #123”
/unready

**Rules:** Only team members (from `teams.yaml`/CODEOWNERS) may issue commands for their team.

---

# 6) Slash Commands (behavior)

- **`/ready wave-1`**  
  Bot validates **that team’s** wave tasks:
  - All issues labeled `wave:1` and `team:{name}` are **CLOSED** via **merged PRs** (not manual close).
  - Required checks green on associated PR merge.
  - Optional: coverage threshold, artifact presence, doc updated file pattern.
  If valid → update JSON state to `"ready"`, post succinct ack.

- **`/blocked reason:"..."`**  
  Update JSON state to `"blocked"` with `reason`, timestamp. Optionally relabel tasks/issues `status:blocked`.

- **`/unready`**  
  Transition back to `"in_progress"`. Provide reason (optional).

**Validation notes**
- Time is in **UTC**.
- The bot is the **only** writer of the canonical JSON block.
- Human comments are allowed; machines parse the JSON only.

---

# 7) Canonical JSON state (schema)

```json
{
  "plan": "phase-1",
  "wave": 1,
  "teams": {
    "alpha": {
      "status": "ready|in_progress|blocked",
      "at": "2025-08-12T18:45:22Z",
      "reason": "optional",
      "tasks": ["P1.T001","P1.T013","P1.T024","P1.T037","P1.T049","P1.T061"]
    },
    "beta": {...},
    "gamma": {...}
  },
  "all_ready": false,
  "updated_at": "2025-08-12T18:45:22Z"
}


⸻

8) GitHub Action (reference implementation)

.github/workflows/wave-coordinator.yml

name: wave-coordinator
on:
  issue_comment:
    types: [created]
  issues:
    types: [opened, edited]
permissions:
  contents: read
  issues: write
  pull-requests: read
  checks: write
jobs:
  handle:
    if: >
      github.event.issue != null &&
      contains(github.event.issue.title, 'Wave ') &&
      contains(github.event.issue.title, 'Coordination')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Node deps
        run: npm i @octokit/graphql @octokit/rest js-yaml
      - name: Run coordinator
        uses: actions/github-script@v7
        with:
          script: |
            const {graphql} = require('@octokit/graphql');
            const yaml = require('js-yaml');
            const octokit = github;
            const issue = context.payload.issue;
            const body = context.payload.comment?.body ?? '';
            const actor = context.payload.comment?.user?.login ?? '';
            // 1) Parse command
            const cmd = body.trim().startsWith('/ready') ? 'ready'
                     : body.trim().startsWith('/blocked') ? 'blocked'
                     : body.trim().startsWith('/unready') ? 'unready'
                     : null;
            if (!cmd) return;
            // 2) Resolve wave number + team from actor
            const waveMatch = body.match(/wave-(\d+)/i) || issue.title.match(/Wave\s+(\d+)/i);
            if (!waveMatch) { core.setFailed('Wave number not found'); return; }
            const wave = Number(waveMatch[1]);
            // Load teams.yaml to map actor → team
            const fs = require('fs');
            const teams = yaml.load(fs.readFileSync('.github/wave/teams.yaml','utf8'));
            const team = Object.keys(teams).find(t => (teams[t].members||[]).includes(actor));
            if (!team) {
              await octokit.rest.issues.createComment({ ...context.repo, issue_number: issue.number, body: `❌ @${actor} is not authorized for any team.` });
              return;
            }
            // 3) Validate readiness (only for /ready)
            let valid = true, reason = '';
            if (cmd === 'ready') {
              // Fetch all tasks for this wave/team from tasks.yaml
              const tasks = yaml.load(fs.readFileSync('.github/wave/tasks.yaml','utf8'));
              const taskIds = tasks.waves.find(w => w.number === wave).teams[team] || [];
              // For each task, verify GH issue closed via merged PR w/ checks green
              // (Left as exercise: query REST/GraphQL for closedBy, PR merge state, checks conclusions)
              // Set valid=false and reason='...' if any fail
            }
            // 4) Load & update canonical JSON block in issue body
            const {data: issueData} = await octokit.rest.issues.get({ ...context.repo, issue_number: issue.number });
            const updated = updateWaveJson(issueData.body, team, cmd, valid);
            await octokit.rest.issues.update({ ...context.repo, issue_number: issue.number, body: updated.body });
            // 5) Feedback + gate
            if (cmd === 'ready') {
              await octokit.rest.issues.createComment({ ...context.repo, issue_number: issue.number, body: valid ? `✅ Team **${team}** is READY for Wave ${wave}` : `❌ Team **${team}** not ready: ${reason}` });
              if (updated.allReady) {
                // Mark custom check-run success and announce
                await octokit.rest.issues.createComment({ ...context.repo, issue_number: issue.number, body: `🚀 All teams ready. **Wave ${wave} → Wave ${wave+1}** initiated.` });
              }
            } else if (cmd === 'blocked') {
              await octokit.rest.issues.createComment({ ...context.repo, issue_number: issue.number, body: `⛔ Team **${team}** BLOCKED.` });
            } else {
              await octokit.rest.issues.createComment({ ...context.repo, issue_number: issue.number, body: `🔄 Team **${team}** back to IN PROGRESS.` });
            }

Note: Real implementation should include retries, rate-limit backoff, strict parsing of the closedBy → PR relationship and checks via GraphQL, UTC timestamps, and unit tests for the JSON block editor.

⸻

9) Workflow (day-to-day)
	1.	Create wave issues: For each wave, open a Coordination Issue from the template.
	2.	Teams execute tasks: Work via issues/PRs; CI required.
	3.	Team signals readiness: Comment /ready wave-1.
	4.	Bot validates: If valid, flips team to ready in canonical JSON and posts ack.
	5.	All ready → transition: Bot announces, flips Wave Gate check to ✅, and (optionally) opens/assigns next-wave tasks.

⸻

10) User Stories, Acceptance, DoD, Tests

Each story has Acceptance Criteria (AC), Definition of Done (DoD), and a Test Plan that directly validates the AC.

⸻

US-01 — Team signals readiness via slash command

As a team member
I want to declare my team ready for a wave via /ready wave-n
So that coordination is fast, validated, and auditable.

AC
	•	AC1: /ready wave-n can only be issued by a member of that team.
	•	AC2: Bot validates all of the team’s wave:n tasks are closed via merged PRs (not manual close).
	•	AC3: All required checks on those PRs conclude success (or allowed neutral).
	•	AC4: On success, bot updates canonical JSON to status:"ready" with at (UTC) and task list; posts ack comment.
	•	AC5: On failure, bot posts a concise failure reason and does not mark ready.

DoD
	•	Team member invokes command; bot responds in < 60s.
	•	JSON block updated exactly once, no duplicates.
	•	Event logged in Actions logs.

Test Plan
	•	Unit: command parser (happy path, whitespace, casing).
	•	Integration: mock GH API shows issues closed via merged PR; bot flips to ready.
	•	Negative: manual issue closure → bot rejects; failing check → rejects.
	•	Security: non-member attempts /ready → rejected.

⸻

US-02 — Team declares block / unready

As a team member
I want to mark us blocked (with reason) or back to in_progress
So that the coordinator sees reality.

AC
	•	AC1: /blocked reason:"..." updates JSON status:"blocked" + reason + time.
	•	AC2: /unready updates JSON status:"in_progress".
	•	AC3: Bot posts minimal ack comment.
	•	AC4: Only authorized team members may issue.

DoD
	•	Status flips reflected in JSON within 60s.
	•	Prior ready timestamps preserved in history log (optional).

Test Plan
	•	Unit: reason parser supports quotes + escaped chars.
	•	Integration: blocked → unready → ready cycle works; JSON consistent.

⸻

US-03 — Canonical state maintained in a single pinned block

As a coordinator
I want machine-readable state in a single place
So that dashboards and humans see the same truth.

AC
	•	AC1: JSON lives in a fenced block delimited by markers: <!-- wave-state:DO-NOT-EDIT --> ... <!-- /wave-state -->.
	•	AC2: Only the bot edits this block.
	•	AC3: JSON validates against schema (wave, teams, statuses).
	•	AC4: Every edit updates updated_at (UTC).

DoD
	•	Schema file exists; linter validates JSON on CI (optional pre-commit).
	•	Editing preserves other body content.

Test Plan
	•	Unit: idempotent editor updates fields without clobbering.
	•	Property: multiple updates produce stable JSON (no reordering noise).

⸻

US-04 — All-ready gate + wave transition

As a coordinator
I want the system to announce transition when all teams ready
So that everyone moves together.

AC
	•	AC1: When every team in tasks.yaml for wave n is "ready", bot posts transition comment tagging teams.
	•	AC2: Bot creates/updates a Check Run named Wave Gate: Wave n to success.
	•	AC3: (Optional) Bot opens/assigns next-wave task issues per tasks.yaml.

DoD
	•	Transition is atomic; no double-announcements.
	•	Check-run visible in repo checks tab.

Test Plan
	•	Integration: final team /ready triggers announcement and check-run.
	•	Race: two teams ready within <5s → single announcement (use GH Action concurrency group).

⸻

US-05 — Validation rules are strict and auditable

As a reviewer
I want confidence that ready means “done-done.”

AC
	•	AC1: Each task is closed by merged PR that references the issue via “Closes #”.
	•	AC2: Required status checks conclude success (include OS matrix).
	•	AC3: (Optional) Coverage threshold per task met.
	•	AC4: (Optional) Files changed include docs for doc-required tasks.

DoD
	•	Validation logic covered by unit tests; rules documented.
	•	Failure messages include direct links to offending PR/check.

Test Plan
	•	Negative: PR merged without “Closes #” → task remains open → reject.
	•	Negative: CI partial green with one failed job → reject.
	•	Positive: all pass → accept.

⸻

US-06 — Permissions and identity

As a security owner
I want least-privilege automation and clear authN.

AC
	•	AC1: GitHub App token used (not user PAT).
	•	AC2: Teams and members defined in .github/wave/teams.yaml and aligned with CODEOWNERS.
	•	AC3: Only team members can change their team state.

DoD
	•	App installed org-wide with documented permissions.
	•	Attempt by non-member rejected.

Test Plan
	•	Integration: simulate actor not in team → 403-style rejection path.

⸻

US-07 — Rate-limit & retry resilience

As a platform owner
I want the coordinator to be resilient to API hiccups.

AC
	•	AC1: Exponential backoff on 403 rate-limit, respect X-RateLimit-Reset.
	•	AC2: Retries on 5xx.
	•	AC3: Idempotency keys / deterministic updates avoid duplicate comments.

DoD
	•	Backoff helper with tests; logs include retry counts.

Test Plan
	•	Fault-injection: mock 403/5xx → validate retries/backoff.

⸻

US-08 — Observability & metrics

As a PM
I want simple metrics without building Grafana.

AC
	•	AC1: Bot emits a compact metrics JSON artifact per run (wave, team, state, durations).
	•	AC2: Nightly job writes a rollup JSON to a branch (data/waves.json) or gh-pages.

DoD
	•	Metrics sane under load; timestamps in UTC.

Test Plan
	•	Integration: generate rollup with three teams over two waves; numbers correct.

⸻

US-09 — Task integrity from tasks.yaml

As a coordinator
I want one place to edit task ownership and wave mapping.

AC
	•	AC1: tasks.yaml drives labels (wave:n, team:name) and validation.
	•	AC2: A generator can (re)sync labels and issue fields from yaml.
	•	AC3: CI fails if a PR references a non-existent task_id.

DoD
	•	Generator script present; dry-run and apply modes.

Test Plan
	•	Unit: parse YAML; Integration: label sync updates issues.

⸻

US-10 — Runbook & failure recovery

As a human oncall
I want clear steps when things go sideways.

AC
	•	AC1: Runbook includes: stuck CI, manual close misuse, race during transition.
	•	AC2: /unready path documented for rollback.

DoD
	•	Runbook checked in at .github/wave/RUNBOOK.md.

Test Plan
	•	Table-top: simulate manual close → recovery path works (reopen issue, fix PR, re-ready).

⸻

11) Definition of Done (Global)
	•	All user stories’ AC satisfied with passing tests.
	•	GitHub App installed with documented scopes.
	•	Actions configured with concurrency (e.g., group: wave-coordinator, cancel-in-progress: true).
	•	Branch protections enforced; PR template requires Task ID + “Closes #”.
	•	Sample plan (tasks.yaml) and three demo teams seeded; dry-run E2E passes.

⸻

12) Test Strategy (End-to-End)
	•	Happy path: Three teams complete Wave 1 tasks → /ready x3 → transition posted → Wave Gate check success → Wave 2 issues assigned.
	•	CI fail path: One team PR has failing job → /ready rejected with link to failing check.
	•	Auth path: Non-member tries /ready → rejected.
	•	Race path: Two /ready comments within 2s → one transition comment.
	•	Manual close misuse: Issue closed manually → validator detects closedBy not PR → rejected; runbook executed to reopen and fix.

⸻

13) PR / Issue Templates (snippets)

PULL_REQUEST_TEMPLATE.md

### Task Link
- Closes #<task-issue-number>
- Task ID: <e.g., P1.T024>

### Definition of Done
- [ ] Acceptance criteria met
- [ ] Required checks green
- [ ] Docs updated (if applicable)
- [ ] Tests added/updated

### Notes

ISSUE_TEMPLATE/task.md

---
name: Task
labels: ["status:in-progress"]
---

## Task: {{id}} — {{title}}

**Wave:** {{wave}}  
**Team:** {{team}}

### Acceptance Criteria
- ...

### Steps ({{steps}})
1. ...


⸻

14) Operations Runbook (abridged)
	•	Team stuck in CI: Team comments /blocked reason:"CI flake on macOS runners"; infra assists; after fix, /unready then /ready.
	•	PR merged without “Closes #”: Reopen issue; push follow-up PR with proper closure; re-ready.
	•	Bot rate-limited: Action retries. If still failing, maintainer manually reruns workflow.
	•	Rollback readiness: Team uses /unready. Bot flips state; transition remains pending.

⸻

15) Rollout Plan
	1.	Week 0: Install GitHub App; add branch protections; seed labels; commit templates; land tasks.yaml.
	2.	Week 1: Enable wave-coordinator.yml; dry-run on a demo wave with 2-3 toy tasks per team.
	3.	Week 2: Pilot on a real wave; observe; tweak validation rules (coverage/doc rules).
	4.	Week 3+: Make it the standard; kill status meetings; keep sync points.

⸻

Appendix A — Validation (GraphQL sketch)

Fetch “closedBy” PR events and check conclusions.

query($owner:String!, $repo:String!, $issue:Int!) {
  repository(owner:$owner, name:$repo) {
    issue(number:$issue) {
      state
      closingIssuesReferences(last:10) {
        nodes {
          __typename
          ... on PullRequest {
            number
            merged
            commits(last:1) { nodes { commit { oid } } }
            commitsResourcePath
            closingIssuesReferences(first:1) { totalCount }
            commits(last:1) {
              nodes {
                commit { checkSuites(first:50) {
                  nodes { conclusion status }
                }}
              }
            }
          }
        }
      }
    }
  }
}


⸻

Appendix B — Minimum bot behaviors checklist
	•	Parse /ready, /blocked, /unready
	•	Resolve actor → team
	•	Validate all team tasks for wave
	•	Update pinned JSON atomically (UTC)
	•	Post concise ack/fail comments
	•	Gate transition & set check-run
	•	Retry/backoff on API limits
	•	Log metrics artifact

⸻

Hand-off note: This spec is designed for a small team to implement in ~1–2 weeks: Day 1–2 templates/labels/branch protections; Day 3–5 coordinator Action + validators; Day 6–7 tests + pilot. Keep humans out of the critical path; let the bot be the truth.