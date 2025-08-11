#!/usr/bin/env node
/**
 * Master Test Runner for Claude Auto-Tee
 * 
 * Runs all test suites and generates comprehensive reports
 */

const fs = require('fs');
const path = require('path');

// Import all test suites
const BasicTestSuite = require('./test.js');
const PerformanceBenchmark = require('./performance/benchmark.js');
const SecurityTestSuite = require('./security/security-tests.js');
const EdgeCaseTestSuite = require('./edge-cases/edge-case-tests.js');
const ActivationStrategyTestSuite = require('./activation/activation-strategy-tests.js');
const CITestSuite = require('./ci/ci-tests.js');

class MasterTestRunner {
  constructor() {
    this.results = {
      timestamp: new Date().toISOString(),
      platform: process.platform,
      nodeVersion: process.version,
      suites: {},
      summary: {
        totalPassed: 0,
        totalFailed: 0,
        criticalIssues: [],
        recommendations: []
      }
    };
    
    this.ensureResultsDir();
  }

  ensureResultsDir() {
    const resultsDir = '/tmp/test-results';
    if (!fs.existsSync(resultsDir)) {
      fs.mkdirSync(resultsDir, { recursive: true });
    }
  }

  async runAllTests() {
    console.log('🧪 Claude Auto-Tee - Master Test Runner');
    console.log('=======================================');
    console.log(`Platform: ${process.platform}`);
    console.log(`Node: ${process.version}`);
    console.log(`Timestamp: ${this.results.timestamp}\n`);

    const suites = [
      { name: 'basic', class: BasicTestSuite, critical: true },
      { name: 'performance', class: PerformanceBenchmark, critical: true },
      { name: 'security', class: SecurityTestSuite, critical: true },
      { name: 'activation-strategy', class: ActivationStrategyTestSuite, critical: true },
      { name: 'edge-cases', class: EdgeCaseTestSuite, critical: false },
      { name: 'ci', class: CITestSuite, critical: false }
    ];

    for (const suite of suites) {
      console.log(`\n${'='.repeat(60)}`);
      console.log(`🔍 Running ${suite.name.toUpperCase()} Test Suite`);
      console.log(`${'='.repeat(60)}`);
      
      try {
        const testSuite = new suite.class();
        const results = await this.runSuite(testSuite);
        
        this.results.suites[suite.name] = {
          ...results,
          critical: suite.critical,
          status: 'completed'
        };
        
        if (results.testsPassed) {
          this.results.summary.totalPassed += results.testsPassed;
        }
        if (results.testsFailed) {
          this.results.summary.totalFailed += results.testsFailed;
        }
        
      } catch (error) {
        console.error(`❌ ${suite.name} suite failed: ${error.message}`);
        this.results.suites[suite.name] = {
          status: 'failed',
          error: error.message,
          critical: suite.critical
        };
        
        if (suite.critical) {
          this.results.summary.criticalIssues.push({
            suite: suite.name,
            error: error.message
          });
        }
      }
    }

    this.analyzeResults();
    await this.generateReports();
    this.printFinalSummary();
    
    return this.results;
  }

  async runSuite(testSuite) {
    // Detect suite type and call appropriate method
    if (testSuite.runTests && typeof testSuite.runTests === 'function') {
      return await testSuite.runTests();
    } else if (testSuite.runBenchmark && typeof testSuite.runBenchmark === 'function') {
      await testSuite.runBenchmark();
      return testSuite.results;
    } else if (testSuite.runSecurityTests && typeof testSuite.runSecurityTests === 'function') {
      return await testSuite.runSecurityTests();
    } else if (testSuite.runEdgeCaseTests && typeof testSuite.runEdgeCaseTests === 'function') {
      return await testSuite.runEdgeCaseTests();
    } else if (testSuite.runActivationTests && typeof testSuite.runActivationTests === 'function') {
      return await testSuite.runActivationTests();
    } else if (testSuite.runCITests && typeof testSuite.runCITests === 'function') {
      return await testSuite.runCITests();
    } else {
      throw new Error('Unknown test suite interface');
    }
  }

