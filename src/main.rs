#!/usr/bin/env rust
//! Claude Auto-Tee Hook - Rust Implementation
//!
//! Automatically injects `tee` into bash commands to save full output to temp files
//! while still allowing truncated results (head/tail).
//!
//! Solves the common pattern:
//! ```bash
//! TMPFILE="/tmp/$(uuidgen).log"
//! command 2>&1 | tee "$TMPFILE" | head -100
//! ```
//!
//! Performance Requirements from Expert Debate:
//! - Sub-millisecond execution time (<0.1ms)
//! - Zero-allocation parsing for simple commands
//! - Memory-efficient concurrent operation (50-100MB total under load)
//! - C-level performance with memory safety

use anyhow::Result;
use claude_auto_tee::process_hook_input;
use std::io::{self, Read};

fn main() -> Result<()> {
    // Read hook input from stdin
    let mut input = String::new();
    io::stdin()
        .read_to_string(&mut input)?;

    // Process the hook data
    let result = process_hook_input(&input);
    
    match result {
        Ok(output) => {
            println!("{}", output);
            Ok(())
        }
        Err(e) => {
            // If anything fails, pass through unchanged (fail-safe behavior)
            eprintln!("Claude Auto-Tee Error: {}", e);
            print!("{}", input); // Pass through original
            Ok(())
        }
    }
}

