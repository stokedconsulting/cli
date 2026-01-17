# Product Requirements Document (Sequential)

## 0. Source Context
**Derived From:** Feature Brief
**Feature Name:** Build Script Manager CLI
**PRD Owner:** TBD
**Last Updated:** 2026-01-16

### Feature Brief Summary
Build Script Manager CLI is a command-line tool built with Ink (React for CLIs) that streamlines the creation, editing, and deployment of shell scripts. It provides an intuitive workflow for developers to create new scripts with proper shebangs, make them executable, install them system-wide to `/usr/local/bin`, and sync them to a GitHub repository for version control and distribution via NPM. The goal is to eliminate the friction of managing personal CLI tools across machines by reducing "I need a script" to "installed and version-controlled" in under 60 seconds.

---

## 1. Objectives & Constraints

### Objectives
- Reduce the time from "I need a script" to "It's installed and version-controlled" to under 60 seconds
- Provide a single command interface for the entire script lifecycle (create, edit, install, sync)
- Enable developers to maintain a personal CLI toolkit that can be installed from NPM on any machine
- Eliminate manual chmod, sudo cp, and git operations for script management
- Support automatic shebang detection and insertion for common script types (bash, zsh, python, node)

### Constraints
- **Platform:** macOS and Linux only; Windows support is out of scope for v1
- **Editor:** VIM is the only supported editor in v1 (configurable editor support planned for v1.1)
- **Technical:** Must work within terminal constraints; Ink provides React-like components but is limited to terminal capabilities
- **Technical:** Requires sudo for `/usr/local/bin` installation, which may prompt for password
- **Security:** Must handle sudo operations carefully to avoid security vulnerabilities
- **Runtime:** Requires Node.js 18+ for running the CLI
- **Timeline:** Target MVP within 4-6 weeks of development
- **Resources:** Single developer project initially

---

## 2. Execution Phases

> Phases below are ordered and sequential.
> A phase cannot begin until all acceptance criteria of the previous phase are met.

---

## Phase 1: Foundation
**Purpose:** Establish the project structure, build system, and basic CLI skeleton. This phase must exist before others because all subsequent features depend on a working CLI entry point with proper argument parsing and configuration management.

### 1.1 Project Initialization
Initialize the Node.js project with TypeScript, Ink framework, and essential development tooling.

**Implementation Details**
- Systems affected: Local filesystem, npm registry
- Inputs: None (greenfield project)
- Outputs: `package.json`, `tsconfig.json`, project directory structure
- Core logic:
  - Initialize npm project with TypeScript support
  - Configure Ink as primary framework
  - Set up ESLint, Prettier for code quality
  - Configure build scripts for development and production
  - Create `src/` directory structure with entry point
- Failure modes:
  - npm initialization fails (check npm/node versions)
  - TypeScript compilation errors (verify tsconfig settings)

**Acceptance Criteria**
- AC-1.1.a: When `npm install` runs → all dependencies install without errors
- AC-1.1.b: When `npm run build` runs → TypeScript compiles to JavaScript in `dist/` directory
- AC-1.1.c: When `npm run dev` runs → development mode starts with hot reloading
- AC-1.1.d: Project structure contains `src/index.tsx`, `src/cli.ts`, `src/components/` directories

**Acceptance Tests**
- Test-1.1.a: Build script executes successfully and produces valid JavaScript output
- Test-1.1.b: ESLint runs without errors on source files
- Test-1.1.c: TypeScript strict mode is enabled and compiles without type errors

---

### 1.2 CLI Entry Point and Argument Parsing
Create the main CLI entry point that accepts file/directory paths as arguments and provides version/help information.

**Implementation Details**
- Systems affected: CLI interface, process arguments
- Inputs: Command-line arguments (file path, flags like `--version`, `--help`, `--dry-run`, `--verbose`)
- Outputs: Parsed arguments object, route to appropriate handler
- Core logic:
  - Use Commander or Yargs for argument parsing
  - Accept positional argument for file/directory path
  - Support flags: `--version`, `--help`, `--dry-run`, `--verbose`
  - Validate that provided path is a valid filesystem path format
  - Determine if path is file or directory
- Failure modes:
  - No path provided (show usage help)
  - Invalid path format (display error with valid examples)
  - Unknown flags (show available options)

