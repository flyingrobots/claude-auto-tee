//! Hook Processor
//!
//! Main processing logic that decides whether to inject tee and how to modify commands.
//! Implements the hybrid activation strategy from the expert debate.
//!
//! Architecture Requirements from Expert Debate:
//! - Clean separation of concerns (parsing, execution, output handling)
//! - Testable code structure 
//! - Zero-cost abstractions enabling maintainable code

use anyhow::Result;
use crate::bash_parser::{BashParser, CommandAnalysis};
use crate::temp_manager::TempManager;

/// Processes bash commands and determines if/how to inject tee
pub struct HookProcessor {
    parser: BashParser,
}

impl HookProcessor {
    /// Create a new hook processor
    pub fn new() -> Self {
        Self {
            parser: BashParser::new(),
        }
    }

    /// Process a command and return modified version if tee should be injected
    /// Returns None if command should not be modified
    pub fn process_command(&self, command: &str) -> Result<Option<String>> {
        let analysis = self.parser.analyze(command);
        
        if !self.should_inject_tee(&analysis, command) {
            return Ok(None);
        }

        let temp_path = TempManager::create_temp_file_path()?;
        let modified_command = self.inject_tee(command, &analysis, &temp_path)?;
        
        Ok(Some(modified_command))
    }

    /// Determine if tee should be injected based on analysis
    /// Implements the hybrid activation strategy from expert consensus
    fn should_inject_tee(&self, analysis: &CommandAnalysis, command: &str) -> bool {
        // Skip if already has tee
        if analysis.already_has_tee {
            return false;
        }
        
        // Skip if has file redirections (> >> <)
        if analysis.has_redirections {
            return false;
        }
        
        // Skip interactive/long-running processes
        if analysis.is_interactive {
            return false;
        }
        
        // Skip very short commands (likely not worth teeing)
        if command.len() < 10 {
            return false;
        }
        
        // EXPERT CONSENSUS: Hybrid activation strategy
        
        // 1. HIGH PRIORITY: Commands with pipes (user is filtering → likely wants full output)
        if analysis.has_pipeline {
            // Only skip if it's a trivial command even with pipes
            if !analysis.is_trivial {
                return true; // Most piped commands should be teed
            }
        }
        
        // 2. MEDIUM PRIORITY: Pattern-matched expensive operations
        if analysis.is_expensive {
            return true;
        }
        
        // 3. FALLBACK: Skip quick operations by default
        false
    }

    /// Inject tee into the command appropriately
    fn inject_tee(&self, command: &str, analysis: &CommandAnalysis, temp_path: &std::path::Path) -> Result<String> {
        let temp_assignment = TempManager::get_shell_assignment(temp_path);
        let temp_var = "$TMPFILE";
        
        if analysis.has_pipeline {
            self.inject_tee_into_pipeline(command, &temp_assignment, temp_var)
        } else {
            self.inject_tee_simple(command, &temp_assignment, temp_var)
        }
    }

    /// Inject tee into a command that already has a pipeline
    fn inject_tee_into_pipeline(&self, command: &str, temp_assignment: &str, temp_var: &str) -> Result<String> {
        // Find first pipe and inject tee before it
        if let Some(pipe_pos) = self.parser.find_first_pipe_position(command) {
            let before_pipe = command[..pipe_pos].trim();
            let after_pipe = command[pipe_pos + 3..].trim(); // Skip " | "
            
            // Remove existing 2>&1 if present to avoid duplication
            let clean_before_pipe = before_pipe.strip_suffix(" 2>&1").unwrap_or(before_pipe);
            
            Ok(format!(
                "{}\n{} 2>&1 | tee {} | {}\necho \"\"\necho \"📝 Full output saved to: {}\"",
                temp_assignment,
                clean_before_pipe,
                temp_var,
                after_pipe,
                temp_var
            ))
        } else {
            // Fallback to simple injection if pipe parsing fails
            self.inject_tee_simple(command, temp_assignment, temp_var)
        }
    }

    /// Inject tee into a simple command (no existing pipeline)
    fn inject_tee_simple(&self, command: &str, temp_assignment: &str, temp_var: &str) -> Result<String> {
        // Remove existing 2>&1 if present to avoid duplication
        let clean_command = command.strip_suffix(" 2>&1").unwrap_or(command);
        
        Ok(format!(
            "{}\n{} 2>&1 | tee {} | head -100\necho \"\"\necho \"📝 Full output saved to: {}\"",
            temp_assignment,
            clean_command,
            temp_var,
            temp_var
        ))
    }
}