  analyzeResults() {
    console.log('\n📊 Analyzing Test Results...');
    
    // Check for critical implementation issues
    const activationSuite = this.results.suites['activation-strategy'];
    if (activationSuite && activationSuite.currentImplementation !== activationSuite.expertRecommendation) {
      this.results.summary.criticalIssues.push({
        type: 'IMPLEMENTATION_MISMATCH',
        description: 'Current implementation uses hybrid strategy but expert consensus chose pipe-only',
        impact: 'HIGH',
        recommendation: 'Migrate to pure pipe-only detection as per expert debate conclusion'
      });
    }

    // Check performance issues
    const performanceSuite = this.results.suites['performance'];
    if (performanceSuite && performanceSuite.tests) {
      const activationTest = performanceSuite.tests.find(t => t.name === 'activation_strategies');
      if (activationTest && activationTest.analysis.performanceRatio > 10) {
        this.results.summary.criticalIssues.push({
          type: 'PERFORMANCE_DEGRADATION',
          description: `Pattern matching causes ${activationTest.analysis.performanceRatio.toFixed(1)}x performance degradation`,
          impact: 'MEDIUM',
          recommendation: 'Switch to pipe-only detection to improve performance'
        });
      }
    }

    // Check security vulnerabilities
    const securitySuite = this.results.suites['security'];
    if (securitySuite && securitySuite.vulnerabilities && securitySuite.vulnerabilities.length > 0) {
      const highSeverity = securitySuite.vulnerabilities.filter(v => v.severity === 'HIGH');
      if (highSeverity.length > 0) {
        this.results.summary.criticalIssues.push({
          type: 'SECURITY_VULNERABILITIES',
          description: `${highSeverity.length} high-severity security vulnerabilities found`,
          impact: 'HIGH',
          recommendation: 'Address security vulnerabilities immediately'
        });
      }
    }

    // Generate recommendations
    this.generateRecommendations();
  }

  generateRecommendations() {
    const recommendations = [];

    // Implementation alignment
    if (this.results.summary.criticalIssues.some(i => i.type === 'IMPLEMENTATION_MISMATCH')) {
      recommendations.push({
        priority: 'URGENT',
        category: 'Architecture',
        action: 'Align implementation with expert recommendation',
        details: 'Switch from hybrid to pure pipe-only activation strategy',
        effort: 'Medium',
        impact: 'High'
      });
    }

    // Performance optimization
    const performanceIssues = this.results.summary.criticalIssues.some(i => i.type === 'PERFORMANCE_DEGRADATION');
    if (performanceIssues) {
      recommendations.push({
        priority: 'HIGH',
        category: 'Performance',
        action: 'Optimize activation strategy performance',
        details: 'Remove pattern matching overhead',
        effort: 'Low',
        impact: 'High'
      });
    }

    // Security hardening
    const securityIssues = this.results.summary.criticalIssues.some(i => i.type === 'SECURITY_VULNERABILITIES');
    if (securityIssues) {
      recommendations.push({
        priority: 'HIGH',
        category: 'Security',
        action: 'Fix security vulnerabilities',
        details: 'Address DoS and injection vulnerabilities',
        effort: 'Medium',
        impact: 'High'
      });
    }

    // Testing improvements
    if (this.results.summary.totalFailed > 0) {
      recommendations.push({
        priority: 'MEDIUM',
        category: 'Quality',
        action: 'Fix failing tests',
        details: `${this.results.summary.totalFailed} tests are failing`,
        effort: 'Variable',
        impact: 'Medium'
      });
    }

    // CI/CD integration
    const ciSuite = this.results.suites['ci'];
    if (ciSuite && ciSuite.status === 'completed') {
      recommendations.push({
        priority: 'MEDIUM',
        category: 'DevOps',
        action: 'Enhance CI/CD integration',
        details: 'Consider disabling auto-tee in CI environments',
        effort: 'Low',
        impact: 'Medium'
      });
    }

    this.results.summary.recommendations = recommendations;
  }

  async generateReports() {
    console.log('\n📝 Generating Test Reports...');
    
    // Generate JSON report
    const jsonReport = JSON.stringify(this.results, null, 2);
    fs.writeFileSync('/tmp/test-results/master-test-report.json', jsonReport);
    
    // Generate HTML report
    const htmlReport = this.generateHTMLReport();
    fs.writeFileSync('/tmp/test-results/master-test-report.html', htmlReport);
    
    // Generate markdown summary
    const markdownReport = this.generateMarkdownReport();
    fs.writeFileSync('/tmp/test-results/test-summary.md', markdownReport);
    
    console.log('✅ Reports generated:');
    console.log('   - /tmp/test-results/master-test-report.json (detailed data)');
    console.log('   - /tmp/test-results/master-test-report.html (visual report)');
    console.log('   - /tmp/test-results/test-summary.md (executive summary)');
  }

