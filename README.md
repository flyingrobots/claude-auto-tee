> [!IMPORTANT]
> **Status:** Invactive
> As I was in the process of hardening this project, Claude Code released an update and I noticed Claude started doing this by default in many cases. So I've suspended work on this project. It works, but there's a lot of room for perfection. But, alas, I am not even a Claude user anymore, sadly. And so, this project is no longer actively worked on.
> 🥀

# claude-auto-tee

**Automatic output capture for Claude Code.** Never lose command output again.

---

## What it does

When Claude runs piped commands, `claude-auto-tee` silently captures the full output to disk while preserving the original pipeline behavior. No more re-running commands to see what you missed.

```bash
# Claude runs:
npm test | grep FAIL

# Behind the scenes:
npm test | tee /tmp/claude-xyz.log | grep FAIL
# → [#auto-tee] saved:/tmp/claude-xyz.log size:2MB cleanup:on

# Claude can now explore the full output:
grep -B 20 "FAIL" /tmp/claude-xyz.log  # See what led to failures
rg "Error|Warning" /tmp/claude-xyz.log  # Find all issues
tail -n 100 /tmp/claude-xyz.log         # Check the final state
```

## Why you need this

**Without claude-auto-tee:** Claude runs the same expensive command 5+ times with different filters, burning time and tokens.

**With claude-auto-tee:** Commands run once. Claude explores the saved output instantly. You save minutes on every debugging session.

Real scenarios where this shines:
- Build failures buried in verbose output
- Test suites with intermittent failures  
- Log analysis with complex patterns
- Package installations with warnings
- Database queries with large result sets

## Installation

```bash
# 1. Clone the repository
git clone https://github.com/flyingrobots/claude-auto-tee.git
cd claude-auto-tee

# 2. Install jq for robust JSON parsing (recommended)
# macOS
brew install jq
# Ubuntu/Debian
sudo apt-get install jq
# Or download from https://jqlang.github.io/jq/

# 3. Configure Claude Code
mkdir -p ~/.claude
cat > ~/.claude/settings.json << 'EOF'
{
  "hooks": {
    "preToolUse": [{
      "command": "PATH_TO_REPO/src/claude-auto-tee.sh",
      "matchers": ["Bash"]
    }]
  }
}
EOF

# 4. Replace PATH_TO_REPO with your actual path
sed -i '' "s|PATH_TO_REPO|$(pwd)|" ~/.claude/settings.json  # macOS
# OR
sed -i "s|PATH_TO_REPO|$(pwd)|" ~/.claude/settings.json      # Linux
```

## Configuration

Environment variables for fine-tuning:

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_AUTO_TEE_VERBOSE` | `false` | Enable debug logging |
| `CLAUDE_AUTO_TEE_DRY_RUN` | `false` | Preview what would happen without executing |
| `CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS` | `true` | Auto-delete captures after successful commands |
| `CLAUDE_AUTO_TEE_MAX_SIZE` | `104857600` | Max capture size in bytes (default: 100MB) |
| `CLAUDE_AUTO_TEE_CLEANUP_AGE_HOURS` | `48` | Delete captures older than N hours |
| `CLAUDE_AUTO_TEE_DENYLIST` | (empty) | Comma-separated commands to never capture (e.g., `ssh,scp,gpg`) |
| `CLAUDE_AUTO_TEE_ALLOWLIST` | (empty) | If set, only capture these commands (e.g., `grep,find,ls`) |

## How it works

1. **Pipe detection**: Identifies single-pipe commands (security-first approach)
2. **Safe injection**: Adds `tee` to capture output without breaking the pipeline
3. **Resource limits**: Caps file sizes, monitors disk space, cleans old files
4. **Status hints**: Reports capture status with concise messages
5. **Graceful fallback**: If anything fails, runs your original command unchanged

### What gets captured

✅ **Captured:**
- Simple piped commands: `ls -la | grep test`
- Stderr redirection: `npm test 2>&1 | tail`
- Complex pipelines: `find . -name "*.js" | xargs grep "TODO" | wc -l`

❌ **Passed through unchanged:**
- Commands without pipes
- Already contains `tee`
- Security-sensitive commands (configurable via denylist)
- Multi-pipe commands (unless explicitly enabled)

### Output format

The tool provides concise status messages:

```bash
[#auto-tee] saved:/tmp/claude-abc123.log size:2MB cleanup:on
[#auto-tee] pass-through: no writable TMPDIR
[#auto-tee] pass-through: command in denylist
[#auto-tee] truncated:yes full_size:150MB limit:100MB
```

## Advanced usage

### Dry-run mode
See what would happen without executing:
```bash
export CLAUDE_AUTO_TEE_DRY_RUN=true
# Now Claude's commands will preview but not execute
```

### Security controls
```bash
# Never capture sensitive commands
export CLAUDE_AUTO_TEE_DENYLIST="ssh,scp,gpg,vault"

# Only capture specific safe commands
export CLAUDE_AUTO_TEE_ALLOWLIST="grep,find,ls,cat"
```

### Resource management
```bash
# Adjust size limits for large outputs
export CLAUDE_AUTO_TEE_MAX_SIZE=524288000  # 500MB

# Keep captures longer for review
export CLAUDE_AUTO_TEE_CLEANUP_AGE_HOURS=168  # 1 week

# Disable auto-cleanup
export CLAUDE_AUTO_TEE_CLEANUP_ON_SUCCESS=false
```

## Troubleshooting

### Test the hook directly
```bash
echo '{"tool":{"name":"Bash","input":{"command":"echo hello | cat"}}}' | \
  ./src/claude-auto-tee.sh
```

### Enable verbose logging
```bash
export CLAUDE_AUTO_TEE_VERBOSE=true
```

### Check disk space
```bash
df -h /tmp
ls -la /tmp/claude-* | wc -l  # Count capture files
```

### Manual cleanup
```bash
# Remove captures older than 24 hours
find /tmp -name "claude-*.log" -mtime +1 -delete
```

## Design philosophy

- **Safety first**: Single-pipe only by default, extensive validation
- **Full fidelity**: Capture everything, let Claude filter later
- **Zero surprise**: Clear status messages, predictable behavior
- **Operational robustness**: Resource limits, cleanup, monitoring
- **Graceful degradation**: When in doubt, pass through unchanged

## Contributing

Issues and PRs welcome! The codebase is modular and well-documented.

Key files:
- `src/claude-auto-tee.sh` - Main hook implementation
- `src/disk-space-check.sh` - Resource monitoring
- `src/error-codes.sh` - Standardized error handling
- `test/` - Comprehensive test suite

## License

MIT

---

**Install this once. Save hours of waiting for commands to re-run.**