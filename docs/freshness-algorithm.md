# Freshness Scoring Algorithm

**Part of P3.T003: PostToolUse Hook Implementation**

## Overview

The freshness scorer is an intelligent scoring system that determines how "fresh" or relevant a captured command output remains over time. It provides scores from 0-100 (where 100 = perfectly fresh) along with confidence intervals and explainable reasoning.

## Core Algorithm

### Time Decay Function

The primary scoring mechanism uses exponential decay:

```
score = 100 * exp(-λ * hours_elapsed)
```

Where:
- `λ` (lambda) = decay rate parameter (default: 0.1)
- `hours_elapsed` = time since capture in hours

This function ensures:
- Fresh captures (< 1 hour) maintain high scores (>90)
- Moderate age captures (1-5 hours) degrade gracefully
- Old captures (>12 hours) approach zero

### Penalty System

The scorer applies penalties for various staleness indicators:

| Factor | Penalty | Trigger |
|--------|---------|---------|
| File modifications | -10 points each | Related files modified since capture |
| Command reruns | -20 points each | Same command executed again |
| Git changes | -15 points | New commits in repository |
| Package changes | -25 points | package.json or lockfile modified |
| Environment changes | -5 points | Environment variables changed |

### Final Score Calculation

```javascript
final_score = max(0, min(100, 
  time_decay_score + 
  sum(all_penalties)
))
```

## Confidence Intervals

Confidence decreases over time and with missing metadata:

```javascript
confidence = base_confidence - (hours_elapsed * uncertainty_factor) - metadata_penalties
```

Base factors:
- `base_confidence`: 0.95 (95%)
- `uncertainty_factor`: 0.1 per hour
- Missing hash: -0.1
- Missing size: -0.05
- No related files: -0.05

## Configuration Parameters

The algorithm is highly tunable through configuration:

```javascript
const DEFAULT_CONFIG = {
  // Time decay
  lambda: 0.1,              // Decay rate (higher = faster decay)
  maxAge: 24,               // Hours after which score approaches 0
  
  // Penalties
  fileChangePenalty: 10,    // Points lost per file modification
  commandRerunPenalty: 20,  // Points lost if command rerun
  gitChangePenalty: 15,     // Points lost for git changes
  packageChangePenalty: 25, // Points lost for package updates
  
  // Confidence
  baseConfidence: 0.95,     // Starting confidence level
  uncertaintyFactor: 0.1,   // Uncertainty increase per hour
  
  // Performance
  maxComputeTime: 10,       // Maximum computation time (ms)
  cacheEnabled: true        // Enable result caching
};
```

## Detection Mechanisms

### File Change Detection

1. **Output File**: Checks if the captured output file has been modified
2. **Working Directory**: Scans for recently modified files in the command's working directory
3. **Related Files**: Examines explicitly specified related files
4. **Efficient Scanning**: Limits file system operations for performance

### Command Rerun Detection

- Uses MD5 hashing to identify identical commands
- Compares against recent command history
- Accounts for multiple reruns with cumulative penalties

### System State Changes

1. **Git Repository Changes**:
   - Detects new commits since capture time
   - Compares current HEAD with historical state
   - Handles non-git directories gracefully

2. **Package Manager Changes**:
   - Monitors `package.json` modification time
   - Tracks `package-lock.json` changes
   - Detects dependency updates

3. **Environment Changes**:
   - Hashes relevant environment variables
   - Compares against stored environment state
   - Focuses on development-relevant variables (NODE_ENV, PATH, etc.)

## Performance Optimizations

### Caching System

- Results cached by metadata + current state hash
- Automatic cache invalidation
- Configurable cache enable/disable

### Efficient File Operations

- Limits directory scans to first 20 files
- Uses asynchronous I/O operations
- Graceful handling of permission errors

### Computation Limits

- Target: <10ms per score calculation
- Timeout protection for long operations
- Minimal system command execution

## Explainable Scoring

The scorer provides detailed reasoning for its decisions:

### Reason Categories

1. **Time-based**: "Capture is 2.3 hours old"
2. **File-based**: "3 file(s) modified since capture: file1.txt, file2.txt"
3. **Command-based**: "Same command run 2 time(s) since capture"
4. **System-based**: "Git repository has new commits since capture"
5. **Error-based**: "Unable to verify git state consistency"

