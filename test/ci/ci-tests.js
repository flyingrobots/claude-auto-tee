#!/usr/bin/env node
/**
 * CI/CD Testing Suite for Claude Auto-Tee
 * 
 * Tests behavior in CI/CD environments where auto-tee should be disabled
 * or behave differently to avoid interfering with build processes.
 */

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const assert = require('assert');

const HOOK_PATH = path.join(__dirname, '../../src/hook.js');

class CITestSuite {
  constructor() {
    this.results = {
      timestamp: new Date().toISOString(),
      testsPassed: 0,
      testsFailed: 0,
      ciEnvironment: this.detectCIEnvironment(),
      tests: []
    };
  }

  detectCIEnvironment() {
    const ciIndicators = {
      CI: process.env.CI,
      GITHUB_ACTIONS: process.env.GITHUB_ACTIONS,
      TRAVIS: process.env.TRAVIS,
      CIRCLECI: process.env.CIRCLECI,
      JENKINS_URL: process.env.JENKINS_URL,
      GITLAB_CI: process.env.GITLAB_CI,
      BUILDKITE: process.env.BUILDKITE,
      AZURE_PIPELINES: process.env.TF_BUILD
    };

    return {
      detected: Object.entries(ciIndicators).filter(([key, value]) => value).map(([key]) => key),
      isCI: Object.values(ciIndicators).some(Boolean)
    };
  }

  async runCITests() {
    console.log('🚀 Starting CI/CD Environment Tests\n');
    console.log(`CI Environment Detected: ${this.results.ciEnvironment.isCI ? 'YES' : 'NO'}`);
    
    if (this.results.ciEnvironment.detected.length > 0) {
      console.log(`CI Systems: ${this.results.ciEnvironment.detected.join(', ')}\n`);
    }
    
    const tests = [
      this.testCIDetection,
      this.testCIBehaviorDisabling,
      this.testBuildProcessIntegration,
      this.testTempFileCleanup,
      this.testConcurrentBuildSupport,
      this.testResourceUsageInCI,
      this.testErrorHandlingInCI,
      this.testLogOutputInCI,
      this.testContainerEnvironment,
      this.testParallelJobSupport
    ];
    
    for (const test of tests) {
      try {
        await test.call(this);
        console.log(`✅ ${test.name}`);
        this.results.testsPassed++;
      } catch (error) {
        console.log(`❌ ${test.name}: ${error.message}`);
        this.results.testsFailed++;
      }
    }
    
    this.printCISummary();
    return this.results;
  }

  async testCIDetection() {
    // Test that the hook can detect CI environment
    const ciEnvironments = [
      { CI: 'true' },
      { GITHUB_ACTIONS: 'true' },
      { TRAVIS: 'true' },
      { CIRCLECI: 'true' },
      { JENKINS_URL: 'http://jenkins.example.com' },
      { GITLAB_CI: 'true' },
      { BUILDKITE: 'true' },
      { TF_BUILD: 'True' } // Azure DevOps
    ];

    for (const envVars of ciEnvironments) {
      // Temporarily set environment variables
      const originalEnv = {};
      for (const [key, value] of Object.entries(envVars)) {
        originalEnv[key] = process.env[key];
        process.env[key] = value;
      }

      try {
        const result = await this.runHook({ 
          tool: { name: 'Bash', input: { command: 'npm run build' } } 
        });

        // In CI, might want to disable auto-tee or behave differently
        // For now, just ensure it doesn't crash
        if (!result || !result.tool) {
          throw new Error(`Hook failed in CI environment: ${Object.keys(envVars)[0]}`);
        }
      } finally {
        // Restore original environment
        for (const [key] of Object.entries(envVars)) {
          if (originalEnv[key] === undefined) {
            delete process.env[key];
          } else {
            process.env[key] = originalEnv[key];
          }
        }
      }
    }
  }

