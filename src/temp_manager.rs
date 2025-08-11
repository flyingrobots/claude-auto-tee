//! Temporary File Manager
//!
//! Cross-platform temporary file handling with proper cleanup and security.
//! 
//! Security Requirements from Expert Debate:
//! - Secure temporary file creation with proper permissions
//! - Cross-platform compatibility (Linux, macOS, Windows)
//! - Minimal attack surface

use anyhow::{Context, Result};
use std::env;
use std::path::{Path, PathBuf};
use uuid::Uuid;

/// Manages temporary file creation and cleanup
pub struct TempManager;

impl TempManager {
    /// Create a new temporary file path for storing command output
    pub fn create_temp_file_path() -> Result<PathBuf> {
        let temp_dir = Self::get_temp_dir()?;
        let filename = format!("claude-{}.log", Uuid::new_v4());
        Ok(temp_dir.join(filename))
    }

    /// Get the appropriate temporary directory for the current platform
    fn get_temp_dir() -> Result<PathBuf> {
        // Use std::env::temp_dir() which handles cross-platform logic:
        // - Unix: $TMPDIR, /tmp, or /var/tmp  
        // - Windows: %TEMP%, %TMP%, or current directory
        // - macOS: Properly handles sandbox restrictions
        let temp_dir = env::temp_dir();
        
        // Verify the directory exists and is writable
        if !temp_dir.exists() {
            return Err(anyhow::anyhow!(
                "Temporary directory does not exist: {}", 
                temp_dir.display()
            ));
        }

        // Test write access by attempting to create a test file
        let test_path = temp_dir.join(format!(".claude-test-{}", Uuid::new_v4()));
        match std::fs::write(&test_path, "") {
            Ok(_) => {
                // Clean up test file
                let _ = std::fs::remove_file(&test_path);
                Ok(temp_dir)
            }
            Err(e) => Err(anyhow::anyhow!(
                "Cannot write to temporary directory {}: {}", 
                temp_dir.display(),
                e
            )),
        }
    }

    /// Format a temporary file path for shell usage
    pub fn format_for_shell(path: &Path) -> String {
        // Convert path to string and handle spaces/special characters
        let path_str = path.to_string_lossy();
        
        // On Unix-like systems, we can use the path directly in quotes
        // On Windows, we may need different escaping, but quotes generally work
        format!("\"{}\"", path_str)
    }

    /// Get platform-appropriate shell variable assignment
    pub fn get_shell_assignment(path: &Path) -> String {
        let formatted_path = Self::format_for_shell(path);
        format!("TMPFILE={}", formatted_path)
    }

    /// Check if a path looks like one of our temporary files
    pub fn is_claude_temp_file(path: &Path) -> bool {
        path.file_name()
            .and_then(|name| name.to_str())
            .map(|name| name.starts_with("claude-") && name.ends_with(".log"))
            .unwrap_or(false)
    }

    /// Attempt to clean up old temporary files (best effort)
    pub fn cleanup_old_temp_files() -> Result<usize> {
        let temp_dir = Self::get_temp_dir()?;
        let mut cleaned = 0;

        // Read directory entries
        let entries = std::fs::read_dir(&temp_dir)
            .with_context(|| format!("Cannot read temp directory: {}", temp_dir.display()))?;

        for entry in entries.flatten() {
            let path = entry.path();
            
            // Only clean up our own temp files
            if Self::is_claude_temp_file(&path) {
                // Check file age - only clean up files older than 24 hours
                if let Ok(metadata) = entry.metadata() {
                    if let Ok(created) = metadata.created().or_else(|_| metadata.modified()) {
                        let age = created.elapsed().unwrap_or(std::time::Duration::ZERO);
                        if age > std::time::Duration::from_secs(24 * 60 * 60) {
                            if std::fs::remove_file(&path).is_ok() {
                                cleaned += 1;
                            }
                        }
                    }
                }
            }
        }

        Ok(cleaned)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn test_temp_dir_access() {
        let temp_dir = TempManager::get_temp_dir().unwrap();
        assert!(temp_dir.exists());
        assert!(temp_dir.is_dir());
    }

    #[test]
    fn test_temp_file_creation() {
        let temp_path = TempManager::create_temp_file_path().unwrap();
        
        // Should be in temp directory
        let temp_dir = std::env::temp_dir();
        assert!(temp_path.starts_with(&temp_dir));
        
        // Should have claude prefix and .log extension
        let filename = temp_path.file_name().unwrap().to_str().unwrap();
        assert!(filename.starts_with("claude-"));
        assert!(filename.ends_with(".log"));
        
        // Should contain UUID (36 chars + prefix + extension)
        assert!(filename.len() > 40);
    }

    #[test]
    fn test_shell_formatting() {
        let path = PathBuf::from("/tmp/claude-test.log");
        let formatted = TempManager::format_for_shell(&path);
        assert_eq!(formatted, "\"/tmp/claude-test.log\"");
        
        // Test with spaces
        let path_with_spaces = PathBuf::from("/tmp/dir with spaces/claude-test.log");
        let formatted_spaces = TempManager::format_for_shell(&path_with_spaces);
        assert_eq!(formatted_spaces, "\"/tmp/dir with spaces/claude-test.log\"");
    }

    #[test]
    fn test_shell_assignment() {
        let path = PathBuf::from("/tmp/claude-test.log");
        let assignment = TempManager::get_shell_assignment(&path);
        assert_eq!(assignment, "TMPFILE=\"/tmp/claude-test.log\"");
    }

    #[test]
    fn test_claude_temp_file_detection() {
        assert!(TempManager::is_claude_temp_file(Path::new("claude-123.log")));
        assert!(TempManager::is_claude_temp_file(Path::new("/tmp/claude-456.log")));
        assert!(!TempManager::is_claude_temp_file(Path::new("other-file.log")));
        assert!(!TempManager::is_claude_temp_file(Path::new("claude-test.txt")));
        assert!(!TempManager::is_claude_temp_file(Path::new("claude")));
    }

    #[test]
    fn test_temp_file_uniqueness() {
        // Create multiple temp file paths and ensure they're unique
        let path1 = TempManager::create_temp_file_path().unwrap();
        let path2 = TempManager::create_temp_file_path().unwrap();
        let path3 = TempManager::create_temp_file_path().unwrap();
        
        assert_ne!(path1, path2);
        assert_ne!(path2, path3);
        assert_ne!(path1, path3);
    }

    #[test] 
    fn test_actual_file_write() {
        let temp_path = TempManager::create_temp_file_path().unwrap();
        
        // Should be able to write to the path
        fs::write(&temp_path, "test content").unwrap();
        
        // Should be able to read it back
        let content = fs::read_to_string(&temp_path).unwrap();
        assert_eq!(content, "test content");
        
        // Clean up
        fs::remove_file(&temp_path).unwrap();
    }
}