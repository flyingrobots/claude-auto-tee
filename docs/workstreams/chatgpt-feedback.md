# ChatGPT Feedback on GitHub-Native Wave Execution Workflow

**External review and critique of the proposed GitHub-native wave execution system**

## 📋 Overall Verdict

**ChatGPT Assessment:** "Green-light with surgical upgrades. The core idea (issues/PRs/comments + CI + minimal scripts) is right."

**Key Insight:** "You've basically weaponized GitHub into a wave orchestrator."

**Recommendation:** Ship it after specific technical improvements rather than architectural changes.

## 🔥 Critical Issues Identified

### Kill / Keep / Change Framework

#### ❌ KILL
- **Local filesystem `~/claude-wave-sync/.../ready.txt`**
  - Identified as "brittle SPOF and not auditable"
  - Not GitHub-native, creates external dependency
  - Lacks proper audit trail

#### ✅ KEEP  
- Issue/PR-centric tracking
- Conventional commits
- CI-gated merges
- Wave sync points concept

#### 🔄 CHANGE
- **Progress comments** → structured, parseable single "pinned" comment (edited in-place)
- **Authentication** → Use GitHub App tokens instead of user PATs
- **Dashboard** → Use GraphQL for efficiency over REST API

## 🚨 Must-Fix Issues (Before Pilot)

### 1. Wave Readiness Artifact Replacement
**Problem:** Filesystem ready.txt is brittle and not auditable

**Preferred Solution:** GitHub Deployments
```bash
# Each team posts deployment to wave-ready environment
gh api repos/:owner/:repo/deployments \
  -f environment="wave-1-ready" \
  -f ref="$BRANCH" \
  -f required_contexts='[]'

# Transition when all deployments succeed
```

**Alternative Solution:** Coordination repo with protected branch
```json
# wave/1/ready/team-alpha.json
{
  "team": "alpha",
  "wave": 1, 
  "tasks": ["P1.T001", "P1.T013", "..."],
  "at": "2025-08-12T18:45:22Z"
}
```

### 2. Structured Progress Comments
**Problem:** Free-text comments are hard to parse and create noise

**Solution:** Single bot-authored pinned comment with JSON block
```json
{
  "task": "P1.T001",
  "team": "alpha", 
  "steps_total": 5,
  "steps_done": 3,
  "last_commit": "abc123",
  "next": "Add env override",
  "ci": "pending",
  "updated_at": "2025-08-12T21:30:00Z"
}
```

### 3. Script Hardening Required
**Issues Identified:**
- Missing `set -euo pipefail` for proper error handling
- No retries with backoff for API calls
- Insufficient input validation
- Lack of idempotency controls
- Need `flock` or lockfiles for state updates

### 4. CI Status Logic Bug
**Problem:** Checking `.status == "FAILURE"` is incorrect

**Issue:** GitHub uses:
- `status`: queued/in_progress/completed  
- `conclusion`: success/failure/neutral/cancelled/timed_out/skipped

**Fix:** Check `conclusion` field (case-insensitive)

### 5. Authentication Upgrade
**Problem:** User PATs have limitations

**Solution:** GitHub App token provides:
- Org-wide installation
- Least-privilege scopes
- Higher rate limits  
- Clean audit trail
- Can post custom Check Runs

### 6. Dashboard Optimization
**Problem:** REST API polling is inefficient

**Solutions:**
- Use GraphQL for batch queries
- Implement ETags and exponential backoff
- Consider webhooks → queue → projector → static JSON
- Host dashboard on gh-pages

### 7. Task Schema Definition
**Problem:** No single source of truth for tasks

**Solution:** Add `tasks.yaml` schema
```yaml
- id: P1.T001
  wave: 1
  title: Cross-platform temp dir
  acceptance_criteria:
    - Platform detection works across macOS/Linux/Windows
    - Fallback hierarchy implemented
    - Environment variables respected
  steps: 5
  team: alpha
```

### 8. Repository Protection
**Required Settings:**
- Branch protection with required status checks
- Code review by CODEOWNERS required
- DCO or signed commits
- Squash merges only
- Linear history
- Enforce "Closes #XYZ" in PR template

### 9. Rate Limit & Noise Control
**Issues:**
- Edit-in-place pinned comments instead of appending 50 comments
- Separate human narrative from machine-readable data
- Respect GitHub API rate limits

### 10. Time & Metrics Consistency
**Requirements:**
- Everything in UTC timestamps
- Compute durations from ISO timestamps
- Store computed metrics in artifacts or coordination repo
- No reliance on local logs for timing

