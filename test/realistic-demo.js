#!/usr/bin/env node
/**
 * Realistic Claude Auto-Tee Demo
 * Shows the BEFORE/AFTER workflow that saves you from re-running expensive commands
 */

const { execSync, spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const HOOK_PATH = path.join(__dirname, '..', 'src', 'hook.js');

console.log('🎯 Realistic Claude Auto-Tee Demo\n');
console.log('This demonstrates the REAL problem this tool solves:\n');

async function runRealisticDemo() {
  console.log('📋 THE SCENARIO:');
  console.log('You want to find warning messages in a large codebase');
  console.log('You run an expensive command but filter wrong, miss what you need,');
  console.log('then have to re-run the expensive command. NOT ANYMORE!\n');
  
  console.log('═'.repeat(80));
  console.log('❌ BEFORE (The Pain): Re-running Expensive Commands');
  console.log('═'.repeat(80));
  
  console.log('\n1️⃣ First attempt - looking for "warning":');
  console.log('   💭 Claude thinks: "Let me search for warning messages"');
  console.log('   🤖 Command: find . -name "*.js" -exec grep -l "warning" {} \\; | head -5');
  console.log('   ⏰ *Expensive operation runs for 30 seconds*');
  console.log('   📤 Output: No files found');
  console.log('   😞 Result: Hmm, no matches. Maybe they use "Warning" with capital W?\n');
  
  console.log('2️⃣ Second attempt - looking for "Warning":');
  console.log('   🤖 Command: find . -name "*.js" -exec grep -l "Warning" {} \\; | head -5');  
  console.log('   ⏰ *Same expensive operation runs AGAIN for 30 seconds*');
  console.log('   📤 Output: No files found');
  console.log('   😫 Result: Still nothing. Maybe "WARNING" in all caps?\n');
  
  console.log('3️⃣ Third attempt - looking for "WARNING":');
  console.log('   🤖 Command: find . -name "*.js" -exec grep -l "WARNING" {} \\; | head -5');
  console.log('   ⏰ *Same expensive operation runs YET AGAIN for 30 seconds*');
  console.log('   💸 Cost: 90 seconds wasted, 3x the work\n');
  
  console.log('═'.repeat(80));
  console.log('✅ AFTER (The Solution): Auto-Tee Hook');
  console.log('═'.repeat(80));
  
  // Simulate what the hook would do
  const expensiveCommand = 'find . -name "*.js" -exec grep -H "warn" {} \\; | head -5';
  
  console.log('\n1️⃣ First attempt with auto-tee:');
  console.log('   💭 Claude thinks: "Let me search for warning messages"');
  console.log(`   🤖 Command: ${expensiveCommand}`);
  
  // Show the hook transformation
  const hookInput = { 
    tool: { 
      name: 'Bash', 
      input: { command: expensiveCommand } 
    } 
  };
  
  console.log('\n   🔄 AUTO-TEE TRANSFORMATION:');
  try {
    const result = await runHook(hookInput);
    const transformedCommand = result.tool.input.command;
    
    // Parse out the temp file for demo
    const tmpFileMatch = transformedCommand.match(/TMPFILE="([^"]+)"/);
    const tmpFile = tmpFileMatch ? tmpFileMatch[1] : '/tmp/claude-example.log';
    
    console.log('   📥 Original:', expensiveCommand);
    console.log('   📤 Transformed:');
    console.log(`   ${transformedCommand.replace(/\n/g, '\n   ')}`);
    
    console.log('\n   ⏰ *Expensive operation runs for 30 seconds*');
    console.log('   📤 Visible Output: (first 5 results)');
    console.log('       ./src/utils.js:15:  // warn user about deprecated API');
    console.log('       ./lib/logger.js:8:   console.warn("Performance issue detected");');
    console.log('       📝 Full output saved to:', tmpFile);
    
    console.log('\n   💡 Claude realizes: "I only see lowercase warn, let me check the full output"');
    console.log(`   🤖 Next command: Read(${tmpFile})`);
    console.log('   ⏰ *Instant - no re-running expensive command!*');
    console.log('   📤 Full Output Shows:');
    console.log('       ./src/utils.js:15:  // warn user about deprecated API');
    console.log('       ./lib/logger.js:8:   console.warn("Performance issue detected");');
    console.log('       ./components/Alert.js:23: showWarning("Invalid input");');
    console.log('       ./tests/warnings.test.js:45: expect(WARNING_MESSAGES).toContain...');
    console.log('       ./config/eslint.js:12: "no-console": "warn",');
    console.log('       ./docs/troubleshooting.md:89: **Warning:** This feature is experimental');
    
    console.log('\n   🎉 SUCCESS: Found all the variations without re-running!');
    console.log('   💰 Time saved: 60+ seconds (2 additional expensive runs avoided)');
    
  } catch (error) {
    console.log(`   ❌ Hook Error: ${error.message}`);
  }
  
  console.log('\n' + '═'.repeat(80));
  console.log('📊 COMPARISON SUMMARY');
  console.log('═'.repeat(80));
  console.log('❌ Without auto-tee:');
  console.log('   • Run expensive command 3x = 90 seconds');  
  console.log('   • High frustration, wasted time');
  console.log('   • Pattern: guess → run → fail → guess → run → fail → repeat\n');
  
  console.log('✅ With auto-tee:');
  console.log('   • Run expensive command 1x = 30 seconds');
  console.log('   • Read cached output instantly');
  console.log('   • Pattern: run → tee → explore → succeed');
  console.log('   • 60+ seconds saved, zero frustration\n');
  
  console.log('🎯 REAL WORLD EXAMPLES:');
  console.log('   • npm run build (fails) → check full output for real error');
  console.log('   • git log --oneline | grep "feature" → missed something? Check full log');  
  console.log('   • find large-codebase | grep pattern → wrong pattern? Check full results');
  console.log('   • test suite output | grep "failed" → want details? Full output ready\n');
  
  console.log('💡 The magic: You get BOTH the filtered view AND the full output automatically!');
}

// Helper to run hook with input  
function runHook(toolData) {
  return new Promise((resolve, reject) => {
    const child = spawn('node', [HOOK_PATH], { 
      stdio: ['pipe', 'pipe', 'pipe'] 
    });
    
    let stdout = '';
    let stderr = '';
    
    child.stdout.on('data', (data) => stdout += data);
    child.stderr.on('data', (data) => stderr += data);
    
    child.on('close', (code) => {
      if (code !== 0) {
        reject(new Error(`Hook failed: ${stderr}`));
        return;
      }
      
      try {
        const result = JSON.parse(stdout);
        resolve(result);
      } catch (error) {
        reject(new Error(`Invalid JSON: ${error.message}`));
      }
    });
    
    child.stdin.write(JSON.stringify(toolData));
    child.stdin.end();
  });
}

// Run demo if called directly
if (require.main === module) {
  runRealisticDemo().catch(console.error);
}