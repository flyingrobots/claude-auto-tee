# Claude Auto-Tee Beta Testing Onboarding Guide

**Welcome to the claude-auto-tee beta testing program!**

Thank you for joining our beta testing group. This guide will help you get set up quickly and make the most of your testing experience.

## 🎯 Quick Start Checklist

- [ ] Join the private Discord server
- [ ] Access the private GitHub repository or download beta package
- [ ] Complete installation and basic setup
- [ ] Run your first test command
- [ ] Submit your first feedback (even if it's just "everything works!")

**Estimated Setup Time:** 15-30 minutes

## 📋 What You're Testing

### Claude Auto-Tee Overview
Claude Auto-Tee automatically captures command output to temporary files when using Claude Code, solving the problem of having to re-run expensive commands to reference previous results.

**Before claude-auto-tee:**
```bash
# User runs expensive command
npm run build    # Takes 2 minutes
# Claude Code can't see the output, user has to re-run
```

**With claude-auto-tee:**
```bash
# Command automatically captured
npm run build | tee /tmp/claude-auto-tee-xyz.log
# Claude Code can reference the saved output file
```

### Key Features to Test
1. **Automatic Pipe Detection** - Tool detects when commands need output capture
2. **Cross-Platform Compatibility** - Works on macOS, Linux, Windows WSL
3. **Error Handling** - Graceful degradation when things go wrong
4. **Resource Management** - Efficient temp file cleanup and space usage
5. **Integration** - Seamless workflow with existing Claude Code usage

## 🚀 Installation & Setup

### Option 1: Private Repository Access
If you received GitHub repository access:

```bash
# Clone the beta repository
git clone https://github.com/flyingrobots/claude-auto-tee-beta.git
cd claude-auto-tee-beta

# Make the script executable
chmod +x src/claude-auto-tee.sh

# Test basic functionality
./src/claude-auto-tee.sh --version
```

### Option 2: Beta Package Download
If you received a direct download link:

```bash
# Download and extract (replace URL with provided link)
curl -L [BETA_DOWNLOAD_URL] -o claude-auto-tee-beta.tar.gz
tar -xzf claude-auto-tee-beta.tar.gz
cd claude-auto-tee-beta

# Make executable and test
chmod +x claude-auto-tee.sh
./claude-auto-tee.sh --version
```

### Platform-Specific Setup

#### macOS
```bash
# Add to PATH (optional)
export PATH="$PATH:$(pwd)"
echo 'export PATH="$PATH:'$(pwd)'"' >> ~/.zshrc

# Test with a simple command
echo "Hello World" | ./claude-auto-tee.sh
```

#### Linux
```bash
# Add to PATH (optional)
export PATH="$PATH:$(pwd)"
echo 'export PATH="$PATH:'$(pwd)'"' >> ~/.bashrc

# Test with system command
ls -la | ./claude-auto-tee.sh
```

#### Windows WSL
```bash
# Ensure WSL integration
which bash  # Should show WSL bash path

# Test with Windows-specific scenarios
cmd.exe /c "dir" | ./claude-auto-tee.sh
```

### Verification
Run these commands to verify installation:

```bash
# Basic functionality test
echo "Installation test" | ./claude-auto-tee.sh

# Check if temp file was created
ls /tmp/claude-auto-tee-*

# Verify content
cat /tmp/claude-auto-tee-* | head -5
```

## 📊 Testing Phases

### Phase 1: Core Functionality (Week 1)
**Focus:** Basic pipe detection and tee injection

**Test Scenarios:**
```bash
# Simple commands
echo "test" | ./claude-auto-tee.sh
date | ./claude-auto-tee.sh
ls -la | ./claude-auto-tee.sh

# Build commands (if applicable)
npm run build | ./claude-auto-tee.sh
make | ./claude-auto-tee.sh
docker build . | ./claude-auto-tee.sh

# Long-running commands
find /usr -name "*.so" | ./claude-auto-tee.sh
```

**What to Report:**
- Does installation work smoothly?
- Do commands execute normally?
- Are temp files created with expected content?
- Any error messages or unusual behavior?

### Phase 2: Advanced Features (Week 2-3)
**Focus:** Error handling, verbose mode, cross-platform compatibility

**Test Scenarios:**
```bash
# Error conditions
./claude-auto-tee.sh --nonexistent-flag
echo "test" | ./claude-auto-tee.sh --verbose

# Resource limits
# (We'll provide specific large-output tests)

# Platform-specific paths
# (Windows: C:\ paths, macOS: /Users, Linux: /home)
```

**What to Report:**
- How does error handling work?
- Is verbose mode helpful?
- Platform-specific issues or compatibility problems?
- Resource usage concerns?

### Phase 3: Integration & Workflow (Week 3-4)
**Focus:** Real-world usage in daily workflows

**Test Scenarios:**
- Use claude-auto-tee in your actual development workflow
- Try with your most common commands
- Test integration with existing scripts/aliases

**What to Report:**
- Does it fit naturally into your workflow?
- Any productivity improvements or hindrances?
- Missing features or enhancement ideas?

## 📞 Communication Channels

### Primary: Private Discord Server
**Invite Link:** [PROVIDED IN WELCOME EMAIL]

**Channels:**
- `#general` - General discussion and questions
- `#bug-reports` - Specific issues and bugs
- `#feature-requests` - Ideas and suggestions
- `#platform-macos` - macOS-specific testing
- `#platform-linux` - Linux-specific testing  
- `#platform-windows` - Windows WSL testing
- `#showcase` - Share interesting use cases

### Secondary: GitHub Issues
**Repository:** [PROVIDED IN WELCOME EMAIL]

Use GitHub for:
- Detailed bug reports with reproduction steps
- Feature requests with technical specifications
- Documentation feedback

### Tertiary: Direct Email
Use for:
- Private concerns or feedback
- Scheduling issues
- Technical problems preventing Discord/GitHub access

## 🐛 How to Report Issues

### Good Bug Reports Include:
1. **Platform & Environment**
   ```
   OS: macOS 14.3.1
   Shell: zsh 5.9
   Terminal: iTerm2
   Claude Code Version: [version]
   ```

2. **Reproduction Steps**
   ```bash
   1. Run: echo "test data" | ./claude-auto-tee.sh
   2. Check temp file: ls /tmp/claude-auto-tee-*
   3. Expected: File contains "test data"
   4. Actual: File is empty
   ```

3. **Actual vs Expected Behavior**
   - What happened?
   - What should have happened?
   - Any error messages?

4. **Additional Context**
   - Does it happen consistently?
   - Started after any changes?
   - Workarounds discovered?

### Bug Report Template
```markdown
**Environment:**
- OS: 
- Shell: 
- Terminal: 

**Bug Description:**
[Clear description of the issue]

**Steps to Reproduce:**
1. 
2. 
3. 

**Expected Behavior:**
[What should happen]

**Actual Behavior:**
[What actually happened]

**Additional Context:**
[Screenshots, logs, workarounds, etc.]
```

## 💡 Feature Request Guidelines

### Good Feature Requests Include:
1. **Use Case Description** - What problem does this solve?
2. **Proposed Solution** - How should it work?
3. **Alternative Solutions** - Other ways to solve the problem
4. **Priority/Impact** - How important is this to your workflow?

### Feature Request Template
```markdown
**Problem/Use Case:**
[Describe the problem or need]

**Proposed Solution:**
[How should this feature work?]

**Alternatives Considered:**
[Other possible solutions]

**Priority:**
- [ ] Critical (blocks testing)
- [ ] High (significant workflow improvement)
- [ ] Medium (nice to have)
- [ ] Low (minor enhancement)

**Additional Context:**
[Examples, mockups, references, etc.]
```

## ⏰ Testing Schedule & Expectations

### Weekly Expectations
- **2-4 hours total testing time**
- **At least 1 feedback submission** (bug, feature, or "everything works!")
- **Participation in Discord discussions** when available

### Weekly Focus Areas
**Week 1:** Installation, basic functionality, platform compatibility
**Week 2:** Advanced features, error scenarios, resource management  
**Week 3:** Real-world integration, workflow testing
**Week 4:** Final feedback, documentation review, polish

### Response Times
- **Discord messages:** Best effort, no pressure for immediate responses
- **Critical bugs:** 24-48 hours if possible
- **General feedback:** Weekly summary is fine

## 🎖️ Recognition & Rewards

### Beta Contributor Recognition
- **Release notes acknowledgment** - Listed as beta contributor
- **Early access to future features** - Priority access to new claude-auto-tee features  
- **Community recognition** - Special "Beta Tester" badge in Discord
- **Direct development influence** - Your feedback directly shapes the final product

### Optional Testimonials
If you'd like to provide a testimonial for the public release:
- **Quote for release announcement**
- **Case study of your use case** (if interesting/unique)
- **Social media mention** (@mention when we launch)

## 🚨 Important Reminders

### Beta Software Disclaimer
- This is **pre-release software** and may contain bugs
- **Don't use in production environments** until public release
- **Backup important data** before extensive testing
- **Report security concerns** immediately via private channels

### Confidentiality
- **Don't share beta software** outside the testing group
- **Don't post about it publicly** until public release
- **Keep private Discord/GitHub content private**
- **Feel free to discuss** general concepts or publicly-available info

### Getting Help
- **Discord #general** for quick questions
- **GitHub issues** for detailed technical problems
- **Direct email** for private concerns
- **Optional onboarding call** if you scheduled one

## 🤝 Community Guidelines

### Be Constructive
- Focus on improvement rather than criticism
- Provide actionable feedback when possible
- Consider the development constraints and timeline

### Be Respectful  
- Other testers have different use cases and priorities
- Development team is working hard to incorporate feedback
- Disagreements are fine, personal attacks are not

### Be Patient
- Not all feedback can be implemented immediately
- Some issues may be deferred to post-release
- Complex bugs may take time to investigate

---

## Quick Reference

**Discord:** [Link in welcome email]  
**GitHub:** [Link in welcome email]  
**Email:** [Provided separately]  

**Installation:** `chmod +x claude-auto-tee.sh`  
**Basic Test:** `echo "test" | ./claude-auto-tee.sh`  
**Check Output:** `ls /tmp/claude-auto-tee-*`  

**Need Help?** Start with Discord #general channel!

---

**Welcome to the team! Let's make claude-auto-tee amazing together! 🚀**