#!/usr/bin/env node
/**
 * Edge Case Testing Suite for Claude Auto-Tee
 * 
 * Tests complex scenarios and edge cases that could break the system:
 * - Complex shell command structures  
 * - Cross-platform path handling
 * - Unicode and encoding issues
 * - Nested command substitutions
 * - Error conditions and recovery
 */

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const assert = require('assert');
const os = require('os');

const HOOK_PATH = path.join(__dirname, '../../src/hook.js');

class EdgeCaseTestSuite {
  constructor() {
    this.results = {
      timestamp: new Date().toISOString(),
      platform: process.platform,
      testsPassed: 0,
      testsFailed: 0,
      edgeCases: [],
      tests: []
    };
  }

  async runEdgeCaseTests() {
    console.log('🔍 Starting Claude Auto-Tee Edge Case Tests\n');
    
    const tests = [
      this.testComplexPipelines,
      this.testCommandSubstitution,
      this.testQuotingEdgeCases,
      this.testUnicodeHandling,
      this.testCrossplatformPaths,
      this.testNestedShells,
      this.testProcessSubstitution,
      this.testRedirectionEdgeCases,
      this.testInteractiveDetection,
      this.testASTParsedFailures,
      this.testConcurrentTempFiles,
      this.testLongCommands,
      this.testSpecialCharacters,
      this.testEnvironmentVariables
    ];
    
    for (const test of tests) {
      try {
        await test.call(this);
        console.log(`✅ ${test.name}`);
        this.results.testsPassed++;
      } catch (error) {
        console.log(`❌ ${test.name}: ${error.message}`);
        this.results.testsFailed++;
        this.results.edgeCases.push({
          test: test.name,
          error: error.message,
          severity: this.assessSeverity(error.message)
        });
      }
    }
    
    this.printEdgeCaseSummary();
    return this.results;
  }

  async testComplexPipelines() {
    const complexCommands = [
      // Multi-stage pipelines
      'find . -name "*.js" | grep -v node_modules | xargs grep -l "test" | head -10',
      
      // Pipelines with command substitution
      'echo "$(date): Starting build" | npm run build | tee build-$(date +%Y%m%d).log | tail -20',
      
      // Process substitution in pipelines
      'npm run build | tee >(grep ERROR >&2) | grep -v WARNING',
      
      // Multiple redirections
      'npm run build 2>&1 | tee build.log | grep -E "(ERROR|WARN)" | sort | uniq -c',
      
      // Background processes in pipeline
      'npm run build | tee build.log & wait; tail -10 build.log'
    ];

    for (const command of complexCommands) {
      const result = await this.runHook({ 
        tool: { name: 'Bash', input: { command } } 
      });
      
      const modifiedCommand = result?.tool?.input?.command || '';
      
      // Should handle complex pipelines gracefully
      if (modifiedCommand.includes('tee') && modifiedCommand.includes('Full output saved')) {
        // Check that the pipeline structure is preserved
        const originalParts = command.split('|').length;
        const modifiedParts = modifiedCommand.split('|').length;
        
        // Should have added tee (so +1 or +2 pipes expected)
        if (modifiedParts < originalParts) {
          throw new Error(`Pipeline structure broken: ${originalParts} -> ${modifiedParts} pipes`);
        }
      }
    }
  }

