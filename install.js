#!/usr/bin/env node
/**
 * Claude Auto-Tee Installer
 * 
 * Slick DX for installing the auto-tee hook globally or locally
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const readline = require('readline');

const HOOK_PATH = path.join(__dirname, 'src', 'hook.js');

// Colors for pretty output
const colors = {
  cyan: '\x1b[36m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  bold: '\x1b[1m',
  reset: '\x1b[0m'
};

function colorize(color, text) {
  return `${colors[color]}${text}${colors.reset}`;
}

function showHelp() {
  console.log(colorize('bold', 'Usage:'));
  console.log('  claude-auto-tee [options]\n');
  
  console.log(colorize('bold', 'Options:'));
  console.log('  -g, --global     Install globally for all Claude Code sessions');
  console.log('  -l, --local      Install locally for current project only');
  console.log('  -u, --uninstall  Remove auto-tee hooks');
  console.log('  -h, --help       Show this help message\n');
  
  console.log(colorize('bold', 'Examples:'));
  console.log('  claude-auto-tee --global    # Install globally');
  console.log('  claude-auto-tee --local     # Install in current project');
  console.log('  claude-auto-tee --uninstall # Remove all hooks');
  console.log('  claude-auto-tee             # Interactive installer\n');
}

async function main() {
  console.log(colorize('cyan', '🚀 Claude Auto-Tee Installer\n'));
  console.log('This tool automatically injects `tee` into bash commands to save full output');
  console.log('while still showing you truncated results (head/tail).\n');
  
  console.log(colorize('yellow', 'Example transformation:'));
  console.log('  Input:  npm run build 2>&1 | tail -10');
  console.log('  Output: npm run build 2>&1 | tee /tmp/file.log | tail -10');
  console.log('          📝 Full output saved to: /tmp/file.log\n');

  // Check for CLI arguments
  const args = process.argv.slice(2);
  let choice = null;
  
  if (args.includes('--global') || args.includes('-g')) {
    choice = 'global';
  } else if (args.includes('--local') || args.includes('-l')) {
    choice = 'local';
  } else if (args.includes('--uninstall') || args.includes('-u')) {
    choice = 'uninstall';
  } else if (args.includes('--help') || args.includes('-h')) {
    showHelp();
    return;
  }
  
  if (!choice) {
    choice = await askChoice();
  }
  
  try {
    if (choice === 'global') {
      await installGlobal();
    } else if (choice === 'local') {
      await installLocal();
    } else {
      await uninstall();
    }
  } catch (error) {
    console.error(colorize('red', `❌ Installation failed: ${error.message}`));
    process.exit(1);
  }
}

function askChoice() {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  return new Promise((resolve) => {
    console.log('Choose installation type:');
    console.log('  1. Global   - Apply to all Claude Code sessions');
    console.log('  2. Local    - Apply only to current project'); 
    console.log('  3. Uninstall - Remove auto-tee hooks\n');
    
    rl.question('Enter your choice (1/2/3): ', (answer) => {
      rl.close();
      const choice = { '1': 'global', '2': 'local', '3': 'uninstall' }[answer.trim()];
      if (!choice) {
        console.log('Invalid choice, defaulting to local installation.');
        resolve('local');
      } else {
        resolve(choice);
      }
    });
  });
}

async function installGlobal() {
  const globalClaudeDir = path.join(os.homedir(), '.claude');
  const settingsFile = path.join(globalClaudeDir, 'settings.json');
  
  console.log(colorize('cyan', '📦 Installing globally...'));
  
  // Ensure ~/.claude directory exists
  if (!fs.existsSync(globalClaudeDir)) {
    fs.mkdirSync(globalClaudeDir, { recursive: true });
    console.log(`Created ${globalClaudeDir}`);
  }
  
  // Read or create settings
  let settings = {};
  if (fs.existsSync(settingsFile)) {
    try {
      settings = JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
      console.log('Found existing global settings');
    } catch (error) {
      console.log('Invalid existing settings, creating fresh configuration');
    }
  }
  
  // Add auto-tee hook
  if (!settings.hooks) settings.hooks = {};
  if (!settings.hooks.preToolUse) settings.hooks.preToolUse = [];
  
  // Remove existing auto-tee hooks
  settings.hooks.preToolUse = settings.hooks.preToolUse.filter(
    hook => !hook.command.includes('claude-auto-tee')
  );
  
  // Add new hook
  settings.hooks.preToolUse.push({
    command: HOOK_PATH,
    matchers: ['Bash']
  });
  
  // Write settings
  fs.writeFileSync(settingsFile, JSON.stringify(settings, null, 2));
  
  console.log(colorize('green', '✅ Installed globally!'));
  console.log(`Settings updated: ${settingsFile}`);
  console.log('\nAuto-tee will now apply to ALL Claude Code sessions.');
}

async function installLocal() {
  const localClaudeDir = path.join(process.cwd(), '.claude');
  const settingsFile = path.join(localClaudeDir, 'settings.json');
  
  console.log(colorize('cyan', '📦 Installing locally...'));
  
  // Ensure .claude directory exists
  if (!fs.existsSync(localClaudeDir)) {
    fs.mkdirSync(localClaudeDir, { recursive: true });
    console.log(`Created ${localClaudeDir}`);
  }
  
  // Read or create settings
  let settings = {};
  if (fs.existsSync(settingsFile)) {
    try {
      settings = JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
      console.log('Found existing local settings');
    } catch (error) {
      console.log('Invalid existing settings, creating fresh configuration');
    }
  }
  
  // Add auto-tee hook  
  if (!settings.hooks) settings.hooks = {};
  if (!settings.hooks.preToolUse) settings.hooks.preToolUse = [];
  
  // Remove existing auto-tee hooks
  settings.hooks.preToolUse = settings.hooks.preToolUse.filter(
    hook => !hook.command.includes('claude-auto-tee')
  );
  
  // Add new hook
  settings.hooks.preToolUse.push({
    command: HOOK_PATH,
    matchers: ['Bash']
  });
  
  // Write settings
  fs.writeFileSync(settingsFile, JSON.stringify(settings, null, 2));
  
  console.log(colorize('green', '✅ Installed locally!'));
  console.log(`Settings updated: ${settingsFile}`);
  console.log('\nAuto-tee will apply only to this project.');
}

async function uninstall() {
  console.log(colorize('cyan', '🗑️  Uninstalling...'));
  
  const locations = [
    path.join(os.homedir(), '.claude', 'settings.json'),    // Global
    path.join(process.cwd(), '.claude', 'settings.json')    // Local
  ];
  
  let removed = 0;
  
  for (const settingsFile of locations) {
    if (fs.existsSync(settingsFile)) {
      try {
        const settings = JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
        
        if (settings.hooks?.preToolUse) {
          const before = settings.hooks.preToolUse.length;
          settings.hooks.preToolUse = settings.hooks.preToolUse.filter(
            hook => !hook.command.includes('claude-auto-tee')
          );
          const after = settings.hooks.preToolUse.length;
          
          if (before !== after) {
            fs.writeFileSync(settingsFile, JSON.stringify(settings, null, 2));
            console.log(`Removed hooks from ${settingsFile}`);
            removed++;
          }
        }
      } catch (error) {
        console.log(`Could not process ${settingsFile}: ${error.message}`);
      }
    }
  }
  
  if (removed > 0) {
    console.log(colorize('green', `✅ Removed auto-tee hooks from ${removed} location(s)`));
  } else {
    console.log(colorize('yellow', '⚠️  No auto-tee hooks found to remove'));
  }
}

// Run installer
if (require.main === module) {
  main().catch(console.error);
}