**Acceptance Criteria**
- AC-1.2.a: When user runs `script-mgr --version` → displays current version from package.json
- AC-1.2.b: When user runs `script-mgr --help` → displays usage information with all available options
- AC-1.2.c: When user runs `script-mgr /path/to/script` → path is captured and validated
- AC-1.2.d: When user runs `script-mgr` without arguments → displays helpful error message with usage example
- AC-1.2.e: When user runs `script-mgr --dry-run /path/to/script` → dry-run flag is captured and passed to handlers

**Acceptance Tests**
- Test-1.2.a: Unit test validates `--version` flag returns version string matching package.json
- Test-1.2.b: Unit test validates `--help` flag returns help text containing all documented options
- Test-1.2.c: Unit test validates file path argument is correctly parsed and stored
- Test-1.2.d: Unit test validates missing arguments trigger appropriate error
- Test-1.2.e: Integration test validates CLI entry point is executable via npm

---

### 1.3 Configuration Management
Implement configuration file support for storing user preferences and GitHub repository settings.

**Implementation Details**
- Systems affected: Local filesystem (`~/.config/script-mgr/` or `~/.script-mgr.json`)
- Inputs: Configuration file path, user input for initial setup
- Outputs: Parsed configuration object
- Core logic:
  - Define configuration schema (GitHub repo, default shebang, scripts directory)
  - Check for existing configuration file on startup
  - Provide `script-mgr config` subcommand for viewing/editing config
  - Support environment variable overrides for CI/CD scenarios
  - Use XDG Base Directory specification for config location
- Failure modes:
  - Config file not found (prompt for initial setup or use defaults)
  - Config file malformed (display parsing error with location)
  - Missing required config values (prompt user to complete setup)

**Acceptance Criteria**
- AC-1.3.a: When config file exists at `~/.config/script-mgr/config.json` → it is loaded on startup
- AC-1.3.b: When config file does not exist → CLI prompts for initial configuration or uses sensible defaults
- AC-1.3.c: When `script-mgr config` runs → displays current configuration values
- AC-1.3.d: When `script-mgr config --set github.repo=user/repo` runs → configuration is updated and persisted
- AC-1.3.e: When `SCRIPT_MGR_GITHUB_REPO` environment variable is set → it overrides config file value

**Acceptance Tests**
- Test-1.3.a: Unit test validates configuration schema parsing
- Test-1.3.b: Unit test validates environment variable override takes precedence
- Test-1.3.c: Integration test validates config file is created on first run
- Test-1.3.d: Integration test validates config subcommand reads and writes values correctly

---

### 1.4 Basic Ink UI Shell
Create the foundational Ink components for rendering CLI output with proper styling and layout.

**Implementation Details**
- Systems affected: Terminal output, Ink rendering engine
- Inputs: Application state, user interactions
- Outputs: Rendered terminal UI
- Core logic:
  - Create main App component that wraps all UI
  - Implement status bar component for operation feedback
  - Create styled text components (success, error, warning, info)
  - Implement spinner component for long-running operations
  - Set up context provider for global state management
- Failure modes:
  - Terminal does not support colors (fall back to plain text)
  - Terminal width too narrow (truncate or wrap text appropriately)

**Acceptance Criteria**
- AC-1.4.a: When CLI starts → Ink app renders without errors
- AC-1.4.b: When operation is in progress → spinner animates with descriptive text
- AC-1.4.c: When error occurs → red-styled error message displays
- AC-1.4.d: When operation succeeds → green-styled success message displays
- AC-1.4.e: When terminal lacks color support → plain text output is readable

**Acceptance Tests**
- Test-1.4.a: Unit test validates Ink App component renders without throwing
- Test-1.4.b: Snapshot test validates spinner component output format
- Test-1.4.c: Unit test validates styled text components apply correct ANSI codes
- Test-1.4.d: Integration test validates full UI renders in mock terminal environment

---

## Phase 2: Editor Integration
**Purpose:** Implement the core workflow of opening VIM for script editing with automatic shebang insertion. This phase cannot start until Phase 1 completes because it depends on the CLI entry point, configuration management, and UI components established in Phase 1.

### 2.1 File Existence Detection
Determine whether the specified file path exists and route to appropriate workflow (create vs edit).

