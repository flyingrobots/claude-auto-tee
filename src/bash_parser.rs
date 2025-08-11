//! Bash Command Parser
//!
//! High-performance, zero-allocation parser for bash commands to detect:
//! - Pipeline operations
//! - Redirections
//! - Interactive commands
//! - Expensive operations
//!
//! Performance Engineering Requirements:
//! - Zero allocations for simple command analysis
//! - Pattern matching using string slices
//! - Minimal regex usage (compiled once)

use std::sync::LazyLock;
use regex::Regex;

/// Command analysis result
#[derive(Debug, Clone, PartialEq)]
pub struct CommandAnalysis {
    pub has_pipeline: bool,
    pub has_redirections: bool,
    pub is_interactive: bool,
    pub is_expensive: bool,
    pub is_trivial: bool,
    pub already_has_tee: bool,
}

/// Bash command parser optimized for performance
pub struct BashParser;

// Compile regexes once using LazyLock (zero-cost after first use)
static EXPENSIVE_PATTERNS: LazyLock<Vec<Regex>> = LazyLock::new(|| {
    vec![
        // Build systems
        Regex::new(r"npm run (build|test|lint|typecheck|check)").unwrap(),
        Regex::new(r"yarn (build|test|lint|typecheck|check)").unwrap(),
        Regex::new(r"pnpm (build|test|lint|typecheck|check)").unwrap(),
        
        // Script runners
        Regex::new(r"tsx .+\.(ts|js)").unwrap(),
        Regex::new(r"node .+\.js").unwrap(),
        Regex::new(r"npx .+").unwrap(),
        
        // Search/analysis tools
        Regex::new(r"find ").unwrap(),
        Regex::new(r"grep -r").unwrap(),
        Regex::new(r"rg ").unwrap(),
        Regex::new(r"ag ").unwrap(),
        
        // Git operations
        Regex::new(r"git log").unwrap(),
        Regex::new(r"git diff.*--stat").unwrap(),
        Regex::new(r"git blame").unwrap(),
        
        // Database/migrations
        Regex::new(r"migrate").unwrap(),
        Regex::new(r"seed").unwrap(),
        Regex::new(r"prisma").unwrap(),
        
        // Custom patterns
        Regex::new(r"decree").unwrap(),
        Regex::new(r"compliance").unwrap(),
        Regex::new(r"audit").unwrap(),
        Regex::new(r"docker (build|run)").unwrap(),
    ]
});

static INTERACTIVE_PATTERNS: LazyLock<Vec<Regex>> = LazyLock::new(|| {
    vec![
        Regex::new(r"npm run (dev|start|serve)").unwrap(),
        Regex::new(r"yarn (dev|start|serve)").unwrap(),
        Regex::new(r"pnpm (dev|start|serve)").unwrap(),
        Regex::new(r"watch").unwrap(),
        Regex::new(r"--watch").unwrap(),
        Regex::new(r"docker run.*-it").unwrap(),
        Regex::new(r"ssh ").unwrap(),
        Regex::new(r"tail -f").unwrap(),
    ]
});

static TRIVIAL_PATTERNS: LazyLock<Vec<Regex>> = LazyLock::new(|| {
    vec![
        Regex::new(r"^(ls|pwd|echo|cat|head|tail|wc|sort)(\s|$)").unwrap(),
    ]
});

impl BashParser {
    /// Create new parser instance
    pub fn new() -> Self {
        Self
    }

    /// Analyze command with zero-allocation string operations where possible
    pub fn analyze(&self, command: &str) -> CommandAnalysis {
        // Early bailout for very short commands (zero allocation)
        if command.len() < 3 {
            return CommandAnalysis {
                has_pipeline: false,
                has_redirections: false,
                is_interactive: false,
                is_expensive: false,
                is_trivial: true,
                already_has_tee: false,
            };
        }

        // Zero-allocation checks using string operations
        let has_pipeline = self.has_pipeline_fast(command);
        let has_redirections = self.has_redirections_fast(command);
        let already_has_tee = self.has_tee_fast(command);
        
        // Pattern matching (requires regex, but patterns compiled once)
        let is_interactive = self.is_interactive(command);
        let is_expensive = self.is_expensive(command);
        let is_trivial = self.is_trivial(command);

        CommandAnalysis {
            has_pipeline,
            has_redirections,
            is_interactive,
            is_expensive,
            is_trivial,
            already_has_tee,
        }
    }

    /// Fast pipeline detection using string operations (zero allocation)
    fn has_pipeline_fast(&self, command: &str) -> bool {
        // Look for " | " pattern - most common pipe usage
        command.contains(" | ")
    }