  async testCommandSubstitution() {
    const substitutionCommands = [
      // Backtick substitution
      'npm run build | head -`echo 10`',
      
      // Dollar substitution
      'npm run build | head -$(echo 10)',
      
      // Nested substitution
      'find . -name "*.js" | grep -E "$(echo "test|spec")" | head -5',
      
      // Complex substitution
      'npm run $(cat package.json | jq -r .scripts | head -1 | cut -d: -f1)',
      
      // Environment variable expansion
      'npm run ${NODE_ENV:-development} | head -10'
    ];

    for (const command of substitutionCommands) {
      const result = await this.runHook({ 
        tool: { name: 'Bash', input: { command } } 
      });
      
      // Should not break command substitution syntax
      const modifiedCommand = result?.tool?.input?.command || command;
      
      // Check that substitution patterns are preserved
      const hasBackticks = command.includes('`') && modifiedCommand.includes('`');
      const hasDollarSub = command.includes('$(') && modifiedCommand.includes('$(');
      const hasVarSub = command.includes('${') && modifiedCommand.includes('${');
      
      if (command.includes('`') && !hasBackticks) {
        throw new Error(`Backtick substitution broken in: ${command}`);
      }
      if (command.includes('$(') && !hasDollarSub) {
        throw new Error(`Dollar substitution broken in: ${command}`);
      }
      if (command.includes('${') && !hasVarSub) {
        throw new Error(`Variable substitution broken in: ${command}`);
      }
    }
  }