**Implementation Details**
- Systems affected: Local filesystem
- Inputs: File path from CLI arguments (from Phase 1.2)
- Outputs: Boolean existence flag, file metadata if exists
- Core logic:
  - Check if path exists using `fs.stat` or `fs.access`
  - If path is directory, prompt for script name within directory
  - Determine file extension if present for shebang detection
  - Store file metadata (size, permissions, modification time) for later use
- Failure modes:
  - Permission denied on path (display error with permission fix suggestion)
  - Path is symbolic link (resolve and continue)
  - Parent directory does not exist (offer to create)

**Acceptance Criteria**
- AC-2.1.a: When file exists → returns true with file metadata object
- AC-2.1.b: When file does not exist → returns false with null metadata
- AC-2.1.c: When directory is provided → prompts user for script name interactively
- AC-2.1.d: When parent directory missing → offers to create parent directories
- AC-2.1.e: When permission denied → displays actionable error message

**Acceptance Tests**
- Test-2.1.a: Unit test validates existing file detection returns correct metadata
- Test-2.1.b: Unit test validates non-existent file detection returns false
- Test-2.1.c: Integration test validates directory handling prompts for filename
- Test-2.1.d: Unit test validates permission error is caught and formatted

---

### 2.2 Shebang Detection and Generation
Automatically detect appropriate shebang based on file extension or user preference.

**Implementation Details**
- Systems affected: In-memory string generation, configuration system
- Inputs: File path, file extension, user configuration
- Outputs: Shebang string (e.g., `#!/bin/bash`, `#!/usr/bin/env python3`)
- Core logic:
  - Map common extensions to shebangs: `.sh`→bash, `.py`→python3, `.js`→node, `.zsh`→zsh
  - Support `#!/usr/bin/env` format for portability
  - Allow configuration override for default shebang
  - For extensionless files, use configured default (bash by default)
  - Parse existing files to detect if shebang already present
- Failure modes:
  - Unknown extension (prompt user or use default)
  - Conflicting shebang in existing file (warn user, do not modify)

**Acceptance Criteria**
- AC-2.2.a: When file extension is `.sh` → generates `#!/bin/bash` or `#!/usr/bin/env bash`
- AC-2.2.b: When file extension is `.py` → generates `#!/usr/bin/env python3`
- AC-2.2.c: When file extension is `.js` → generates `#!/usr/bin/env node`
- AC-2.2.d: When file has no extension → uses configured default shebang
- AC-2.2.e: When existing file has shebang → does not duplicate or modify existing shebang

**Acceptance Tests**
- Test-2.2.a: Unit test validates shebang mapping for all supported extensions
- Test-2.2.b: Unit test validates env-style shebang format
- Test-2.2.c: Unit test validates existing shebang detection
- Test-2.2.d: Unit test validates default shebang from configuration

---

### 2.3 VIM Spawning and Process Management
Spawn VIM editor as child process with proper terminal handling and wait for exit.

**Implementation Details**
- Systems affected: Process management, terminal TTY
- Inputs: File path, initial content (shebang for new files)
- Outputs: Exit code from VIM, modified file on disk
- Core logic:
  - Use `execa` or native `child_process.spawn` with `stdio: 'inherit'`
  - For new files, write shebang to temp file then open in VIM
  - Ensure proper TTY passthrough for VIM to render correctly
  - Capture VIM exit code to detect save vs abort
  - Handle SIGINT/SIGTERM gracefully
- Failure modes:
  - VIM not installed (check PATH, display installation instructions)
  - VIM crashes (capture exit code, display error)
  - User aborts without saving (detect and skip subsequent steps)

**Acceptance Criteria**
- AC-2.3.a: When VIM opens → terminal is passed through correctly, VIM is interactive
- AC-2.3.b: When new file → VIM opens with shebang pre-populated on first line
- AC-2.3.c: When user saves and exits VIM (`:wq`) → exit code 0 captured, proceed to next step
- AC-2.3.d: When user exits without saving (`:q!`) → exit code captured, operation cancelled
- AC-2.3.e: When VIM is not installed → helpful error message with installation instructions