    /// Fast redirection detection (zero allocation)
    fn has_redirections_fast(&self, command: &str) -> bool {
        // Look for common redirection patterns
        command.contains(" > ") || 
        command.contains(" >> ") || 
        command.contains(" < ") ||
        command.contains(" 2>&1 >") ||
        command.contains(" &>")
    }

    /// Fast tee detection (zero allocation)
    fn has_tee_fast(&self, command: &str) -> bool {
        command.contains("tee ")
    }

    /// Check if command is interactive (requires regex matching)
    fn is_interactive(&self, command: &str) -> bool {
        INTERACTIVE_PATTERNS.iter().any(|pattern| pattern.is_match(command))
    }

    /// Check if command is expensive (requires regex matching)
    fn is_expensive(&self, command: &str) -> bool {
        EXPENSIVE_PATTERNS.iter().any(|pattern| pattern.is_match(command))
    }

    /// Check if command is trivial (requires regex matching)
    fn is_trivial(&self, command: &str) -> bool {
        TRIVIAL_PATTERNS.iter().any(|pattern| pattern.is_match(command))
    }

    /// Extract the position of the first pipe for injection
    pub fn find_first_pipe_position(&self, command: &str) -> Option<usize> {
        command.find(" | ")
    }
}

impl Default for BashParser {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pipeline_detection() {
        let parser = BashParser::new();
        
        assert!(parser.has_pipeline_fast("ls -la | grep test"));
        assert!(parser.has_pipeline_fast("npm run build | head -100"));
        assert!(!parser.has_pipeline_fast("npm run build"));
        assert!(!parser.has_pipeline_fast("ls -la"));
    }

    #[test]
    fn test_redirection_detection() {
        let parser = BashParser::new();
        
        assert!(parser.has_redirections_fast("echo test > file.txt"));
        assert!(parser.has_redirections_fast("cmd >> log.txt"));
        assert!(parser.has_redirections_fast("cmd < input.txt"));
        assert!(parser.has_redirections_fast("cmd 2>&1 > output.log"));
        assert!(!parser.has_redirections_fast("simple command"));
    }

    #[test]
    fn test_tee_detection() {
        let parser = BashParser::new();
        
        assert!(parser.has_tee_fast("cmd | tee file.log"));
        assert!(parser.has_tee_fast("cmd 2>&1 | tee /tmp/output.log | head -100"));
        assert!(!parser.has_tee_fast("cmd | head -100"));
    }

    #[test]
    fn test_expensive_patterns() {
        let parser = BashParser::new();
        
        assert!(parser.is_expensive("npm run build"));
        assert!(parser.is_expensive("npm run test"));
        assert!(parser.is_expensive("tsx script.ts"));
        assert!(parser.is_expensive("git log --oneline"));
        assert!(parser.is_expensive("docker build -t test ."));
        assert!(!parser.is_expensive("echo hello"));
        assert!(!parser.is_expensive("ls -la"));
    }

    #[test]
    fn test_interactive_patterns() {
        let parser = BashParser::new();
        
        assert!(parser.is_interactive("npm run dev"));
        assert!(parser.is_interactive("yarn start"));
        assert!(parser.is_interactive("docker run -it ubuntu bash"));
        assert!(parser.is_interactive("tail -f log.txt"));
        assert!(!parser.is_interactive("npm run build"));
        assert!(!parser.is_interactive("ls -la"));
    }

    #[test]
    fn test_trivial_patterns() {
        let parser = BashParser::new();
        
        assert!(parser.is_trivial("ls -la"));
        assert!(parser.is_trivial("pwd"));
        assert!(parser.is_trivial("echo hello"));
        assert!(parser.is_trivial("cat file.txt"));
        assert!(!parser.is_trivial("npm run build"));
        assert!(!parser.is_trivial("complex-command --with-args"));
    }

    #[test]
    fn test_complete_analysis() {
        let parser = BashParser::new();
        
        let analysis = parser.analyze("npm run build | head -100");
        assert!(analysis.has_pipeline);
        assert!(analysis.is_expensive);
        assert!(!analysis.is_interactive);
        assert!(!analysis.is_trivial);
        assert!(!analysis.already_has_tee);
        assert!(!analysis.has_redirections);
    }

    #[test]
    fn test_short_command_optimization() {
        let parser = BashParser::new();
        
        let analysis = parser.analyze("ls");
        assert!(analysis.is_trivial);
        assert!(!analysis.has_pipeline);
        assert!(!analysis.has_redirections);
    }

    #[test]
    fn test_pipe_position_finding() {
        let parser = BashParser::new();
        
        assert_eq!(parser.find_first_pipe_position("cmd | grep test"), Some(3));
        assert_eq!(parser.find_first_pipe_position("long command | head -100"), Some(12));
        assert_eq!(parser.find_first_pipe_position("no pipes here"), None);
    }
}