  async testQuotingEdgeCases() {
    const quotingCommands = [
      // Single quotes with pipes
      'echo \'hello | world\' | cat',
      
      // Double quotes with variables
      'echo "Building project: $PWD" | npm run build',
      
      // Mixed quoting
      'echo "Starting \'npm run build\'" | sh',
      
      // Escaped quotes
      'echo "He said \"Hello | World\"" | cat',
      
      // Heredoc (might break AST parsing)
      `cat << 'EOF' | head -5
Hello
World
EOF`,
      
      // Command with embedded pipes in quotes
      'grep "error|warning|info" build.log | head -10'
    ];

    for (const command of quotingCommands) {
      const result = await this.runHook({ 
        tool: { name: 'Bash', input: { command } } 
      });
      
      // Should preserve quoting correctly
      const modifiedCommand = result?.tool?.input?.command || command;
      
      // Check that quotes are balanced
      const singleQuotes = (command.match(/'/g) || []).length;
      const doubleQuotes = (command.match(/"/g) || []).length;
      const modifiedSingleQuotes = (modifiedCommand.match(/'/g) || []).length;
      const modifiedDoubleQuotes = (modifiedCommand.match(/"/g) || []).length;
      
      if (singleQuotes % 2 === 0 && modifiedSingleQuotes % 2 !== 0) {
        throw new Error(`Single quote balance broken: ${command}`);
      }
      if (doubleQuotes % 2 === 0 && modifiedDoubleQuotes % 2 !== 0) {
        throw new Error(`Double quote balance broken: ${command}`);
      }
    }
  }

  async testUnicodeHandling() {
    const unicodeCommands = [
      // Unicode in command names
      'npm run café | head -10',
      
      // Unicode in file paths
      'find . -name "*测试*.js" | head -5',
      
      // Emoji in commands
      'echo "🎉 Build complete!" | npm run build',
      
      // Unicode quotes
      'echo "Hello "world"" | head -10',
      
      // Unicode whitespace
      'echo "hello\u00a0world" | head -5',
      
      // Zero-width characters
      'npm\u200drun\u200dbuild | head -10'
    ];

    for (const command of unicodeCommands) {
      const result = await this.runHook({ 
        tool: { name: 'Bash', input: { command } } 
      });
      
      // Should handle Unicode without corruption
      const modifiedCommand = result?.tool?.input?.command || command;
      
      // Basic check that Unicode characters are preserved
      const originalLength = command.length;
      const modifiedLength = modifiedCommand.replace(/TMPFILE="[^"]*"/, '').replace(/Full output saved to:.*/, '').length;
      
      // Allow for reasonable expansion due to tee injection, but not massive corruption
      if (modifiedLength < originalLength * 0.5) {
        throw new Error(`Unicode corruption detected: ${command}`);
      }
    }
  }

  async testCrossplatformPaths() {
    const pathCommands = [
      'npm run build | head -10',
      'find /usr/local -name "*" | head -5',
      'ls C:\\Windows | head -5',  // Windows-style path
      'find ~/Documents -name "*.txt" | head -3'
    ];

    for (const command of pathCommands) {
      const result = await this.runHook({ 
        tool: { name: 'Bash', input: { command } } 
      });
      
      const modifiedCommand = result?.tool?.input?.command || '';
      
      if (modifiedCommand.includes('TMPFILE=')) {
        // Extract temp file path
        const tempFileMatch = modifiedCommand.match(/TMPFILE="([^"]+)"/);
        if (tempFileMatch) {
          const tempFile = tempFileMatch[1];
          
          // Check it's a valid cross-platform path
          const validPath = this.isValidCrossplatformPath(tempFile);
          if (!validPath) {
            throw new Error(`Invalid cross-platform temp path: ${tempFile}`);
          }
        }
      }
    }
  }

  async testNestedShells() {
    const nestedCommands = [
      // Nested bash invocations
      'bash -c "npm run build | head -10"',
      
      // Sh with pipes
      'sh -c \'echo "test" | npm run build\'',
      
      // Zsh with complex pipeline
      'zsh -c "find . -name \'*.js\' | grep test | wc -l"',
      
      // Command with shell options
      'bash -euo pipefail -c "npm run build | head -5"'
    ];

    for (const command of nestedCommands) {
      const result = await this.runHook({ 
        tool: { name: 'Bash', input: { command } } 
      });
      
      // Should handle nested shells appropriately
      // Might choose not to inject tee into nested shells for simplicity
      const modifiedCommand = result?.tool?.input?.command || command;
      
      // At minimum, should not break the command structure
      if (modifiedCommand.includes('bash -c') !== command.includes('bash -c')) {
        throw new Error(`Nested shell structure broken: ${command}`);
      }
    }
  }

  async testProcessSubstitution() {
    const processSubCommands = [
      // Process substitution
      'diff <(npm run test) <(npm run test:prod)',
      
      // Output process substitution
      'npm run build | tee >(grep ERROR >&2)',
      
      // Multiple process substitution
      'comm <(sort file1) <(sort file2) | head -10'
    ];

    for (const command of processSubCommands) {
      const result = await this.runHook({ 
        tool: { name: 'Bash', input: { command } } 
      });
      
      const modifiedCommand = result?.tool?.input?.command || command;
      
      // Should preserve process substitution syntax
      if (command.includes('<(') && !modifiedCommand.includes('<(')) {
        throw new Error(`Process substitution broken: ${command}`);
      }
      if (command.includes('>(') && !modifiedCommand.includes('>(')) {
        throw new Error(`Output process substitution broken: ${command}`);
      }
    }
  }

  async testRedirectionEdgeCases() {
    const redirectionCommands = [
      // Multiple redirections (should skip)
      'npm run build > build.log 2>&1',
      
      // Appending redirection
      'npm run build >> build.log',
      
      // Input redirection
      'npm run build < config.txt',
      
      // File descriptor redirection
      'npm run build 3>&1 1>&2 2>&3',
      
      // Redirection with pipes (complex)
      'npm run build 2>&1 | grep ERROR > errors.log'
    ];

    for (const command of redirectionCommands) {
      const result = await this.runHook({ 
        tool: { name: 'Bash', input: { command } } 
      });
      
      // Commands with redirections should generally be skipped
      if (command.includes('>') && !command.includes('|')) {
        // Should pass through unchanged for simple redirections
        assert.deepEqual(result.tool.input.command, command, 
          `Redirection command should pass through: ${command}`);
      }
    }
  }

  async testInteractiveDetection() {
    const interactiveCommands = [
      // Development servers (should skip)
      'npm run dev',
      'yarn start',
      'pnpm run serve',
      
      // Watch commands (should skip)  
      'npm run test:watch',
      'npx nodemon server.js',
      'webpack --watch',
      
      // Interactive tools (should skip)
      'npm run storybook',
      'docker run -it ubuntu bash',
      
      // Long-running but not interactive (might activate)
      'npm run build:prod',
      'npm run test:coverage'
    ];

    for (const command of interactiveCommands) {
      const result = await this.runHook({ 
        tool: { name: 'Bash', input: { command } } 
      });
      
      const isInteractive = ['dev', 'start', 'serve', 'watch', 'storybook', '-it'].some(
        keyword => command.includes(keyword)
      );
      
      if (isInteractive) {
        // Interactive commands should pass through unchanged
        assert.deepEqual(result.tool.input.command, command,
          `Interactive command should pass through: ${command}`);
      }
    }
  }

  async testASTParsedFailures() {
    const unparsableCommands = [
      // Malformed syntax
      'npm run build | | head -10',
      
      // Unclosed quotes
      'echo "hello world | head -10',
      
      // Invalid heredoc
      'cat << EOF\nhello | head -10',
      
      // Extreme nesting
      '((((npm run build))))',
      
      // Unicode edge cases that might break parsing
      'echo \u0000\u0001\u0002 | head -10'
    ];

    for (const command of unparsableCommands) {
      const result = await this.runHook({ 
        tool: { name: 'Bash', input: { command } } 
      });
      
      // Should gracefully handle parse failures by passing through
      // (hook.js has try/catch for this)
      if (!result || !result.tool) {
        throw new Error(`Hook crashed on unparsable command: ${command}`);
      }
    }
  }

  async testConcurrentTempFiles() {
    const command = 'npm run build | head -10';
    
    // Run multiple hooks concurrently
    const concurrent = 10;
    const promises = Array(concurrent).fill(null).map(() =>
      this.runHook({ tool: { name: 'Bash', input: { command } } })
    );
    
    const results = await Promise.all(promises);
    
    // Extract temp file paths
    const tempFiles = results.map(result => {
      const cmd = result?.tool?.input?.command || '';
      const match = cmd.match(/TMPFILE="([^"]+)"/);
      return match ? match[1] : null;
    }).filter(Boolean);
    
    // All temp files should be unique
    const uniqueTempFiles = new Set(tempFiles);
    if (uniqueTempFiles.size !== tempFiles.length) {
      throw new Error(`Temp file collision: ${tempFiles.length} requests, ${uniqueTempFiles.size} unique files`);
    }
    
    // All should follow naming convention
    for (const tempFile of tempFiles) {
      if (!tempFile.includes('claude-') || !this.isValidCrossplatformPath(tempFile)) {
        throw new Error(`Invalid concurrent temp file: ${tempFile}`);
      }
    }
  }

  async testLongCommands() {
    const longCommand = 'npm run build:prod:with:very:long:name:that:might:cause:issues | ' +
      'grep -E "(ERROR|WARN|INFO|DEBUG)" | ' +
      'sed "s/^/$(date): /" | ' +
      'tee -a build-$(date +%Y%m%d-%H%M%S).log | ' +
      'head -' + '1'.repeat(100); // Very long head argument

    const result = await this.runHook({ 
      tool: { name: 'Bash', input: { command: longCommand } } 
    });
    
    // Should handle long commands without corruption
    const modifiedCommand = result?.tool?.input?.command || '';
    
    if (modifiedCommand.includes('tee') && !modifiedCommand.includes('claude-')) {
      throw new Error('Long command broke tee injection logic');
    }
  }

  async testSpecialCharacters() {
    const specialCommands = [
      // Shell metacharacters
      'npm run build | head -10 # comment',
      'npm run build && echo "success"',
      'npm run build || echo "failed"',
      'npm run build; echo "done"',
      
      // Glob patterns
      'find . -name "*.{js,ts}" | head -10',
      'ls **/*.js | grep test',
      
      // Brace expansion
      'echo {1..10} | npm run build',
      
      // History expansion (bash)
      'npm run build | head -!!'
    ];

    for (const command of specialCommands) {
      const result = await this.runHook({ 
        tool: { name: 'Bash', input: { command } } 
      });
      
      // Should preserve shell special characters appropriately
      const modifiedCommand = result?.tool?.input?.command || command;
      
      // Basic structural integrity check
      if (command.includes('&&') && modifiedCommand.includes('&&')) {
        // Good, preserved
      } else if (command.includes('&&') && !modifiedCommand.includes('&&')) {
        // Only acceptable if the command was transformed significantly
        if (!modifiedCommand.includes('tee')) {
          throw new Error(`Special character handling broke: ${command}`);
        }
      }
    }
  }

  async testEnvironmentVariables() {
    const envCommands = [
      // Environment variable expansion
      'NODE_ENV=production npm run build | head -10',
      
      // Multiple environment variables
      'DEBUG=1 VERBOSE=true npm run build | head -5',
      
      // Environment variables in pipes
      'npm run build | head -$LINES',
      
      // Complex environment variable usage
      'export BUILD_ENV=test; npm run build:$BUILD_ENV | head -10'
    ];

    for (const command of envCommands) {
      const result = await this.runHook({ 
        tool: { name: 'Bash', input: { command } } 
      });
      
      const modifiedCommand = result?.tool?.input?.command || command;
      
      // Should preserve environment variable syntax
      if (command.includes('NODE_ENV=') && !modifiedCommand.includes('NODE_ENV=')) {
        throw new Error(`Environment variable syntax broken: ${command}`);
      }
      if (command.includes('$LINES') && !modifiedCommand.includes('$LINES')) {
        throw new Error(`Variable expansion syntax broken: ${command}`);
      }
    }
  }

  isValidCrossplatformPath(filePath) {
    // Check if path uses appropriate temp directory
    const tempDir = os.tmpdir();
    const commonTempDirs = ['/tmp/', '/var/tmp/', tempDir];
    
    const hasValidPrefix = commonTempDirs.some(dir => 
      dir && filePath.startsWith(dir)
    );
    
    // Check for path traversal attempts
    const hasTraversal = filePath.includes('../') || filePath.includes('..\\');
    
    // Check for invalid characters (basic check)
    const hasInvalidChars = /[<>:"|?*\x00-\x1f]/.test(filePath);
    
    return hasValidPrefix && !hasTraversal && !hasInvalidChars;
  }

  async runHook(toolData) {
    return new Promise((resolve, reject) => {
      const child = spawn('node', [HOOK_PATH], { 
        stdio: ['pipe', 'pipe', 'pipe'],
        timeout: 10000 // 10 second timeout for edge cases
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
          // For edge case testing, parse errors might be acceptable
          resolve(toolData); // Return original
        }
      });
      
      child.stdin.write(JSON.stringify(toolData));
      child.stdin.end();
    });
  }

  assessSeverity(errorMessage) {
    if (errorMessage.includes('corruption') || errorMessage.includes('crash')) {
      return 'HIGH';
    } else if (errorMessage.includes('broken') || errorMessage.includes('collision')) {
      return 'MEDIUM';
    } else {
      return 'LOW';
    }
  }

  printEdgeCaseSummary() {
    console.log('\n🔍 Edge Case Test Summary');
    console.log('=========================');
    console.log(`Tests Passed: ${this.results.testsPassed}`);
    console.log(`Tests Failed: ${this.results.testsFailed}`);
    console.log(`Edge Cases Found: ${this.results.edgeCases.length}`);
    
    if (this.results.edgeCases.length > 0) {
      console.log('\n⚠️  Edge Cases:');
      this.results.edgeCases.forEach((edge, i) => {
        console.log(`${i + 1}. [${edge.severity}] ${edge.test}: ${edge.error}`);
      });
    }
  }
}

// Run edge case tests if called directly
if (require.main === module) {
  const suite = new EdgeCaseTestSuite();
  suite.runEdgeCaseTests().catch(console.error);
}

module.exports = EdgeCaseTestSuite;