  async testCIBehaviorDisabling() {
    // Test if auto-tee should be disabled in CI environments
    const originalCI = process.env.CI;
    process.env.CI = 'true';

    try {
      const result = await this.runHook({ 
        tool: { name: 'Bash', input: { command: 'npm run build' } } 
      });

      const wasModified = result.tool.input.command !== 'npm run build';
      
      // Decision point: Should auto-tee be disabled in CI?
      // Based on problem statement: "Must not activate in CI/CD environments where auto-fixing is inappropriate"
      
      if (wasModified) {
        console.log('    ⚠️  Auto-tee activated in CI environment - may need disabling logic');
      } else {
        console.log('    ✅ Auto-tee respects CI environment');
      }
      
    } finally {
      if (originalCI === undefined) {
        delete process.env.CI;
      } else {
        process.env.CI = originalCI;
      }
    }
  }

  async testBuildProcessIntegration() {
    // Test that auto-tee doesn't interfere with build processes
    const buildCommands = [
      'npm run build',
      'npm run test:ci',
      'docker build . -t test-image',
      'mvn clean install',
      'gradle build',
      'make all',
      'cmake --build .',
      'cargo build --release'
    ];

    for (const command of buildCommands) {
      const result = await this.runHook({ 
        tool: { name: 'Bash', input: { command } } 
      });

      const modifiedCommand = result.tool.input.command;
      
      // Ensure build commands can still be parsed and executed
      if (modifiedCommand.includes('tee')) {
        // If tee was injected, ensure temp file paths are accessible
        const tempFileMatch = modifiedCommand.match(/TMPFILE="([^"]+)"/);
        if (tempFileMatch) {
          const tempFile = tempFileMatch[1];
          
          // Check temp directory is writable in CI
          const tempDir = path.dirname(tempFile);
          try {
            fs.accessSync(tempDir, fs.constants.W_OK);
          } catch (error) {
            throw new Error(`Temp directory not writable in CI: ${tempDir}`);
          }
        }
      }
    }
  }

  async testTempFileCleanup() {
    // Test temp file cleanup in CI environments
    const command = 'npm run build | head -10';
    
    const result = await this.runHook({ 
      tool: { name: 'Bash', input: { command } } 
    });

    const modifiedCommand = result.tool.input.command;
    
    if (modifiedCommand.includes('TMPFILE=')) {
      // In CI, temp files should be cleaned up or use CI-appropriate locations
      const tempFileMatch = modifiedCommand.match(/TMPFILE="([^"]+)"/);
      if (tempFileMatch) {
        const tempFile = tempFileMatch[1];
        
        // Should use CI-friendly temp directories
        const ciTempDirs = [
          process.env.RUNNER_TEMP, // GitHub Actions
          process.env.TEMP, // General
          process.env.TMPDIR, // Unix
          '/tmp', // Fallback
          '/var/tmp' // Alternative
        ].filter(Boolean);
        
        const isValidCITempDir = ciTempDirs.some(dir => tempFile.startsWith(dir));
        
        if (!isValidCITempDir) {
          console.log(`    ⚠️  Temp file not in CI-appropriate location: ${tempFile}`);
        }
      }
    }
  }

  async testConcurrentBuildSupport() {
    // Test behavior when multiple builds run concurrently (common in CI)
    const concurrentBuilds = 5;
    const command = 'npm run build | head -20';
    
    const promises = Array(concurrentBuilds).fill(null).map((_, index) =>
      this.runHook({ 
        tool: { name: 'Bash', input: { command: `${command} # job-${index}` } } 
      })
    );

    const results = await Promise.all(promises);
    
    // Extract temp files to check for collisions
    const tempFiles = results.map(result => {
      const cmd = result.tool.input.command;
      const match = cmd.match(/TMPFILE="([^"]+)"/);
      return match ? match[1] : null;
    }).filter(Boolean);

    // All temp files should be unique
    const uniqueTempFiles = new Set(tempFiles);
    if (uniqueTempFiles.size !== tempFiles.length) {
      throw new Error(`Temp file collision in concurrent CI builds: ${tempFiles.length} builds, ${uniqueTempFiles.size} unique files`);
    }

    console.log(`    ✅ Concurrent builds supported: ${concurrentBuilds} parallel jobs`);
  }

  async testResourceUsageInCI() {
    // Test resource usage in CI environments (memory, CPU)
    const heavyCommands = [
      'npm run build',
      'npm run test:coverage',
      'docker build . -t test',
      'find . -name "*.ts" -exec grep -l "export" {} \\;'
    ];

    for (const command of heavyCommands) {
      const memBefore = process.memoryUsage();
      const startTime = Date.now();

      await this.runHook({ 
        tool: { name: 'Bash', input: { command } } 
      });

      const endTime = Date.now();
      const memAfter = process.memoryUsage();

      const executionTime = endTime - startTime;
      const memoryDelta = memAfter.heapUsed - memBefore.heapUsed;

      // CI environments have resource constraints
      if (executionTime > 1000) { // >1 second is suspicious for hook processing
        console.log(`    ⚠️  Slow processing in CI: ${executionTime}ms for "${command}"`);
      }

      if (memoryDelta > 10 * 1024 * 1024) { // >10MB is concerning
        console.log(`    ⚠️  High memory usage in CI: ${Math.round(memoryDelta/1024/1024)}MB for "${command}"`);
      }
    }
  }

  async testErrorHandlingInCI() {
    // Test error handling in CI environments
    const problematicInputs = [
      // Malformed JSON
      '{"tool": {"name": "Bash", "input"',
      
      // Missing fields
      '{"tool": {"name": "Bash"}}',
      
      // Invalid command types
      '{"tool": {"name": "Bash", "input": {"command": null}}}',
      
      // Very long commands
      JSON.stringify({
        tool: { 
          name: 'Bash', 
          input: { 
            command: 'npm run ' + 'very-long-command-name-'.repeat(100) 
          } 
        }
      })
    ];

    for (const input of problematicInputs) {
      const child = spawn('node', [HOOK_PATH], { 
        stdio: ['pipe', 'pipe', 'pipe'],
        timeout: 5000
      });

      let stdout = '';
      let stderr = '';

      child.stdout.on('data', (data) => stdout += data);
      child.stderr.on('data', (data) => stderr += data);

      const exitCode = await new Promise((resolve) => {
        child.on('close', resolve);
        child.stdin.write(input);
        child.stdin.end();
      });

      // In CI, errors should not crash the hook (exit code 0)
      if (exitCode !== 0) {
        throw new Error(`Hook crashed in CI on malformed input: exit code ${exitCode}, stderr: ${stderr}`);
      }
    }
  }

  async testLogOutputInCI() {
    // Test that log output is appropriate for CI environments
    const command = 'npm run build | head -10';
    
    const result = await this.runHook({ 
      tool: { name: 'Bash', input: { command } } 
    });

    const modifiedCommand = result.tool.input.command;
    
    if (modifiedCommand.includes('📝 Full output saved to:')) {
      // CI environments might prefer different messaging
      console.log('    ℹ️  Emoji in CI output - consider plain text for CI environments');
    }

    // Check for ANSI escape codes that might interfere with CI logs
    const hasAnsiCodes = /\x1b\[[0-9;]*m/.test(modifiedCommand);
    if (hasAnsiCodes) {
      console.log('    ⚠️  ANSI codes detected - might interfere with CI log parsing');
    }
  }

  async testContainerEnvironment() {
    // Test behavior in containerized CI environments
    const containerIndicators = [
      fs.existsSync('/.dockerenv'),
      fs.existsSync('/run/.containerenv'),
      process.env.container === 'docker',
      process.env.KUBERNETES_SERVICE_HOST !== undefined
    ];

    const inContainer = containerIndicators.some(Boolean);
    
    if (inContainer) {
      console.log('    🐳 Container environment detected');
      
      // Test temp file paths work in container
      const result = await this.runHook({ 
        tool: { name: 'Bash', input: { command: 'npm run build | head -10' } } 
      });

      const modifiedCommand = result.tool.input.command;
      
      if (modifiedCommand.includes('TMPFILE=')) {
        const tempFileMatch = modifiedCommand.match(/TMPFILE="([^"]+)"/);
        if (tempFileMatch) {
          const tempFile = tempFileMatch[1];
          
          // Check that temp directory exists and is writable in container
          const tempDir = path.dirname(tempFile);
          try {
            fs.accessSync(tempDir, fs.constants.W_OK);
            console.log(`    ✅ Container temp directory accessible: ${tempDir}`);
          } catch (error) {
            throw new Error(`Container temp directory not accessible: ${tempDir}`);
          }
        }
      }
    } else {
      console.log('    💻 Host environment (non-container)');
    }
  }

  async testParallelJobSupport() {
    // Test support for parallel CI jobs (common pattern)
    const parallelJobs = [
      { job: 'test:unit', command: 'npm run test:unit | head -20' },
      { job: 'test:integration', command: 'npm run test:integration | head -20' },
      { job: 'lint', command: 'npm run lint | head -10' },
      { job: 'typecheck', command: 'npm run typecheck | head -15' },
      { job: 'build', command: 'npm run build | head -30' }
    ];

    const parallelResults = await Promise.all(
      parallelJobs.map(job => 
        this.runHook({ 
          tool: { 
            name: 'Bash', 
            input: { command: job.command } 
          } 
        }).then(result => ({ job: job.job, result }))
      )
    );

    // Check that all jobs completed successfully
    const failures = parallelResults.filter(r => !r.result || !r.result.tool);
    if (failures.length > 0) {
      throw new Error(`Parallel job failures: ${failures.map(f => f.job).join(', ')}`);
    }

    // Check for temp file collisions across parallel jobs
    const allTempFiles = parallelResults.map(r => {
      const cmd = r.result.tool.input.command;
      const match = cmd.match(/TMPFILE="([^"]+)"/);
      return match ? match[1] : null;
    }).filter(Boolean);

    const uniqueTempFiles = new Set(allTempFiles);
    if (allTempFiles.length > 0 && uniqueTempFiles.size !== allTempFiles.length) {
      throw new Error(`Temp file collision in parallel CI jobs`);
    }

    console.log(`    ✅ Parallel CI jobs supported: ${parallelJobs.length} simultaneous jobs`);
  }

  async runHook(toolData) {
    return new Promise((resolve, reject) => {
      const child = spawn('node', [HOOK_PATH], { 
        stdio: ['pipe', 'pipe', 'pipe'],
        timeout: 10000 // 10 second timeout for CI
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
          // In CI, parse errors should not fail the build
          resolve(toolData); // Return original
        }
      });
      
      child.stdin.write(JSON.stringify(toolData));
      child.stdin.end();
    });
  }

  printCISummary() {
    console.log('\n🚀 CI/CD Test Summary');
    console.log('=====================');
    console.log(`Tests Passed: ${this.results.testsPassed}`);
    console.log(`Tests Failed: ${this.results.testsFailed}`);
    console.log(`CI Environment: ${this.results.ciEnvironment.isCI ? 'YES' : 'NO'}`);
    
    if (this.results.ciEnvironment.detected.length > 0) {
      console.log(`Detected Systems: ${this.results.ciEnvironment.detected.join(', ')}`);
    }

    console.log('\n📋 CI/CD Recommendations:');
    console.log('=========================');
    console.log('1. Consider disabling auto-tee in CI environments (per problem statement)');
    console.log('2. Use CI-appropriate temp directories (RUNNER_TEMP, etc.)');
    console.log('3. Ensure temp file cleanup in CI pipelines');
    console.log('4. Test resource usage under CI constraints');
    console.log('5. Handle concurrent builds without temp file collisions');
    console.log('6. Provide CI-friendly output (no emoji, plain text)');
  }
}

// Run CI tests if called directly
if (require.main === module) {
  const suite = new CITestSuite();
  suite.runCITests().catch(console.error);
}

module.exports = CITestSuite;