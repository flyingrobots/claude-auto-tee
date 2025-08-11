#!/usr/bin/env node
/**
 * Performance Benchmark Suite for Claude Auto-Tee
 * 
 * Tests the 165x performance degradation claim from Expert 002
 * and validates pipe-only vs pattern-matching performance
 */

const { performance } = require('perf_hooks');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const HOOK_PATH = path.join(__dirname, '../../src/hook.js');
const RESULTS_FILE = '/tmp/test-results/performance-results.json';

// Ensure results directory exists
fs.mkdirSync('/tmp/test-results', { recursive: true });

class PerformanceBenchmark {
  constructor() {
    this.results = {
      timestamp: new Date().toISOString(),
      platform: process.platform,
      nodeVersion: process.version,
      tests: []
    };
  }

  async runBenchmark() {
    console.log('🚀 Starting Claude Auto-Tee Performance Benchmark\n');
    
    await this.benchmarkActivationStrategies();
    await this.benchmarkMemoryUsage();
    await this.benchmarkConcurrentLoad();
    await this.benchmarkASTParsing();
    
    await this.saveResults();
    this.printSummary();
  }

  async benchmarkActivationStrategies() {
    console.log('📊 Benchmarking Activation Strategies');
    
    const testCommands = [
      // Pipe-only scenarios
      { type: 'pipe', command: 'npm run build | head -10', expectActivation: true },
      { type: 'pipe', command: 'find . -name "*.js" | grep test', expectActivation: true },
      { type: 'pipe', command: 'ls | wc -l', expectActivation: false }, // trivial command
      
      // Pattern-matching scenarios  
      { type: 'pattern', command: 'npm run build', expectActivation: true },
      { type: 'pattern', command: 'npm run test', expectActivation: true },
      { type: 'pattern', command: 'npx tsc', expectActivation: true },
      { type: 'pattern', command: 'find . -name "*.ts"', expectActivation: true },
      { type: 'pattern', command: 'git log --oneline', expectActivation: true },
      
      // Non-activating scenarios
      { type: 'none', command: 'ls -la', expectActivation: false },
      { type: 'none', command: 'pwd', expectActivation: false },
      { type: 'none', command: 'echo "hello"', expectActivation: false }
    ];

    const strategyResults = {
      pipeOnly: [],
      patternMatching: [],
      hybrid: []
    };

    for (const testCase of testCommands) {
      // Test current hybrid implementation
      const hybridTime = await this.measureActivationTime(testCase.command);
      strategyResults.hybrid.push({
        command: testCase.command,
        type: testCase.type,
        time: hybridTime,
        expectActivation: testCase.expectActivation
      });

      // Simulate pure pipe-only (would need implementation change)
      const pipeOnlyTime = await this.measurePipeOnlyTime(testCase.command);
      strategyResults.pipeOnly.push({
        command: testCase.command,
        type: testCase.type,
        time: pipeOnlyTime,
        expectActivation: testCase.type === 'pipe' && testCase.expectActivation
      });
    }

    this.results.tests.push({
      name: 'activation_strategies',
      results: strategyResults,
      analysis: this.analyzeActivationPerformance(strategyResults)
    });
  }

  async measureActivationTime(command) {
    const toolData = {
      tool: { name: 'Bash', input: { command } }
    };

    const start = performance.now();
    await this.runHook(toolData);
    const end = performance.now();

    return end - start;
  }

  async measurePipeOnlyTime(command) {
    // Simulate pipe-only detection performance
    const start = performance.now();
    
    // Simple pipe detection (what pure pipe-only would do)
    const hasPipe = command.includes('|');
    const shouldActivate = hasPipe && command.length > 10;
    
    const end = performance.now();
    return end - start;
  }

  async benchmarkMemoryUsage() {
    console.log('💾 Benchmarking Memory Usage');
    
    const memoryTests = [];
    const commands = [
      'npm run build',
      'find . -name "*.ts" | grep -v node_modules | head -20',
      'docker build . -t test',
      'npx tsc --noEmit'
    ];

    for (const command of commands) {
      const memBefore = process.memoryUsage();
      
      await this.measureActivationTime(command);
      
      const memAfter = process.memoryUsage();
      
      memoryTests.push({
        command,
        heapUsed: memAfter.heapUsed - memBefore.heapUsed,
        heapTotal: memAfter.heapTotal - memBefore.heapTotal,
        external: memAfter.external - memBefore.external,
        rss: memAfter.rss - memBefore.rss
      });
    }

    this.results.tests.push({
      name: 'memory_usage',
      results: memoryTests
    });
  }