**Acceptance Tests**
- Test-2.3.a: Integration test validates VIM spawns and accepts keyboard input (mock terminal)
- Test-2.3.b: Unit test validates temp file is created with shebang for new files
- Test-2.3.c: Unit test validates exit code handling for save vs abort scenarios
- Test-2.3.d: Unit test validates VIM-not-found error handling

---

### 2.4 Post-Edit File Validation
Validate the edited file after VIM exits to ensure it's ready for installation.

**Implementation Details**
- Systems affected: Local filesystem
- Inputs: File path after VIM edit
- Outputs: Validation result (valid, warnings, errors)
- Core logic:
  - Verify file exists and has content
  - Check that shebang is present on first line
  - Validate shebang interpreter exists on system
  - Detect common issues (Windows line endings, invalid syntax for known types)
  - Display warnings for potential issues without blocking
- Failure modes:
  - File is empty (warn user, prompt to continue or abort)
  - Shebang missing (offer to add, or warn and continue)
  - Shebang interpreter not found (warn but allow continue)

**Acceptance Criteria**
- AC-2.4.a: When file has valid shebang and content → validation passes with no warnings
- AC-2.4.b: When file is empty → warning displayed, user prompted to continue
- AC-2.4.c: When shebang is missing → warning displayed with option to auto-add
- AC-2.4.d: When shebang references missing interpreter → warning displayed
- AC-2.4.e: When file has Windows line endings → warning displayed with auto-fix option

**Acceptance Tests**
- Test-2.4.a: Unit test validates successful file validation with shebang
- Test-2.4.b: Unit test validates empty file warning trigger
- Test-2.4.c: Unit test validates missing shebang detection
- Test-2.4.d: Integration test validates interpreter existence check

---

## Phase 3: System Integration
**Purpose:** Make scripts executable and install them to system PATH. This phase cannot start until Phase 2 completes because it operates on the edited/created files from the editor workflow.

### 3.1 Chmod Execution Permission
Make the script file executable after editing.

**Implementation Details**
- Systems affected: Local filesystem, file permissions
- Inputs: File path
- Outputs: Updated file permissions
- Core logic:
  - Use `fs.chmod` with mode `0o755` (rwxr-xr-x)
  - Verify permission change succeeded
  - Display current permissions before and after (in verbose mode)
  - Skip if already executable