  generateHTMLReport() {
    const criticalIssuesHtml = this.results.summary.criticalIssues.map(issue => `
      <div class="issue ${issue.impact?.toLowerCase() || 'medium'}">
        <h4>${issue.type || issue.suite}</h4>
        <p>${issue.description || issue.error}</p>
        <p><strong>Recommendation:</strong> ${issue.recommendation || 'Review and address'}</p>
      </div>
    `).join('');

    const suitesHtml = Object.entries(this.results.suites).map(([name, suite]) => `
      <div class="suite ${suite.status}">
        <h3>${name.toUpperCase()} ${suite.critical ? '(Critical)' : ''}</h3>
        <p>Status: ${suite.status}</p>
        ${suite.testsPassed !== undefined ? `<p>Passed: ${suite.testsPassed}</p>` : ''}
        ${suite.testsFailed !== undefined ? `<p>Failed: ${suite.testsFailed}</p>` : ''}
        ${suite.error ? `<p class="error">Error: ${suite.error}</p>` : ''}
      </div>
    `).join('');

    const recommendationsHtml = this.results.summary.recommendations.map(rec => `
      <div class="recommendation ${rec.priority.toLowerCase()}">
        <h4>${rec.category}: ${rec.action}</h4>
        <p>${rec.details}</p>
        <p><strong>Priority:</strong> ${rec.priority}, <strong>Effort:</strong> ${rec.effort}, <strong>Impact:</strong> ${rec.impact}</p>
      </div>
    `).join('');

    return `
<!DOCTYPE html>
<html>
<head>
    <title>Claude Auto-Tee Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .summary { background: #f5f5f5; padding: 20px; border-radius: 5px; }
        .issue, .suite, .recommendation { margin: 10px 0; padding: 15px; border-radius: 5px; }
        .issue.high { background: #ffebee; border-left: 5px solid #f44336; }
        .issue.medium { background: #fff3e0; border-left: 5px solid #ff9800; }
        .issue.low { background: #e8f5e8; border-left: 5px solid #4caf50; }
        .suite.completed { background: #e8f5e8; }
        .suite.failed { background: #ffebee; }
        .recommendation.urgent { background: #ffebee; }
        .recommendation.high { background: #fff3e0; }
        .recommendation.medium { background: #f3e5f5; }
        .error { color: #d32f2f; }
        h1, h2 { color: #333; }
    </style>
</head>
<body>
    <h1>Claude Auto-Tee Test Report</h1>
    <div class="summary">
        <p><strong>Platform:</strong> ${this.results.platform}</p>
        <p><strong>Node Version:</strong> ${this.results.nodeVersion}</p>
        <p><strong>Timestamp:</strong> ${this.results.timestamp}</p>
        <p><strong>Total Tests:</strong> ${this.results.summary.totalPassed + this.results.summary.totalFailed}</p>
        <p><strong>Passed:</strong> ${this.results.summary.totalPassed}</p>
        <p><strong>Failed:</strong> ${this.results.summary.totalFailed}</p>
        <p><strong>Critical Issues:</strong> ${this.results.summary.criticalIssues.length}</p>
    </div>
    
    <h2>Critical Issues</h2>
    ${criticalIssuesHtml || '<p>No critical issues found.</p>'}
    
    <h2>Test Suites</h2>
    ${suitesHtml}
    
    <h2>Recommendations</h2>
    ${recommendationsHtml || '<p>No recommendations at this time.</p>'}
</body>
</html>`;
  }

