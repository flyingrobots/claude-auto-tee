#!/usr/bin/env node
/**
 * Claude Auto-Tee Hook
 * 
 * Automatically injects `tee` into bash commands to save full output to /tmp
 * while still allowing you to see truncated results (head/tail).
 * 
 * Solves the common pattern:
 * TMPFILE="/tmp/$(uuidgen).log"
 * command 2>&1 | tee "$TMPFILE" | head -100
 * 
 * Usage: Claude Code pre-tool hook that transforms commands automatically
 */

const parse = require('bash-parser');
const { v4: uuidv4 } = require('uuid');
const os = require('os');

// Read hook input from stdin
let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => input += chunk);
process.stdin.on('end', () => {
  try {
    const hookData = JSON.parse(input);
    const result = processHookData(hookData);
    console.log(JSON.stringify(result, null, 2));
  } catch (error) {
    // If anything fails, pass through unchanged
    console.error('Claude Auto-Tee Error:', error.message);
    console.log(input); // Pass through original
  }
});

function processHookData(hookData) {
  // Only process Bash tool calls
  if (hookData.tool?.name !== 'Bash') {
    return hookData;
  }

  const command = hookData.tool.input?.command;
  if (!command || typeof command !== 'string') {
    return hookData;
  }

  try {
    // Parse bash command into AST for robust analysis
    const ast = parse(command);
    
    // Determine if we should inject tee
    if (!shouldInjectTee(ast, command)) {
      return hookData;
    }

    // Inject tee intelligently
    const modifiedCommand = injectTee(command, ast);
    
    return {
      ...hookData,
      tool: {
        ...hookData.tool,
        input: {
          ...hookData.tool.input,
          command: modifiedCommand
        }
      }
    };
  } catch (parseError) {
    // If AST parsing fails, fall back gracefully
    return hookData;
  }
}

function shouldInjectTee(ast, command) {
  // Skip if already has tee
  if (command.includes('tee ')) {
    return false;
  }
  
  // Skip if has file redirections (> >> <)
  if (hasRedirections(ast)) {
    return false;
  }
  
  // Skip interactive/long-running processes
  if (isInteractiveCommand(command)) {
    return false;
  }
  
  // Skip very short commands (likely not worth teeing)
  if (command.length < 10) {
    return false;
  }
  
  // EXPERT CONSENSUS: Hybrid activation strategy
  
  // 1. HIGH PRIORITY: Commands with pipes (user is filtering → likely wants full output)
  if (hasPipeline(ast)) {
    // Only skip if it's a trivial command even with pipes
    const trivialPatterns = [/^(ls|pwd|echo|cat|head|tail|wc|sort)\s/];
    if (!trivialPatterns.some(pattern => pattern.test(command))) {
      return true; // Most piped commands should be teed
    }
  }
  
  // 2. MEDIUM PRIORITY: Pattern-matched expensive operations  
  const expensivePatterns = [
    // Build systems
    /npm run (build|test|lint|typecheck|check)/,
    /yarn (build|test|lint|typecheck|check)/,  
    /pnpm (build|test|lint|typecheck|check)/,
    
    // Script runners
    /tsx .+\.(ts|js)/,
    /node .+\.js/,
    /npx .+/,
    
    // Search/analysis tools
    /find /,
    /grep -r/,
    /rg /,
    /ag /,
    
    // Git operations  
    /git log/,
    /git diff.*--stat/,
    /git blame/,
    
    // Database/migrations
    /migrate/,
    /seed/,
    /prisma/,
    
    // Custom patterns
    /decree/,
    /compliance/,
    /audit/,
    /docker (build|run)/
  ];
  
  if (expensivePatterns.some(pattern => pattern.test(command))) {
    return true;
  }
  
  // 3. FALLBACK: Skip quick operations by default
  return false;
}

function hasRedirections(ast) {
  return walkAST(ast, (node) => node.type === 'redirect');
}

function isInteractiveCommand(command) {
  const interactivePatterns = [
    /npm run (dev|start|serve)/,
    /yarn (dev|start|serve)/,
    /pnpm (dev|start|serve)/,
    /watch/,
    /--watch/,
    /docker run.*-it/,
    /ssh /,
    /tail -f/
  ];
  
  return interactivePatterns.some(pattern => pattern.test(command));
}

function injectTee(command, ast) {
  // Cross-platform temp file path (expert recommendation)
  const tmpDir = os.tmpdir();
  const tmpFile = `${tmpDir}/claude-${uuidv4()}.log`;
  
  // Check if command already has a pipeline
  if (hasPipeline(ast)) {
    return injectTeeIntoPipeline(command, tmpFile);
  } else {
    return injectTeeSimple(command, tmpFile);
  }
}

function hasPipeline(ast) {
  return walkAST(ast, (node) => node.type === 'pipeline');
}

function injectTeeIntoPipeline(command, tmpFile) {
  // Find first pipe and inject tee before it
  const pipeIndex = command.indexOf(' | ');
  if (pipeIndex === -1) {
    return injectTeeSimple(command, tmpFile);
  }
  
  const beforePipe = command.substring(0, pipeIndex).trim();
  const afterPipe = command.substring(pipeIndex + 3).trim();
  
  // Remove existing 2>&1 if present to avoid duplication
  const cleanBeforePipe = beforePipe.replace(/ 2>&1$/, '');
  
  return `TMPFILE="${tmpFile}"
${cleanBeforePipe} 2>&1 | tee "$TMPFILE" | ${afterPipe}
echo ""
echo "📝 Full output saved to: $TMPFILE"`;
}

function injectTeeSimple(command, tmpFile) {
  // No pipeline, add tee with default head truncation
  const cleanCommand = command.replace(/ 2>&1$/, '');
  
  return `TMPFILE="${tmpFile}"
${cleanCommand} 2>&1 | tee "$TMPFILE" | head -100
echo ""  
echo "📝 Full output saved to: $TMPFILE"`;
}

// Utility: Walk AST and check if any node matches predicate
function walkAST(node, predicate) {
  if (!node || typeof node !== 'object') {
    return false;
  }
  
  if (predicate(node)) {
    return true;
  }
  
  // Recursively check all properties
  for (const key in node) {
    const value = node[key];
    if (Array.isArray(value)) {
      if (value.some(item => walkAST(item, predicate))) {
        return true;
      }
    } else if (typeof value === 'object') {
      if (walkAST(value, predicate)) {
        return true;
      }
    }
  }
  
  return false;
}