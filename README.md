# 🚀 Claude Auto-Tee

Automatically injects `tee` into Claude Code bash commands to save full output while still showing truncated results.

## ✨ The Problem

When using Claude Code, you often run commands like:
```bash
npm run build 2>&1 | tail -10    # See last 10 lines
```

But then you want to see the full output and have to re-run the slow command:
```bash  
npm run build                    # Wait again... 😩
```

## 🎯 The Solution

This tool automatically transforms your commands:

**Input:**
```bash
npm run build 2>&1 | tail -10
```

**Auto-transformed to:**
```bash
npm run build 2>&1 | tee /tmp/claude-abc123.log | tail -10
📝 Full output saved to: /tmp/claude-abc123.log
```

Now you get **both**:
- ✅ The last 10 lines you wanted  
- ✅ Full output saved to `/tmp` for later inspection

## 🚀 Installation

### Option 1: NPM (Recommended)
```bash
npm install -g claude-auto-tee
claude-auto-tee
```

### Option 2: Direct Install
```bash
git clone https://github.com/flyingrobots/claude-auto-tee.git
cd claude-auto-tee  
npm install
node install.js
```

## 🎛️ Usage

### Interactive Mode
```bash
claude-auto-tee
```
The installer will prompt you to choose:

### CLI Mode
```bash
claude-auto-tee --global     # Install globally  
claude-auto-tee --local      # Install locally
claude-auto-tee --uninstall  # Remove hooks
claude-auto-tee --help       # Show help
```

### Installation Types

1. **Global** (`-g`, `--global`) - Apply to all Claude Code sessions
2. **Local** (`-l`, `--local`) - Apply only to current project  
3. **Uninstall** (`-u`, `--uninstall`) - Remove auto-tee hooks

## 🎯 Smart Detection

The hook only activates for commands that typically produce lots of output:

### ✅ Will Auto-Tee
- `npm run build`
- `yarn test`  
- `tsx scripts/my-script.ts`
- `find . -name "*.js"`
- `git log --oneline`
- `npx some-tool`
- Custom patterns: `decree`, `compliance`, etc.

### ❌ Will Skip
- Interactive commands: `npm run dev`, `yarn start`
- Redirections: `build > output.txt`  
- Already has tee: `build | tee log.txt`
- Short commands: `ls`, `pwd`

## 🧠 How It Works

Uses **AST parsing** (not regex!) with [`bash-parser`](https://www.npmjs.com/package/bash-parser) to:

1. Parse bash commands into Abstract Syntax Tree
2. Detect pipelines, redirections, and interactive commands  
3. Intelligently inject `tee` before existing pipes
4. Handle edge cases like quoted strings and complex pipelines

## 📋 Examples

### Simple Command
```bash
# You run:
npm run build

# Auto-transformed:  
npm run build 2>&1 | tee /tmp/claude-xyz.log | head -100
📝 Full output saved to: /tmp/claude-xyz.log
```

### With Existing Pipeline  
```bash
# You run:
npm run test 2>&1 | grep "Error" | head -5

# Auto-transformed:
npm run test 2>&1 | tee /tmp/claude-xyz.log | grep "Error" | head -5  
📝 Full output saved to: /tmp/claude-xyz.log
```

### Complex Pipeline
```bash
# You run:
find . -name "*.ts" | grep -v node_modules | wc -l

# Auto-transformed:
find . -name "*.ts" 2>&1 | tee /tmp/claude-xyz.log | grep -v node_modules | wc -l
📝 Full output saved to: /tmp/claude-xyz.log
```

## 🔧 Configuration

The tool installs as a Claude Code pre-tool hook in `.claude/settings.json`:

```json
{
  "hooks": {
    "preToolUse": [
      {
        "command": "/path/to/claude-auto-tee/src/hook.js",
        "matchers": ["Bash"]
      }
    ]
  }
}
```

## 🧪 Testing

Run the test suite:
```bash
npm test
```

Tests cover:
- ✅ AST parsing edge cases
- ✅ Pipeline injection  
- ✅ Skip conditions
- ✅ Error handling
- ✅ Complex command patterns

## 🚨 Edge Cases Handled

- **Quoted pipes**: `echo "file | name" | head` ✅
- **Redirections**: `cmd > file.txt` (skipped) ✅
- **Interactive**: `npm run dev` (skipped) ✅
- **Existing tee**: `cmd | tee log` (skipped) ✅
- **Complex pipelines**: Multi-stage pipes ✅

## 🤝 Contributing

1. Fork the repo
2. Create feature branch: `git checkout -b feature/amazing`
3. Run tests: `npm test`  
4. Commit: `git commit -am 'Add amazing feature'`
5. Push: `git push origin feature/amazing`
6. Create Pull Request

## 📄 License

MIT © [flyingrobots](https://github.com/flyingrobots)

## 🙏 Credits

Inspired by the CLAUDE.md guideline:
> When running commands that might fail, capture full output to a temp file FIRST

Built for the [Claude Code](https://claude.ai/code) community.

---

**Stop re-running slow commands!** 🎉