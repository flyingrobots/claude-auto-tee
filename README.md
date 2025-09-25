> [!IMPORTANT]
> **Status:** Invactive
> As I was in the process of hardening this project, Claude Code released an update and I noticed Claude started doing this by default in many cases. So I've suspended work on this project. It works, but there's a lot of room for perfection. But, alas, I am not even a Claude user anymore, sadly. And so, this project is no longer actively worked on.
> 🥀

# claude-auto-tee

**Save time and tokens.** Stop Claude from running the same commands over and over.

---

## The Problem

Let's say Claude investigates a build failure. An error message flashes by in hundreds of lines of output. Claude, trying to be helpful, piped the build to `tail -10` to avoid flooding your screen. But surprise - the actual error isn't in the last 10 lines.

Now what?

### BEFORE `claude-auto-tee`

```
Let me check what's failing...
→ npm run build | tail -10
[Shows last 10 lines, no error visible]
Maybe I should search for errors...
→ npm run build | grep "ERROR"
0 results
Maybe it's lowercase...
→ npm run build | grep "error"
2 results (but not the root cause)
Let me look for warnings...
→ npm run build | grep "warning"
47 results (too many)
Let me see the actual failure...
→ npm run build | grep -A 5 "failed"
(finds something, but needs more context)
I need to see what happened before this...
→ npm run build | grep -B 10 "failed"
(wait... running the whole build AGAIN...)
```

*Result: 6 builds. 5 minutes wasted. Hundreds of tokens burned.*

### AFTER `claude-auto-tee`

```
Let me check what's failing...
→ npm run build | tail -10
[Shows last 10 lines, no error visible]
→ Full output saved to /tmp/claude-xyz.log ✨
Let me search the saved output...
→ grep -i "error" /tmp/claude-xyz.log
→ grep "Module not found" /tmp/claude-xyz.log
→ grep -B 20 -A 5 "failed" /tmp/claude-xyz.log
→ awk '/warning/,/error/' /tmp/claude-xyz.log
```

*Result: Build runs ONCE. Claude explores the full output instantly.*

---

### How?

This hook injects `tee` into any piped command:

```bash
# Claude runs:
npm run build | tail -10

# It becomes:
npm run build | tee /tmp/claude-xyz.log | tail -10
```

Claude sees the truncated output AND gets told where the full log is saved.

**BOOM!** No more re-running commands.

---

## Installation

```bash
# Clone and install
git clone https://github.com/flyingrobots/claude-auto-tee.git
cd claude-auto-tee
chmod +x src/claude-auto-tee.sh

# Configure Claude Code
mkdir -p ~/.claude
echo '{
  \"hooks\": {
    \"preToolUse\": [{
      \"command\": \"'$(pwd)'/src/claude-auto-tee.sh\",
      \"matchers\": [\"Bash\"]
    }]
  }
}' > ~/.claude/settings.json
```

## How it works

- **Detects pipes**: Any command with `\" | \"` gets `tee` injected
- **Saves everything**: Full output goes to `/tmp/claude-*.log`
- **Zero config**: Works immediately after installation
- **Graceful**: If anything fails, your command runs unchanged

## Examples

```bash
# Claude runs:
find . -name \"*.js\" | wc -l

# Hook transforms to:
find . -name \"*.js\" | tee /tmp/claude-xyz.log | wc -l

# Later, Claude can review the full output:
cat /tmp/claude-xyz.log
```

## Configuration

Optional environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_AUTO_TEE_VERBOSE` | `false` | Enable debug logging |
| `TMPDIR` | `/tmp` | Override temp directory |

## Troubleshooting

```bash
# Test the tool
echo '{\"tool\":{\"name\":\"Bash\",\"input\":{\"command\":\"ls | head -5\"}}}' | ./src/claude-auto-tee.sh

# Enable verbose mode
CLAUDE_AUTO_TEE_VERBOSE=true claude

# Run diagnostics
bash scripts/diagnose.sh
```

## Roadmap

Currently implementing Phase 1 improvements. See [open issues](https://github.com/flyingrobots/claude-auto-tee/issues) for details.

**Priority areas:**
- Platform compatibility testing
- Error handling improvements  
- Installation automation
- Documentation expansion

## Contributing

Issues and PRs welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT

---

**Bottom line**: Stop re-running slow commands. Install this, run commands with pipes, get full output saved automatically.