### Factor Breakdown

Each result includes detailed factor analysis:

```javascript
{
  score: 67,
  confidence: 0.85,
  factors: {
    timeDecay: 82,
    fileChanges: -10,
    commandReruns: -20,
    gitChanges: -15
  },
  reasons: [
    "Capture is 1.2 hours old",
    "1 file(s) modified since capture: output.txt",
    "Same command run 1 time(s) since capture",
    "Git repository has new commits since capture"
  ]
}
```

## Usage Examples

### Basic Usage

```javascript
const { FreshnessScorer, CaptureMetadata } = require('./freshness-scorer');

const scorer = new FreshnessScorer();
const metadata = new CaptureMetadata({
  path: '/tmp/output.txt',
  command: 'npm test',
  timestamp: new Date('2023-01-01T10:00:00Z'),
  size: 1024,
  hash: 'abc123'
});

const result = await scorer.calculateScore(metadata);
console.log(`Score: ${result.score}, Confidence: ${result.confidence}`);
```

### With Current State

```javascript
const currentState = {
  recentCommands: [{
    command: 'npm test',
    timestamp: new Date('2023-01-01T10:30:00Z')
  }],
  environment: process.env
};

const result = await scorer.calculateScore(metadata, currentState);
```

### Custom Configuration

```javascript
const scorer = new FreshnessScorer({
  lambda: 0.2,              // Faster decay
  fileChangePenalty: 15,    // Higher file penalty
  cacheEnabled: false       // Disable caching
});
```

## Integration with PostToolUse Hook

The freshness scorer integrates with the PostToolUse hook system:

```javascript
// In PostToolUse handler
const scorer = new FreshnessScorer();
const metadata = extractCaptureMetadata(toolResponse);
const currentState = getCurrentSystemState();

const freshness = await scorer.calculateScore(metadata, currentState);

if (freshness.score < 50) {
  console.warn('Capture may be stale:', freshness.reasons.join(', '));
}

// Include freshness in context
const context = formatContextWithFreshness(metadata, freshness);
```

## Testing and Validation

### Accuracy Requirements

- **Target**: ≥90% accuracy in freshness classification
- **Test Scenarios**: Fresh, stale, and intermediate captures
- **Validation**: Comprehensive test suite with realistic scenarios

### Performance Requirements

- **Computation Time**: <10ms per score calculation
- **Memory Usage**: Minimal memory footprint
- **Error Handling**: Graceful degradation with invalid inputs

### Test Categories

1. **Unit Tests**: Individual algorithm components
2. **Integration Tests**: End-to-end scoring scenarios
3. **Performance Tests**: Speed and memory benchmarks
4. **Error Tests**: Invalid input handling
5. **Realistic Tests**: Real-world development scenarios

## Future Enhancements

### Machine Learning Integration

- Train models on user feedback about freshness accuracy
- Learn project-specific staleness patterns
- Adaptive parameter tuning

### Advanced Detection

- Semantic analysis of command outputs
- Dependency graph analysis
- Network-based staleness detection

### Performance Improvements

- Parallel factor calculation
- Incremental updates
- Smart caching strategies

## Troubleshooting

### Common Issues

1. **Slow Performance**: 
   - Check file system permissions
   - Reduce related files list
   - Enable caching

2. **Low Accuracy**:
   - Tune decay parameters for project
   - Add project-specific penalties
   - Increase related files tracking

3. **Cache Issues**:
   - Clear cache with `scorer.clearCache()`
   - Verify cache key generation
   - Check memory usage

### Debug Information

```javascript
// Get scoring statistics
const stats = scorer.getStats();
console.log('Cache size:', stats.cacheSize);
console.log('Configuration:', stats.config);

// Enable detailed logging (future enhancement)
const scorer = new FreshnessScorer({ debug: true });
```

## Conclusion

The freshness scoring algorithm provides a robust, performant, and explainable system for determining the relevance of captured command outputs. Its tunable parameters and comprehensive detection mechanisms make it suitable for diverse development environments while maintaining the <10ms performance requirement and ≥90% accuracy target.