impl Default for HookProcessor {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_should_inject_expensive_command() {
        let processor = HookProcessor::new();
        let result = processor.process_command("npm run build").unwrap();
        
        assert!(result.is_some());
        let modified = result.unwrap();
        assert!(modified.contains("tee"));
        assert!(modified.contains("TMPFILE"));
        assert!(modified.contains("head -100")); // Simple command gets head truncation
    }

    #[test]
    fn test_should_inject_piped_command() {
        let processor = HookProcessor::new();
        let result = processor.process_command("npm run test | grep error").unwrap();
        
        assert!(result.is_some());
        let modified = result.unwrap();
        assert!(modified.contains("tee"));
        assert!(modified.contains("TMPFILE"));
        assert!(modified.contains("grep error")); // Pipeline preserved
        assert!(!modified.contains("head -100")); // No head for piped commands
    }

    #[test]
    fn test_skip_trivial_command() {
        let processor = HookProcessor::new();
        let result = processor.process_command("ls -la").unwrap();
        
        assert!(result.is_none()); // Should not be modified
    }

    #[test]
    fn test_skip_interactive_command() {
        let processor = HookProcessor::new();
        let result = processor.process_command("npm run dev").unwrap();
        
        assert!(result.is_none()); // Interactive commands should be skipped
    }

    #[test]
    fn test_skip_already_has_tee() {
        let processor = HookProcessor::new();
        let result = processor.process_command("npm run build | tee output.log").unwrap();
        
        assert!(result.is_none()); // Already has tee, should be skipped
    }

    #[test]
    fn test_skip_with_redirections() {
        let processor = HookProcessor::new();
        let result = processor.process_command("npm run build > output.log").unwrap();
        
        assert!(result.is_none()); // Has redirection, should be skipped
    }

    #[test]
    fn test_skip_short_command() {
        let processor = HookProcessor::new();
        let result = processor.process_command("pwd").unwrap();
        
        assert!(result.is_none()); // Very short command should be skipped
    }

    #[test]
    fn test_complex_pipeline_injection() {
        let processor = HookProcessor::new();
        let result = processor.process_command("find . -name '*.rs' | grep -v target | wc -l").unwrap();
        
        assert!(result.is_some());
        let modified = result.unwrap();
        
        // Should inject tee before first pipe
        assert!(modified.contains("find . -name '*.rs' 2>&1 | tee"));
        assert!(modified.contains("| grep -v target | wc -l"));
        assert!(modified.contains("📝 Full output saved to"));
    }

    #[test]
    fn test_removes_existing_stderr_redirect() {
        let processor = HookProcessor::new();
        let result = processor.process_command("npm run build 2>&1").unwrap();
        
        assert!(result.is_some());
        let modified = result.unwrap();
        
        // Should not have duplicate 2>&1
        let stderr_redirects = modified.matches("2>&1").count();
        assert_eq!(stderr_redirects, 1); // Only one 2>&1 should be present
    }

    #[test]
    fn test_preserves_complex_piped_command() {
        let processor = HookProcessor::new();
        let result = processor.process_command("docker build . 2>&1 | grep -E '(Step|Error)'").unwrap();
        
        assert!(result.is_some());
        let modified = result.unwrap();
        
        // Should inject tee but preserve the grep
        assert!(modified.contains("docker build . 2>&1 | tee"));
        assert!(modified.contains("| grep -E '(Step|Error)'"));
        assert!(!modified.contains("head -100")); // No head for piped commands
    }

    #[test]
    fn test_custom_expensive_patterns() {
        let processor = HookProcessor::new();
        
        // Test decree pattern (custom to this project)
        let result = processor.process_command("./scripts/decree/check-compliance.sh").unwrap();
        assert!(result.is_some());
        
        // Test git operations
        let result = processor.process_command("git log --oneline --graph").unwrap();
        assert!(result.is_some());
        
        // Test typescript compilation
        let result = processor.process_command("tsx scripts/build.ts").unwrap();
        assert!(result.is_some());
    }

    #[test]
    fn test_temp_file_creation() {
        let processor = HookProcessor::new();
        let result = processor.process_command("npm run build").unwrap();
        
        assert!(result.is_some());
        let modified = result.unwrap();
        
        // Should contain TMPFILE assignment
        assert!(modified.contains("TMPFILE="));
        // Should contain claude prefix in path
        assert!(modified.contains("claude-"));
        // Should contain .log extension
        assert!(modified.contains(".log"));
    }
}