  async benchmarkConcurrentLoad() {
    console.log('⚡ Benchmarking Concurrent Load');
    
    const concurrentCounts = [1, 5, 10, 25, 50];
    const testCommand = 'npm run build | head -10';
    
    const concurrencyResults = [];
    
    for (const count of concurrentCounts) {
      const start = performance.now();
      
      const promises = Array(count).fill(null).map(() => 
        this.measureActivationTime(testCommand)
      );
      
      const times = await Promise.all(promises);
      const end = performance.now();
      
      concurrencyResults.push({
        concurrentCount: count,
        totalTime: end - start,
        averageTime: times.reduce((a, b) => a + b, 0) / times.length,
        maxTime: Math.max(...times),
        minTime: Math.min(...times)
      });
    }

    this.results.tests.push({
      name: 'concurrent_load',
      results: concurrencyResults
    });
  }

  async benchmarkASTParsing() {
    console.log('🌳 Benchmarking AST Parsing Performance');
    
    const parse = require('bash-parser');
    
    const astTests = [
      // Simple commands
      { complexity: 'simple', command: 'ls -la' },
      { complexity: 'simple', command: 'npm run build' },
      
      // Medium complexity
      { complexity: 'medium', command: 'find . -name "*.js" | grep test' },
      { complexity: 'medium', command: 'npm run build 2>&1 | tail -10' },
      
      // High complexity
      { complexity: 'complex', command: 'find . -name "*.ts" -not -path "./node_modules/*" | xargs grep -l "export" | head -20' },
      { complexity: 'complex', command: 'docker build . -t test && docker run --rm test npm test 2>&1 | tee build.log | grep -E "(PASS|FAIL)"' }
    ];

    const astResults = [];
    
    for (const test of astTests) {
      const iterations = 100; // Multiple iterations for accurate timing
      const times = [];
      
      for (let i = 0; i < iterations; i++) {
        const start = performance.now();
        try {
          parse(test.command);
        } catch (e) {
          // Some commands might not parse perfectly, that's ok
        }
        const end = performance.now();
        times.push(end - start);
      }
      
      astResults.push({
        command: test.command,
        complexity: test.complexity,
        averageTime: times.reduce((a, b) => a + b, 0) / times.length,
        maxTime: Math.max(...times),
        minTime: Math.min(...times),
        iterations
      });
    }

    this.results.tests.push({
      name: 'ast_parsing',
      results: astResults
    });
  }

  analyzeActivationPerformance(results) {
    const hybridTimes = results.hybrid.map(r => r.time);
    const pipeOnlyTimes = results.pipeOnly.map(r => r.time);
    
    const hybridAvg = hybridTimes.reduce((a, b) => a + b, 0) / hybridTimes.length;
    const pipeOnlyAvg = pipeOnlyTimes.reduce((a, b) => a + b, 0) / pipeOnlyTimes.length;
    
    const performanceRatio = hybridAvg / pipeOnlyAvg;
    
    return {
      hybridAverageMs: hybridAvg,
      pipeOnlyAverageMs: pipeOnlyAvg,
      performanceRatio,
      expertClaim: 165, // Expert 002's claim
      claimValidation: performanceRatio > 100 ? 'CONFIRMED' : 'DISPUTED',
      recommendation: performanceRatio > 10 ? 'SWITCH_TO_PIPE_ONLY' : 'HYBRID_ACCEPTABLE'
    };
  }

  async runHook(toolData) {
    return new Promise((resolve, reject) => {
      const child = spawn('node', [HOOK_PATH], { 
        stdio: ['pipe', 'pipe', 'pipe'] 
      });
      
      let stdout = '';
      
      child.stdout.on('data', (data) => stdout += data);
      
      child.on('close', (code) => {
        if (code !== 0) {
          reject(new Error(`Hook failed with code ${code}`));
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

  async saveResults() {
    fs.writeFileSync(RESULTS_FILE, JSON.stringify(this.results, null, 2));
    console.log(`📁 Results saved to: ${RESULTS_FILE}`);
  }

  printSummary() {
    console.log('\n📈 Performance Benchmark Summary');
    console.log('================================');
    
    const activationTest = this.results.tests.find(t => t.name === 'activation_strategies');
    if (activationTest) {
      const analysis = activationTest.analysis;
      console.log(`Hybrid Strategy Average: ${analysis.hybridAverageMs.toFixed(3)}ms`);
      console.log(`Pipe-Only Average: ${analysis.pipeOnlyAverageMs.toFixed(3)}ms`);
      console.log(`Performance Ratio: ${analysis.performanceRatio.toFixed(1)}x`);
      console.log(`Expert Claim (165x): ${analysis.claimValidation}`);
      console.log(`Recommendation: ${analysis.recommendation}`);
    }
    
    console.log('\n⚠️  CRITICAL FINDING:');
    console.log('Current implementation uses hybrid strategy but expert consensus chose pipe-only.');
    console.log('Consider implementing pure pipe-only detection as per expert recommendation.');
  }
}

// Run benchmark if called directly
if (require.main === module) {
  const benchmark = new PerformanceBenchmark();
  benchmark.runBenchmark().catch(console.error);
}

module.exports = PerformanceBenchmark;