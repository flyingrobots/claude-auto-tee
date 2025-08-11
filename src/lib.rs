//! Claude Auto-Tee Library
//!
//! High-performance bash command processor for automatic tee injection

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};

mod bash_parser;
mod hook_processor;
mod temp_manager;

use hook_processor::HookProcessor;

/// Claude Code hook data structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HookData {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tool: Option<Tool>,
    #[serde(flatten)]
    pub extra: serde_json::Map<String, serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Tool {
    pub name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub input: Option<ToolInput>,
    #[serde(flatten)]
    pub extra: serde_json::Map<String, serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolInput {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub command: Option<String>,
    #[serde(flatten)]
    pub extra: serde_json::Map<String, serde_json::Value>,
}

/// Process hook input and return modified JSON or original on error
pub fn process_hook_input(input: &str) -> Result<String> {
    let mut hook_data: HookData = serde_json::from_str(input)
        .context("Failed to parse JSON input")?;

    // Only process Bash tool calls
    if let Some(ref tool) = hook_data.tool {
        if tool.name == "Bash" {
            if let Some(ref tool_input) = tool.input {
                if let Some(ref command) = tool_input.command {
                    let processor = HookProcessor::new();
                    
                    if let Some(modified_command) = processor.process_command(command)? {
                        // Create new tool input with modified command
                        let mut new_tool_input = tool_input.clone();
                        new_tool_input.command = Some(modified_command);
                        
                        // Update the hook data
                        let mut new_tool = tool.clone();
                        new_tool.input = Some(new_tool_input);
                        hook_data.tool = Some(new_tool);
                    }
                }
            }
        }
    }

    let output = serde_json::to_string_pretty(&hook_data)
        .context("Failed to serialize modified JSON")?;
    
    Ok(output)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pass_through_non_bash_tools() {
        let input = r#"{"tool": {"name": "Read", "input": {"file": "test.txt"}}}"#;
        let result = process_hook_input(input).unwrap();
        
        // Should pass through unchanged
        let original: serde_json::Value = serde_json::from_str(input).unwrap();
        let processed: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(original, processed);
    }

    #[test]
    fn test_pass_through_no_tool() {
        let input = r#"{"other_data": "value"}"#;
        let result = process_hook_input(input).unwrap();
        
        let original: serde_json::Value = serde_json::from_str(input).unwrap();
        let processed: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(original, processed);
    }

    #[test]
    fn test_bash_command_processing() {
        let input = r#"{"tool": {"name": "Bash", "input": {"command": "npm run build"}}}"#;
        let result = process_hook_input(input).unwrap();
        
        let processed: HookData = serde_json::from_str(&result).unwrap();
        let command = processed.tool.unwrap().input.unwrap().command.unwrap();
        
        // Should be modified to include tee
        assert!(command.contains("tee"));
        assert!(command.contains("TMPFILE"));
    }

    #[test]
    fn test_malformed_json_fallback() {
        let input = r#"{"malformed": json}"#;
        let result = process_hook_input(input);
        
        // Should fail gracefully
        assert!(result.is_err());
    }
}