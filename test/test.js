#!/usr/bin/env node
/**
 * Tests for Claude Auto-Tee Hook
 */

const { execSync, spawn } = require('child_process');
const path = require('path');
const assert = require('assert');

const HOOK_PATH = path.join(__dirname, '..', 'src', 'claude-auto-tee.sh');

// Test runner
async function runTests() {
  console.log('🧪 Running Claude Auto-Tee Tests\n');
  
  const tests = [
    testNonBashCommands,
    testSimpleBuildCommand,
    testPipelineInjection,
    testSkipRedirections,
    testSkipNonPipeCommands,
    testSkipExistingTee,
    testShortCommandSkip,
    testComplexPipelines,
    testPipeOnlyDetection,
    testErrorHandling
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
  
  console.log(`\n📊 Results: ${passed} passed, ${failed} failed`);
  
  if (failed > 0) {
    process.exit(1);
  }
}

// Helper to run bash hook with input
function runHook(toolData) {
  return new Promise((resolve, reject) => {
    const child = spawn('bash', [HOOK_PATH], { 
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

// Test Cases

async function testNonBashCommands() {
  const input = {
    tool: { name: 'Read', input: { file_path: 'test.txt' } }
  };
  
  const result = await runHook(input);
  assert.deepEqual(result, input, 'Non-bash commands should pass through unchanged');
}

async function testSimpleBuildCommand() {
  const input = {
    tool: { 
      name: 'Bash', 
      input: { command: 'npm run build' } 
    }
  };
  
  const result = await runHook(input);
  
  // New implementation: no pipes = no activation
  assert.deepEqual(result, input, 'Commands without pipes should pass through unchanged');
}

async function testPipelineInjection() {
  const input = {
    tool: { 
      name: 'Bash', 
      input: { command: 'npm run build 2>&1 | tail -10' } 
    }
  };
  
  const result = await runHook(input);
  const cmd = result.tool.input.command;
  
  assert(cmd.includes('| tee'), 'Should inject tee into pipeline');
  assert(cmd.includes('| tail -10'), 'Should preserve existing tail');
  assert(cmd.includes('claude-') && cmd.includes('.log'), 'Should use temp file with claude prefix');
  assert(cmd.includes('Full output saved to:'), 'Should show temp file location');
}

async function testSkipRedirections() {
  const input = {
    tool: { 
      name: 'Bash', 
      input: { command: 'npm run build > output.txt' } 
    }
  };
  
  const result = await runHook(input);
  assert.deepEqual(result, input, 'Commands with redirections should pass through');
}

async function testSkipNonPipeCommands() {
  const testCases = [
    'npm run dev',
    'yarn start', 
    'npm run build',
    'find . -name "*.js"',
    'git log --oneline'
  ];
  
  for (const command of testCases) {
    const input = { tool: { name: 'Bash', input: { command } } };
    const result = await runHook(input);
    assert.deepEqual(result, input, `Non-pipe command "${command}" should pass through`);
  }
}

async function testSkipExistingTee() {
  const input = {
    tool: { 
      name: 'Bash', 
      input: { command: 'npm run build | tee output.log' } 
    }
  };
  
  const result = await runHook(input);
  assert.deepEqual(result, input, 'Commands with existing tee should pass through');
}

async function testShortCommandSkip() {
  const input = {
    tool: { 
      name: 'Bash', 
      input: { command: 'ls' } 
    }
  };
  
  const result = await runHook(input);
  assert.deepEqual(result, input, 'Commands without pipes should pass through');
}

async function testComplexPipelines() {
  const input = {
    tool: { 
      name: 'Bash', 
      input: { command: 'ls -la | grep -v node_modules | head -20' } 
    }
  };
  
  const result = await runHook(input);
  
  // After security hardening: multiple pipes are passed through unchanged for security
  assert.deepEqual(result, input, 'Multi-pipe commands should pass through unchanged for security');
}

async function testPipeOnlyDetection() {
  // Test the core pipe-only logic
  const testCases = [
    // Should activate (has pipe, no existing tee)
    { command: 'npm run build | head -10', shouldActivate: true },
    { command: 'ls -la | grep test', shouldActivate: true },
    { command: 'ls -la | wc -l', shouldActivate: true },
    { command: 'echo test | cat', shouldActivate: true },
    
    // Should NOT activate (no pipes)
    { command: 'npm run build', shouldActivate: false },
    { command: 'find . -name "*.js"', shouldActivate: false },
    { command: 'ls -la', shouldActivate: false },
    { command: 'echo "test"', shouldActivate: false },
    
    // Should NOT activate (already has tee)
    { command: 'npm run build | tee output.log', shouldActivate: false },
    { command: 'find . -name "*.js" | tee results.txt | head -10', shouldActivate: false }
  ];

  for (const testCase of testCases) {
    const input = { tool: { name: 'Bash', input: { command: testCase.command } } };
    const result = await runHook(input);
    
    const wasActivated = result.tool.input.command !== testCase.command && 
                        result.tool.input.command.includes('tee');
    
    assert.strictEqual(wasActivated, testCase.shouldActivate, 
      `Pipe detection failed for: "${testCase.command}" (expected ${testCase.shouldActivate}, got ${wasActivated})`);
  }
}

async function testErrorHandling() {
  // Test with malformed JSON
  const malformedInput = '{"tool": {"name": "Bash", "input"';
  
  return new Promise((resolve, reject) => {
    const child = spawn('bash', [HOOK_PATH], { 
      stdio: ['pipe', 'pipe', 'pipe'] 
    });
    
    let stderr = '';
    child.stderr.on('data', (data) => stderr += data);
    
    child.on('close', (code) => {
      if (code === 0) {
        resolve(); // Hook should handle errors gracefully
      } else {
        reject(new Error('Hook should not crash on malformed input'));
      }
    });
    
    child.stdin.write(malformedInput);
    child.stdin.end();
  });
}

// Integration test - verify hook can be installed
async function testInstallation() {
  try {
    // This would test the actual installation, but requires file system changes
    // For now, just verify the bash script exists
    const fs = require('fs');
    const scriptPath = path.join(__dirname, '..', 'src', 'claude-auto-tee.sh');
    assert(fs.existsSync(scriptPath), 'Bash script should exist');
  } catch (error) {
    throw new Error(`Installation test failed: ${error.message}`);
  }
}

// Run tests if called directly
if (require.main === module) {
  runTests().catch(console.error);
}

module.exports = { runTests };