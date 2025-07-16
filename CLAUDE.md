# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Script Philosophy

Core principles:
- Do one thing well - Each script has a single clear purpose
- Fail fast and loud - `set -euo pipefail`, meaningful error messages
- Self-documenting - `--help` is the source of truth, not code comments
- Least surprise - Consistent patterns, predictable behavior
- Safety first - Default to dry-run, require confirmation for destructive actions
- Composable - Play well with pipes, automation, and other tools
- Transparent - Show what you're doing, especially when destructive
- Minimal aesthetics - Clean output, no unnecessary emojis or visual noise

Common patterns:
- Version headers: `# Version: x.y.z`
- Comprehensive help with examples
- Environment variable configuration
- Consistent option naming (`-q/--quiet`, `-n/--dry-run`, `-h/--help`)
- Error handling with meaningful messages


## Development workflow:
- Tools are self-contained shell scripts with version headers
- Use `set -euo pipefail` for error handling
- Maintain Bash 3.2+ compatibility (macOS support)
- Follow the existing help/option patterns

## Bash Compatibility

Target: Bash 3.2+ (macOS default)

Common compatibility issues encountered:
- `mapfile`/`readarray` (Bash 4.0+) → Use temp file with `while read` loop
- `declare -A` associative arrays (Bash 4.0+) → Use regular arrays with helper functions
- Array expansion with `set -u`: `"${array[@]}"` → `"${array[@]+"${array[@]}"}"`

## Quality Assurance

Run ShellCheck on all scripts before committing:
```bash
shellcheck src/bin/*.sh install.sh
```

## Architecture

Collection of utility scripts and tools for notifications and automation.

Key Components:
- `src/bin/barkme.sh` - Bark notification service client (iOS push notifications)
- `src/bin/purgeb.sh` - Build artifact purging tool (node_modules, Rust targets, etc.)
- `install.sh` - Interactive installer with version management


## Tool Architecture

### barkme.sh specifics:
- Bark iOS notification service client
- Supports both GET and POST requests
- Environment variables: `BARK_SERVER`, `BARK_KEY`, `BARK_GROUP`, etc.
- Retry logic and quiet mode for automation

### purgeb.sh specifics:
- Build artifact cleanup tool
- Supports multiple artifact types (node_modules, Rust targets)
- Human-readable size formatting
- Dry-run mode for safety
- Glob pattern exclusions
