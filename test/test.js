#!/usr/bin/env node
/**
 * Tests for Claude Auto-Tee Hook
 */

const { execSync, spawn } = require('child_process');
const path = require('path');
const assert = require('assert');

const HOOK_PATH = path.join(__dirname, '..', 'src', 'hook.js');

// Test runner
async function runTests() {
  console.log('🧪 Running Claude Auto-Tee Tests\n');
  
  const tests = [
    testNonBashCommands,
    testSimpleBuildCommand,
    testPipelineInjection,
    testSkipRedirections,
    testSkipInteractiveCommands,
    testSkipExistingTee,
    testShortCommandSkip,
    testComplexPipelines,
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
  const cmd = result.tool.input.command;
  
  assert(cmd.includes('tee'), 'Should inject tee');
  assert(cmd.includes('/tmp/claude-'), 'Should use temp file');
  assert(cmd.includes('head -100'), 'Should add head truncation');
  assert(cmd.includes('Full output saved to:'), 'Should show temp file location');
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
  assert(!cmd.includes('| head'), 'Should not add head when tail exists');
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

async function testSkipInteractiveCommands() {
  const testCases = [
    'npm run dev',
    'yarn start', 
    'watch test',
    'npm run serve'
  ];
  
  for (const command of testCases) {
    const input = { tool: { name: 'Bash', input: { command } } };
    const result = await runHook(input);
    assert.deepEqual(result, input, `Interactive command "${command}" should pass through`);
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
  assert.deepEqual(result, input, 'Short commands should pass through');
}

async function testComplexPipelines() {
  const input = {
    tool: { 
      name: 'Bash', 
      input: { command: 'find . -name "*.ts" | grep -v node_modules | head -20' } 
    }
  };
  
  const result = await runHook(input);
  const cmd = result.tool.input.command;
  
  assert(cmd.includes('find . -name "*.ts" 2>&1 | tee'), 'Should inject tee after first command');
  assert(cmd.includes('| grep -v node_modules | head -20'), 'Should preserve rest of pipeline');
}

async function testErrorHandling() {
  // Test with malformed JSON
  const malformedInput = '{"tool": {"name": "Bash", "input"';
  
  return new Promise((resolve, reject) => {
    const child = spawn('node', [HOOK_PATH], { 
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
    // For now, just verify the installer exists
    const fs = require('fs');
    const installerPath = path.join(__dirname, '..', 'install.js');
    assert(fs.existsSync(installerPath), 'Installer should exist');
  } catch (error) {
    throw new Error(`Installation test failed: ${error.message}`);
  }
}

// Run tests if called directly
if (require.main === module) {
  runTests().catch(console.error);
}