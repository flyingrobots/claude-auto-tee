#!/usr/bin/env node
/**
 * Test cleanup functionality for Claude Auto-Tee Hook
 * P1.T013: Implement cleanup on successful completion
 */

const { execSync, spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const assert = require('assert');

const HOOK_PATH = path.join(__dirname, '..', 'src', 'claude-auto-tee.sh');

// Test runner
async function runCleanupTests() {
  console.log('🧹 Testing Cleanup Functionality\n');
  
  const tests = [
    testCleanupOnSuccess,
    testPreservationOnFailure,
    testCleanupInVerboseMode
  ];
  
  let passed = 0;
  let failed = 0;
  
  for (const test of tests) {
    try {
      await test();
      console.log(`✅ ${test.name}`);
      passed++;
    } catch (error) {
      console.log(`❌ ${test.name}: ${error.message}`);
      failed++;
    }
  }
  
  console.log(`\n📊 Cleanup Test Results: ${passed} passed, ${failed} failed`);
  
  if (failed > 0) {
    process.exit(1);
  }
}

// Helper to run bash hook with input
function runHook(toolData, env = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn('bash', [HOOK_PATH], { 
      stdio: ['pipe', 'pipe', 'pipe'],
      env: { ...process.env, ...env }
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
        resolve({ result, stderr });
      } catch (error) {
        reject(new Error(`Invalid JSON output: ${error.message}`));
      }
    });
    
    child.stdin.write(JSON.stringify(toolData));
    child.stdin.end();
  });
}

// Test successful command cleanup
async function testCleanupOnSuccess() {
  const input = {
    tool: { 
      name: 'Bash', 
      input: { command: 'echo "test output" | head -1' } 
    }
  };
  
  const { result } = await runHook(input);
  const cmd = result.tool.input.command;
  
  // Verify cleanup logic is injected
  assert(cmd.includes('cleanup_temp_file'), 'Should include cleanup function call');
  assert(cmd.includes('source'), 'Should source cleanup script');
  assert(cmd.includes('rm -f'), 'Should cleanup the cleanup script itself');
  
  // The command should have conditional cleanup
  assert(cmd.includes('&&'), 'Should use conditional execution for cleanup');
  assert(cmd.includes('||'), 'Should handle command failure case');
}

// Test that files are preserved on failure
async function testPreservationOnFailure() {
  const input = {
    tool: { 
      name: 'Bash', 
      input: { command: 'false | echo "this will fail"' } 
    }
  };
  
  const { result } = await runHook(input);
  const cmd = result.tool.input.command;
  
  // Should preserve file on failure
  assert(cmd.includes('temp file preserved'), 'Should preserve temp file on failure');
  assert(cmd.includes('Command failed'), 'Should indicate command failure');
}

// Test cleanup with verbose mode
async function testCleanupInVerboseMode() {
  const input = {
    tool: { 
      name: 'Bash', 
      input: { command: 'echo "verbose test" | cat' } 
    }
  };
  
  const { result, stderr } = await runHook(input, { CLAUDE_AUTO_TEE_VERBOSE: 'true' });
  
  // Should show verbose logging for cleanup
  assert(stderr.includes('cleanup script'), 'Should log cleanup script creation');
  assert(stderr.includes('cleanup logic'), 'Should log cleanup logic addition');
}

// Run tests if called directly
if (require.main === module) {
  runCleanupTests().catch(console.error);
}

module.exports = { runCleanupTests };