- Failure modes:
  - Permission denied (user doesn't own file)
  - File system is read-only
  - File has been deleted during operation

**Acceptance Criteria**
- AC-3.1.a: When chmod runs → file has executable bit set (user, group, other)
- AC-3.1.b: When `--verbose` flag set → displays permission change details
- AC-3.1.c: When file already executable → skips with informational message
- AC-3.1.d: When permission denied → displays error with ownership information

**Acceptance Tests**
- Test-3.1.a: Unit test validates chmod sets correct permissions (0755)
- Test-3.1.b: Integration test validates file is executable after operation
- Test-3.1.c: Unit test validates skip behavior for already-executable files
- Test-3.1.d: Unit test validates error handling for permission denied

---

### 3.2 Script Name Extraction
Extract the script name from the file path for use in installation.

**Implementation Details**
- Systems affected: String processing
- Inputs: Full file path
- Outputs: Script name (basename without extension for script types)
- Core logic:
  - Extract basename from path
  - Determine if extension should be stripped (e.g., `.sh` stripped, `.py` kept)
  - Handle edge cases (hidden files, multiple extensions)
  - Validate name is valid for installation (no spaces, special chars)
- Failure modes:
  - Invalid characters in name (offer sanitization)
  - Name conflicts with system commands (warn user)

**Acceptance Criteria**
- AC-3.2.a: When path is `/path/to/myscript.sh` → script name is `myscript`
- AC-3.2.b: When path is `/path/to/tool.py` → script name is `tool.py` (Python convention)
- AC-3.2.c: When name contains spaces → sanitized name offered with confirmation
- AC-3.2.d: When name conflicts with common command (e.g., `ls`, `cat`) → warning displayed

**Acceptance Tests**
- Test-3.2.a: Unit test validates shell script extension stripping
- Test-3.2.b: Unit test validates Python script extension preservation
- Test-3.2.c: Unit test validates name sanitization for special characters
- Test-3.2.d: Unit test validates system command conflict detection

---

### 3.3 Sudo Copy to /usr/local/bin
Copy the script to `/usr/local/bin` using sudo for system-wide availability.

**Implementation Details**
- Systems affected: `/usr/local/bin/`, sudo subsystem
- Inputs: Source file path, script name from 3.2
- Outputs: Installed script at `/usr/local/bin/{script-name}`
- Core logic:
  - Check if `/usr/local/bin` exists and is writable (or requires sudo)
  - Use `sudo cp` command via `execa` with user TTY for password prompt
  - Preserve executable permissions in copy
  - If script already exists at destination, prompt for overwrite
  - Support `--dry-run` to show what would happen without executing
- Failure modes:
  - User cancels sudo password prompt
  - `/usr/local/bin` does not exist (rare, but handle)
  - Existing file is different (show diff, confirm overwrite)
  - Disk full

**Acceptance Criteria**
- AC-3.3.a: When sudo succeeds → script is copied to `/usr/local/bin/{name}`
- AC-3.3.b: When user cancels sudo → operation aborted with message, no partial state
- AC-3.3.c: When script already exists → user prompted with overwrite confirmation
- AC-3.3.d: When `--dry-run` → displays intended operation without executing
- AC-3.3.e: When copy complete → script is executable from any terminal

**Acceptance Tests**
- Test-3.3.a: Integration test validates script appears in `/usr/local/bin/` (may require elevated privileges to run)
- Test-3.3.b: Unit test validates sudo command is properly constructed
- Test-3.3.c: Unit test validates overwrite prompt trigger on existing file
- Test-3.3.d: Unit test validates dry-run outputs expected operation

---

### 3.4 Installation Verification
Verify the script was installed correctly and is accessible from PATH.

**Implementation Details**
- Systems affected: Process execution, PATH lookup
- Inputs: Script name
- Outputs: Verification result (installed, accessible, version if applicable)
- Core logic:
  - Use `which` or `command -v` to verify script is in PATH
  - Optionally run script with `--version` if it supports it
  - Display installation success message with full path
  - Show next steps (GitHub sync, usage)
- Failure modes:
  - Script not found in PATH (check PATH includes `/usr/local/bin`)
  - Script errors on execution (display error, suggest fixes)

**Acceptance Criteria**
- AC-3.4.a: When installation succeeds → `which {script-name}` returns `/usr/local/bin/{script-name}`
- AC-3.4.b: When script not in PATH → helpful message about PATH configuration
- AC-3.4.c: When verification complete → success message with next steps displayed
- AC-3.4.d: When `--verbose` → shows full verification details

**Acceptance Tests**
- Test-3.4.a: Integration test validates `which` returns correct path
- Test-3.4.b: Unit test validates PATH troubleshooting message content
- Test-3.4.c: Integration test validates end-to-end: create, edit, install, verify

---

## Phase 4: GitHub Sync
**Purpose:** Synchronize scripts to a configured GitHub repository for version control and distribution. This phase cannot start until Phase 3 completes because it operates on verified, installed scripts and requires the configuration system from Phase 1.

### 4.1 GitHub Authentication
Handle GitHub authentication for API operations.

**Implementation Details**
- Systems affected: GitHub API, credential storage
- Inputs: User configuration, environment variables, git credentials
- Outputs: Authenticated Octokit client
- Core logic:
  - Check for `GITHUB_TOKEN` environment variable first
  - Fall back to GitHub CLI (`gh`) token if available
  - Support personal access token in config file
  - Validate token has required scopes (repo access)
  - Cache authenticated client for session
- Failure modes:
  - No authentication method available (guide user to set up)
  - Token expired or invalid (clear and re-prompt)
  - Insufficient token scopes (display required scopes)

**Acceptance Criteria**
- AC-4.1.a: When `GITHUB_TOKEN` env var exists → used for authentication
- AC-4.1.b: When no token exists → displays setup instructions with links
- AC-4.1.c: When token is invalid → clear error message with re-authentication steps
- AC-4.1.d: When token lacks scopes → displays required scopes and how to update

**Acceptance Tests**
- Test-4.1.a: Unit test validates environment variable token extraction
- Test-4.1.b: Unit test validates gh CLI token fallback
- Test-4.1.c: Integration test validates Octokit client authenticates successfully
- Test-4.1.d: Unit test validates scope validation error handling

---

### 4.2 Repository Configuration
Configure and validate the target GitHub repository for script storage.

**Implementation Details**
- Systems affected: GitHub API, configuration system
- Inputs: Repository name from config (e.g., `username/my-scripts`)
- Outputs: Validated repository reference
- Core logic:
  - Parse repository string into owner/repo components
  - Verify repository exists and user has push access
  - If repository doesn't exist, offer to create it
  - Store repository metadata for subsequent operations
  - Support repository initialization with README
- Failure modes:
  - Repository not found and user declines creation
  - User lacks push access to repository
  - Rate limit exceeded

**Acceptance Criteria**
- AC-4.2.a: When repository exists and accessible → validation passes
- AC-4.2.b: When repository doesn't exist → user prompted to create
- AC-4.2.c: When user confirms creation → repository created with README
- AC-4.2.d: When user lacks access → error with permission explanation
- AC-4.2.e: When rate limited → retry with backoff or helpful message

**Acceptance Tests**
- Test-4.2.a: Unit test validates repository string parsing
- Test-4.2.b: Integration test validates repository existence check via API
- Test-4.2.c: Integration test validates repository creation flow
- Test-4.2.d: Unit test validates access denied error handling

---

### 4.3 File Upload/Update
Upload or update the script file in the GitHub repository.

**Implementation Details**
- Systems affected: GitHub API (Contents API), local filesystem
- Inputs: Script file content, target path in repository
- Outputs: Commit reference, file URL
- Core logic:
  - Read file content and encode as base64
  - Check if file exists in repository (for update vs create)
  - If exists, get current SHA for update operation
  - Create commit with descriptive message
  - Support custom commit message via CLI flag
  - Support `--dry-run` to preview without pushing
- Failure modes:
  - Conflict (file changed on remote) - fetch latest and retry or warn
  - Large file (>100MB GitHub limit)
  - Network failure during upload

**Acceptance Criteria**
- AC-4.3.a: When file is new → created in repository with commit
- AC-4.3.b: When file exists → updated with new commit showing diff
- AC-4.3.c: When `--message "custom"` → uses custom commit message
- AC-4.3.d: When `--dry-run` → displays what would be committed without pushing
- AC-4.3.e: When upload succeeds → displays file URL and commit SHA

**Acceptance Tests**
- Test-4.3.a: Integration test validates file creation via GitHub API
- Test-4.3.b: Integration test validates file update with SHA handling
- Test-4.3.c: Unit test validates commit message formatting
- Test-4.3.d: Unit test validates dry-run output format

---

### 4.4 Sync Status Reporting
Report the synchronization status with clear visual feedback.

**Implementation Details**
- Systems affected: Ink UI components
- Inputs: Sync operation results
- Outputs: Formatted status display
- Core logic:
  - Show spinner during upload operation
  - Display success with repository URL and commit link
  - Show file diff summary (lines added/removed)
  - List any warnings or non-blocking issues
  - Provide copy-able commands for cloning repo
- Failure modes:
  - Partial failure (some files synced, others failed) - report individually

**Acceptance Criteria**
- AC-4.4.a: When sync in progress → spinner with descriptive text displayed
- AC-4.4.b: When sync succeeds → green success message with links
- AC-4.4.c: When sync fails → red error message with actionable fix
- AC-4.4.d: When complete → displays summary of changes and repository URL

**Acceptance Tests**
- Test-4.4.a: Unit test validates success message format contains URL
- Test-4.4.b: Unit test validates error message format is actionable
- Test-4.4.c: Snapshot test validates status component rendering

---

## Phase 5: Polish & Distribution
**Purpose:** Finalize the user experience and prepare for public distribution via NPM. This phase cannot start until Phase 4 completes because it requires all features to be functional for proper testing, documentation, and packaging.

### 5.1 Enhanced Ink UI
Polish the interactive UI with improved visual design and user experience.

**Implementation Details**
- Systems affected: Ink components, terminal rendering
- Inputs: All application states and user interactions
- Outputs: Refined UI components
- Core logic:
  - Add color themes (default, colorblind-friendly, plain)
  - Implement progress bars for multi-step operations
  - Add confirmation dialogs with keyboard navigation
  - Create summary panels for operation results
  - Implement responsive layout for different terminal widths
- Failure modes:
  - Terminal too narrow (graceful degradation)
  - Unicode not supported (ASCII fallbacks)

**Acceptance Criteria**
- AC-5.1.a: When operation has multiple steps → progress bar shows completion percentage
- AC-5.1.b: When confirmation needed → Y/n dialog with clear styling
- AC-5.1.c: When `--no-color` flag set → all color codes stripped
- AC-5.1.d: When terminal width < 40 → layout adjusts without breaking
- AC-5.1.e: When operation completes → summary panel shows all results

**Acceptance Tests**
- Test-5.1.a: Snapshot test validates progress bar rendering
- Test-5.1.b: Unit test validates confirmation dialog keyboard handling
- Test-5.1.c: Unit test validates no-color flag removes ANSI codes
- Test-5.1.d: Unit test validates narrow terminal layout adjustment

---

### 5.2 Error Handling and Help System
Implement comprehensive error handling with helpful, actionable messages.

**Implementation Details**
- Systems affected: All components, error boundaries
- Inputs: Errors from any operation
- Outputs: Formatted, helpful error messages
- Core logic:
  - Categorize errors (user fixable, bug, network, permission)
  - Provide specific fix instructions for common errors
  - Include documentation links where relevant
  - Implement `--verbose` stack traces for debugging
  - Create contextual help for each subcommand
- Failure modes:
  - Unknown error (generic message with bug report link)

**Acceptance Criteria**
- AC-5.2.a: When common error occurs → specific fix instructions displayed
- AC-5.2.b: When unknown error occurs → generic message with issue tracker link
- AC-5.2.c: When `--verbose` set → full stack trace included
- AC-5.2.d: When `script-mgr help {command}` → detailed help for that command
- AC-5.2.e: When operation fails → error is logged to debug file for issue reports

**Acceptance Tests**
- Test-5.2.a: Unit test validates error categorization for known error types
- Test-5.2.b: Unit test validates verbose flag includes stack trace
- Test-5.2.c: Unit test validates help text completeness for all commands
- Test-5.2.d: Integration test validates error log file creation

---

### 5.3 NPM Package Configuration
Configure the project for publishing to NPM as a global CLI tool.

**Implementation Details**
- Systems affected: package.json, npm registry, build system
- Inputs: Package metadata, build artifacts
- Outputs: Publishable npm package
- Core logic:
  - Configure `bin` field in package.json for global install
  - Set up proper `files` field to include only necessary files
  - Create prepublish build script
  - Configure package scope (optional @username/script-mgr)
  - Add keywords, repository, homepage fields for discoverability
- Failure modes:
  - Package name taken (suggest alternatives)
  - Build fails during prepublish

**Acceptance Criteria**
- AC-5.3.a: When `npm install -g` runs → `script-mgr` command available globally
- AC-5.3.b: When package installed → only production files included (no dev files)
- AC-5.3.c: When `npm publish --dry-run` → shows correct package contents
- AC-5.3.d: When published → package page shows correct metadata

**Acceptance Tests**
- Test-5.3.a: Integration test validates global install creates working command
- Test-5.3.b: Unit test validates package.json bin field configuration
- Test-5.3.c: Test validates npm pack produces expected tarball contents

---

### 5.4 Documentation and Examples
Create user-facing documentation for installation and usage.

**Implementation Details**
- Systems affected: Repository docs, npm package
- Inputs: Feature specifications, CLI help text
- Outputs: README.md, examples, CHANGELOG
- Core logic:
  - Write comprehensive README with installation, quick start, full usage
  - Create example scripts demonstrating workflows
  - Document all CLI flags and configuration options
  - Include troubleshooting section for common issues
  - Add contributing guidelines for open source
- Failure modes:
  - Documentation out of sync with code (add doc tests)

**Acceptance Criteria**
- AC-5.4.a: README contains installation instructions for npm global install
- AC-5.4.b: README contains quick start example that works
- AC-5.4.c: All CLI flags documented with examples
- AC-5.4.d: Configuration file format fully documented
- AC-5.4.e: Troubleshooting section covers top 5 anticipated issues

**Acceptance Tests**
- Test-5.4.a: Documentation test validates README examples execute successfully
- Test-5.4.b: Lint test validates all CLI flags have documentation
- Test-5.4.c: Link test validates all documentation URLs are valid

---

### 5.5 Test Suite and CI/CD
Establish comprehensive test coverage and continuous integration pipeline.

**Implementation Details**
- Systems affected: Test framework, GitHub Actions
- Inputs: All source code modules
- Outputs: Test results, coverage reports, published releases
- Core logic:
  - Configure Jest or Vitest for unit and integration tests
  - Set up GitHub Actions for CI on push/PR
  - Add coverage thresholds (target: 80% coverage)
  - Configure automated npm publish on version tags
  - Add semantic release for automated versioning
- Failure modes:
  - Flaky tests (identify and fix)
  - CI timeout (optimize test parallelization)

**Acceptance Criteria**
- AC-5.5.a: When PR opened → tests run automatically
- AC-5.5.b: When tests pass and tag pushed → npm publish triggered
- AC-5.5.c: When coverage drops below 80% → build fails
- AC-5.5.d: When tests fail → clear report of failures in PR
- AC-5.5.e: Test suite runs in under 2 minutes

**Acceptance Tests**
- Test-5.5.a: CI configuration test validates workflow triggers correctly
- Test-5.5.b: Coverage test validates threshold enforcement
- Test-5.5.c: Timing test validates test suite completes under 2 minutes

---

## 3. Completion Criteria
The project is considered complete when:
- All phase acceptance criteria pass (Phases 1-5)
- All acceptance tests are green with 80%+ code coverage
- No open P0 (critical) or P1 (high) issues remain
- Documentation is complete and validated
- Package is published to npm and installable globally
- At least 3 end-to-end workflows validated:
  1. Create new bash script, install, verify in PATH
  2. Edit existing script, reinstall, verify changes
  3. Create script, install, sync to GitHub
- Performance target met: complete workflow in under 60 seconds (excluding editor time)

---

## 4. Rollout & Validation

### Rollout Strategy
1. **Alpha Release (v0.1.0)**
   - Internal testing only
   - Install from local source or GitHub
   - Gather feedback on core workflows

2. **Beta Release (v0.5.0)**
   - Publish to npm with `beta` tag: `npm install -g script-mgr@beta`
   - Announce in developer communities for early adopter feedback
   - Monitor error rates and user reports

3. **General Availability (v1.0.0)**
   - Publish to npm as latest
   - Full documentation and examples available
   - Support channels established (GitHub Issues)

### Feature Flags
- `SCRIPT_MGR_GITHUB_SYNC=0` - Disable GitHub sync functionality
- `SCRIPT_MGR_EDITOR=vim` - Override editor (future-proofing)
- `SCRIPT_MGR_INSTALL_PATH=/custom/path` - Override installation directory

### Post-Launch Validation
**Metrics to Monitor**
- npm weekly download count (target: 1,000+ within 3 months)
- GitHub stars (target: 500+ within 6 months)
- Error rate from telemetry (target: <2% failure rate)
- Issue response time (target: first response within 48 hours)
- User retention (weekly active usage)

**Rollback Triggers**
- Error rate exceeds 10% for any core operation
- Critical security vulnerability discovered
- Major regression in user workflow
- npm package corrupted or unusable

**Rollback Procedure**
1. Unpublish problematic version: `npm unpublish script-mgr@x.x.x`
2. Republish last known good version as latest
3. Post incident report to GitHub repository
4. Notify affected users via release notes

---

## 5. Open Questions
- Should the tool support multiple GitHub repositories for different categories of scripts?
- What should happen if a script already exists in `/usr/local/bin` from a different source (Homebrew, manual install, etc.)?
- Should we support private GitHub repositories for proprietary scripts, and how should authentication differ?
- How should we handle scripts that require additional dependencies (e.g., Python packages, Node modules)?
- Should the GitHub repository have a specific structure (e.g., `bin/`, `scripts/`, organized by language)?
- Should we auto-generate a README.md in the GitHub repo listing all managed scripts with descriptions?
- What should the npm package name be to avoid conflicts? (e.g., `@scope/script-mgr`, `build-script-mgr`)
- Should we support uninstalling/removing scripts from `/usr/local/bin` with a dedicated command?
- How should we handle script execution on systems where `/usr/local/bin` is not in PATH by default?
- Should we support syncing scripts from GitHub to local (pull/clone functionality)?
