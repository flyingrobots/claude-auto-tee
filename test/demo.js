#!/usr/bin/env node
/**
 * Claude Auto-Tee Demo
 * Shows how the hook transforms commands in a safe sandboxed environment
 */

const { execSync, spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const HOOK_PATH = path.join(__dirname, '..', 'src', 'hook.js');

console.log('🎭 Claude Auto-Tee Demo\n');
console.log('This shows how the hook transforms bash commands safely in Docker.\n');

// Demo cases to show
const demoCases = [
  {
    name: 'Simple Build Command',
    input: { tool: { name: 'Bash', input: { command: 'npm run build' } } },
    description: 'Should inject tee + head truncation'
  },
  {
    name: 'Pipeline with Tail',
    input: { tool: { name: 'Bash', input: { command: 'npm run test 2>&1 | tail -10' } } },
    description: 'Should inject tee BEFORE existing tail'
  },
  {
    name: 'Interactive Command (Skip)',
    input: { tool: { name: 'Bash', input: { command: 'npm run dev' } } },
    description: 'Should pass through unchanged (interactive)'
  },
  {
    name: 'With Redirection (Skip)',
    input: { tool: { name: 'Bash', input: { command: 'npm run build > output.txt' } } },
    description: 'Should pass through unchanged (has redirection)'
  },
  {
    name: 'Complex Pipeline',
    input: { tool: { name: 'Bash', input: { command: 'find . -name "*.js" | grep -v node_modules | head -20' } } },
    description: 'Should inject tee after find command'
  },
  {
    name: 'Non-Bash Tool (Skip)',
    input: { tool: { name: 'Read', input: { file_path: 'test.txt' } } },
    description: 'Should pass through unchanged (not bash)'
  }
];

async function runDemo() {
  for (let i = 0; i < demoCases.length; i++) {
    const testCase = demoCases[i];
    console.log(`${i + 1}. ${testCase.name}`);
    console.log(`   ${testCase.description}\n`);
    
    console.log('   📥 INPUT:');
    console.log(`   ${JSON.stringify(testCase.input, null, 4)}\n`);
    
    try {
      const result = await runHook(testCase.input);
      
      console.log('   📤 OUTPUT:');
      if (JSON.stringify(result) === JSON.stringify(testCase.input)) {
        console.log('   ✅ UNCHANGED (passed through)');
      } else {
        console.log(`   ${JSON.stringify(result, null, 4)}`);
        
        if (result.tool?.input?.command !== testCase.input.tool?.input?.command) {
          console.log('\n   🔄 COMMAND TRANSFORMATION:');
          console.log(`   Before: ${testCase.input.tool?.input?.command || 'N/A'}`);
          console.log(`   After:  ${result.tool?.input?.command || 'N/A'}`);
        }
      }
    } catch (error) {
      console.log(`   ❌ ERROR: ${error.message}`);
    }
    
    console.log('\n' + '─'.repeat(80) + '\n');
  }
  
  console.log('🎉 Demo complete!\n');
  console.log('💡 In real usage, Claude Code would:');
  console.log('   1. Send the original command to the hook');
  console.log('   2. Execute the transformed command');
  console.log('   3. Show you the truncated output + temp file location');
  console.log('   4. Save full output to /tmp/claude-*.log for later inspection\n');
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
        reject(new Error(`Hook failed with code ${code}: ${stderr}`));
        return;
      }
      
      try {
        const result = JSON.parse(stdout);
        resolve(result);
      } catch (error) {
        reject(new Error(`Invalid JSON output: ${error.message}`));
      }
    });
    
    child.stdin.write(JSON.stringify(toolData));
    child.stdin.end();
  });
}

// Run demo if called directly
if (require.main === module) {
  runDemo().catch(console.error);
}