## 💪 Strong Recommendations

### GitHub Deployments as Wave Gates
- "It's literally what they're for"
- Each team "deploys" readiness to `wave-<n>-ready` environment
- GitHub Action aggregates readiness and updates coordination issue

### Custom Check Runs
- Add "Task Progress" check run per task
- Update summary with step table and links
- Appears in PR checks area (prime real estate)

### Label Taxonomy
```
wave:1, team:alpha, status:in-progress|blocked|ready, risk:high
```
- Saved searches become dashboard without custom code

### PR/Issue Templates
- Lock in Definition of Done and Acceptance Criteria
- Link to tasks.yaml
- Fail CI if PR doesn't reference valid Task ID

### Security & Permissions
- Action permissions: `contents:read`, `pull-requests:write`
- Secret scanning enabled
- Dependabot enabled
- CODEOWNERS required for all changes

## 🔧 Specific Script Improvements

### Required Header for All Scripts
```bash
#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit || true
RETRIES=${RETRIES:-5}
SLEEP=${SLEEP:-2}
require() { command -v "$1" >/dev/null || { echo "Missing $1"; exit 127; }; }
require gh; require jq; require git
```

### Fixed CI Monitoring Logic
```bash
LOWER='def lower_ascii: if type=="string" then ascii_downcase else . end;'
ROLLUP=$(gh pr view "$PR_NUMBER" --json statusCheckRollup | jq '.statusCheckRollup')
FAIL=$(echo "$ROLLUP" | jq -e --argjson L "$LOWER" '[.[] | select((.conclusion|tostring|ascii_downcase) as $c | ($c=="failure" or $c=="timed_out" or $c=="cancelled" or $c=="action_required"))] | length')
PENDING=$(echo "$ROLLUP" | jq -e '[.[] | select(.status!="SUCCESS" and .conclusion==null)] | length')
```

### JSON Progress Update Pattern
```bash
# Build canonical JSON
JSON=$(jq -n \
  --arg task "$TASK_ID" \
  --arg team "$(get_team_name)" \
  --arg last_commit "$NEW_SHA" \
  --arg next "$(get_next_step_description "$TASK_ID")" \
  --arg time "$NOW" \
  --argjson steps_total "$TOTAL_STEPS" \
  --argjson steps_done "$STEP_NUM" \
  '{task:$task,team:$team,steps_total:$steps_total,steps_done:$steps_done,last_commit:$last_commit,next:$next,ci:"pending",updated_at:$time}')

BODY="<!-- progress:do-not-edit-above -->
\`\`\`json
$JSON
\`\`\`
"

# Update pinned comment
gh api --method PATCH \
  -H "Accept: application/vnd.github+json" \
  "/repos/:owner/:repo/issues/comments/$PINNED_ID" \
  -f body="$BODY"
```

## 🎯 Priority Actions

### Immediate (Before Any Pilot)
1. **Replace ready.txt with GitHub Deployments**
2. **Fix CI status checking logic**
3. **Implement structured progress comments**
4. **Add script hardening (set -euo pipefail, retries, validation)**

### High Priority (Week 1)
1. **Set up GitHub App authentication**
2. **Implement tasks.yaml schema**
3. **Add repository protections and templates**
4. **Create GraphQL dashboard queries**

### Medium Priority (Week 2)
1. **Add custom Check Runs for task progress**
2. **Implement label taxonomy and saved searches**
3. **Set up webhook-based dashboard updates**
4. **Add comprehensive error handling and dry-run modes**

## 🎪 Stretch Goals (Nice-to-Have)

- **Custom Check Run "Wave Gate"** showing overall wave readiness
- **GitHub Projects (v2) board** auto-filled from tasks.yaml
- **Nightly static metrics report** to gh-pages with SPA
- **Concurrency groups** for Actions to auto-cancel superseded runs

## 📊 Assessment Summary

**ChatGPT's Core Message:** The fundamental approach is sound, but the implementation needs technical refinement to be production-ready.

**Key Validation:** "If you do nothing else: (1) kill ready.txt, (2) structured pinned progress, (3) fix CI status logic, (4) run as a GitHub App. Do those and this thing will purr like a well-oiled CI cat."

**Strategic Insight:** The critique validates the core GitHub-native approach while identifying specific technical debt that would cause real-world operational issues.

---

**This feedback provides a clear roadmap for converting our prototype into a production-ready system that leverages GitHub's native capabilities properly.** 🚀