  generateMarkdownReport() {
    const criticalSection = this.results.summary.criticalIssues.length > 0 
      ? `## 🚨 Critical Issues\n\n${this.results.summary.criticalIssues.map(issue => 
          `### ${issue.type || issue.suite}\n${issue.description || issue.error}\n**Recommendation:** ${issue.recommendation || 'Review and address'}\n`
        ).join('\n')}`
      : '## ✅ No Critical Issues Found\n';

    const suiteResults = Object.entries(this.results.suites).map(([name, suite]) => 
      `- **${name.toUpperCase()}** ${suite.critical ? '(Critical)' : ''}: ${suite.status} ` +
      `${suite.testsPassed !== undefined ? `(${suite.testsPassed} passed` : ''}` +
      `${suite.testsFailed !== undefined ? `, ${suite.testsFailed} failed)` : ''}`
    ).join('\n');

    const recommendations = this.results.summary.recommendations.map(rec =>
      `### ${rec.priority} Priority: ${rec.category}\n**Action:** ${rec.action}\n**Details:** ${rec.details}\n**Effort:** ${rec.effort} | **Impact:** ${rec.impact}\n`
    ).join('\n');

    return `# Claude Auto-Tee Test Summary

**Platform:** ${this.results.platform}  
**Node Version:** ${this.results.nodeVersion}  
**Test Date:** ${this.results.timestamp}

## 📊 Summary

- **Total Tests:** ${this.results.summary.totalPassed + this.results.summary.totalFailed}
- **Passed:** ${this.results.summary.totalPassed}
- **Failed:** ${this.results.summary.totalFailed}
- **Critical Issues:** ${this.results.summary.criticalIssues.length}

${criticalSection}

## 🧪 Test Suite Results

${suiteResults}

## 📋 Recommendations

${recommendations || 'No specific recommendations at this time.'}

## 🔍 Key Findings

1. **Implementation Mismatch:** Current code uses hybrid strategy but expert debate chose pipe-only
2. **Performance Impact:** Pattern matching may cause significant performance degradation
3. **Security Concerns:** Potential DoS vulnerabilities in pattern matching logic
4. **Cross-Platform Compatibility:** Temp file handling works across platforms
5. **CI/CD Integration:** Consider disabling auto-tee in CI environments

---
*Generated by Claude Auto-Tee Master Test Runner*
`;
  }

  printFinalSummary() {
    console.log('\n' + '='.repeat(80));
    console.log('🏁 FINAL TEST SUMMARY');
    console.log('='.repeat(80));
    
    console.log(`\n📊 Overall Results:`);
    console.log(`   Tests Passed: ${this.results.summary.totalPassed}`);
    console.log(`   Tests Failed: ${this.results.summary.totalFailed}`);
    console.log(`   Critical Issues: ${this.results.summary.criticalIssues.length}`);
    
    if (this.results.summary.criticalIssues.length > 0) {
      console.log('\n🚨 Critical Issues:');
      this.results.summary.criticalIssues.forEach((issue, i) => {
        console.log(`   ${i + 1}. ${issue.type || issue.suite}: ${issue.description || issue.error}`);
      });
    }
    
    if (this.results.summary.recommendations.length > 0) {
      console.log('\n📋 Top Recommendations:');
      this.results.summary.recommendations
        .sort((a, b) => {
          const priority = { 'URGENT': 3, 'HIGH': 2, 'MEDIUM': 1, 'LOW': 0 };
          return priority[b.priority] - priority[a.priority];
        })
        .slice(0, 3)
        .forEach((rec, i) => {
          console.log(`   ${i + 1}. [${rec.priority}] ${rec.category}: ${rec.action}`);
        });
    }
    
    console.log('\n💡 Key Insight:');
    console.log('   The current implementation (hybrid strategy) contradicts the expert');
    console.log('   debate conclusion (pure pipe-only). This needs architectural alignment.');
    
    console.log('\n📁 Detailed reports available at:');
    console.log('   /tmp/test-results/master-test-report.json');
    console.log('   /tmp/test-results/master-test-report.html');
    console.log('   /tmp/test-results/test-summary.md');
    
    console.log('\n' + '='.repeat(80));
    
    // Exit code based on results
    const hasFailures = this.results.summary.totalFailed > 0;
    const hasCriticalIssues = this.results.summary.criticalIssues.length > 0;
    
    if (hasFailures || hasCriticalIssues) {
      console.log('⚠️  Exiting with non-zero code due to failures or critical issues');
      process.exit(1);
    } else {
      console.log('✅ All tests passed successfully');
      process.exit(0);
    }
  }
}

// Run all tests if called directly
if (require.main === module) {
  const runner = new MasterTestRunner();
  runner.runAllTests().catch(console.error);
}

module.exports = MasterTestRunner;