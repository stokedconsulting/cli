# Build Script Manager CLI

## 1. Feature Overview
**Feature Name:** Build Script Manager CLI
**Owner:** TBD
**Status:** Draft
**Target Release:** Q2 2026

### Summary
Build Script Manager CLI is a command-line tool built with Ink (React for CLIs) that streamlines the creation, editing, and deployment of shell scripts. It provides an intuitive workflow for developers to create new scripts with proper shebangs, make them executable, install them system-wide to `/usr/local/bin`, and sync them to a GitHub repository for version control and distribution via NPM. The goal is to eliminate the friction of managing personal CLI tools across machines.

---

## 2. Problem Statement
### What problem are we solving?
Developers frequently create small shell scripts, utility commands, and personal CLI tools that live scattered across their systems. Managing these scripts is tedious: setting proper permissions, installing them to PATH directories, keeping them version-controlled, and syncing them across multiple machines requires manual, error-prone steps. There is no unified workflow for creating, maintaining, and deploying personal CLI tooling.

### Who is affected?
- **Primary user:** Software developers who create and maintain personal shell scripts and CLI utilities
- **Secondary users:** DevOps engineers, system administrators, and power users who want to package and distribute their custom tooling

### Why now?
- The rise of dotfiles repositories shows developers want portable, version-controlled configurations
- NPM has become a standard distribution mechanism for CLI tools, but there's no streamlined path from "quick script" to "published package"
- Remote work and multi-machine setups have increased the need for synchronized development environments
- Modern CLI frameworks like Ink enable rich, interactive terminal experiences that weren't previously possible

---

## 3. Goals & Success Metrics
### Goals
- Reduce the time from "I need a script" to "It's installed and version-controlled" to under 60 seconds
- Provide a single command interface for the entire script lifecycle (create, edit, install, sync)
- Enable developers to maintain a personal CLI toolkit that can be installed from NPM on any machine
- Eliminate manual chmod, sudo cp, and git operations for script management

### Success Metrics (How we'll know it worked)
- Time to create and install a new script: baseline (5+ minutes manual) to target (< 60 seconds)
- User adoption: 500+ GitHub stars within 6 months of release
- NPM weekly downloads: 1,000+ within 3 months of release
- User retention: 40%+ of installers use the tool more than once per week
- Error rate: < 2% of script installation operations fail

---

## 4. User Experience & Scope
### In Scope
- Accept file path or directory path as CLI argument
- Detect if file exists; if not, open VIM for editing with appropriate shebang pre-populated
- Automatically detect script type and insert correct shebang (bash, zsh, python, node, etc.)
- Make file executable (chmod +x) upon VIM exit
- Copy script to `/usr/local/bin` using sudo for system-wide availability
- Configuration file support for GitHub repository settings
- Upload/sync script to configured GitHub repository
- Interactive Ink-based UI for status, progress, and confirmations
- Support for both individual files and directories of scripts
- NPM package structure for easy global installation

### Out of Scope
- GUI or web interface
- Support for editors other than VIM in v1 (future enhancement)
- Automatic NPM publishing (manual publish step required)
- Windows support in v1 (macOS and Linux only)
- Script dependency management
- Script testing framework
- Rollback/versioning of installed scripts (relies on git history)

---

## 5. Assumptions & Constraints
### Assumptions
- Users have VIM installed and basic familiarity with it
- Users have sudo access on their machine
- Users have a GitHub account and configured git credentials
- `/usr/local/bin` exists and is in the user's PATH
- Users have Node.js 18+ installed for running the CLI
- Users want their scripts stored in a single GitHub repository

### Constraints
- **Technical:** Must work within terminal constraints; Ink provides React-like components but is limited to terminal capabilities
- **Technical:** Requires sudo for `/usr/local/bin` installation, which may prompt for password
- **Security:** Must handle sudo operations carefully to avoid security vulnerabilities
- **Platform:** macOS and Linux only; Windows would require significant path and permission handling changes
- **Timeline:** Target MVP within 4-6 weeks of development
- **Resources:** Single developer project initially

---

## 6. Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| Sudo operations could be misused or create security concerns | High | Clearly document what sudo is used for; only copy to `/usr/local/bin`; never execute arbitrary code with elevated privileges |
| VIM dependency alienates non-VIM users | Medium | Plan for configurable editor support via EDITOR env variable in v1.1 |
| GitHub API rate limits could block syncing | Medium | Implement local caching; batch operations; use authenticated requests |
| Script name conflicts in `/usr/local/bin` | Medium | Check for existing files and prompt user before overwriting; show diff if possible |
| Shebang detection may not cover all languages | Low | Start with common shells and scripting languages; make shebang configurable |
| Git credential issues could block GitHub sync | Medium | Provide clear error messages; link to GitHub credential setup docs |

---

## 7. Dependencies
### Team Dependencies
- None (single developer project)

### External Systems / Vendors
- **GitHub API:** For repository creation, file upload, and sync operations
- **NPM Registry:** For package distribution
- **VIM:** External editor dependency for file creation/editing

### Data or Infrastructure Dependencies
- GitHub personal access token or SSH key for authentication
- Local filesystem access for script storage
- Network connectivity for GitHub sync operations

### Package Dependencies
- **Ink:** React-based CLI framework for terminal UI
- **Octokit:** GitHub API client
- **Commander/Yargs:** CLI argument parsing (or Ink's built-in handling)
- **fs-extra:** Enhanced filesystem operations
- **execa:** For spawning VIM and running shell commands

---

## 8. Open Questions
- Should the tool support multiple GitHub repositories for different categories of scripts?
- What should happen if a script already exists in `/usr/local/bin` from a different source?
- Should we support private GitHub repositories for proprietary scripts?
- How should we handle scripts that require additional dependencies (e.g., Python packages)?
- Should the GitHub repository have a specific structure (e.g., `bin/`, `scripts/` directories)?
- Should we auto-generate a README.md in the GitHub repo listing all scripts?
- What should the NPM package name be? (e.g., `@username/scripts`, `my-cli-tools`)
- Should we support uninstalling/removing scripts from `/usr/local/bin`?

---

## 9. Non-Goals
- This tool is **not** a replacement for full CLI frameworks like Commander, Yargs, or oclif for building complex applications
- This tool does **not** aim to manage system packages or replace package managers like Homebrew
- This tool will **not** handle script runtime dependencies or virtual environments
- This tool is **not** designed for team/organization-wide script distribution (focused on personal use)
- This tool will **not** provide script execution sandboxing or security scanning
- This tool does **not** aim to be cross-platform in v1 (Windows support is not a goal)

---

## 10. Notes & References

### Prior Art
- [dotfiles](https://dotfiles.github.io/) - Community around managing dotfiles via git
- [Homebrew](https://brew.sh/) - macOS package manager (inspiration for installation flow)
- [npx](https://docs.npmjs.com/cli/v8/commands/npx) - NPM package runner
- [bash-it](https://github.com/Bash-it/bash-it) - Community bash framework

### Technical References
- [Ink Documentation](https://github.com/vadimdemedes/ink) - React for CLI apps
- [Octokit.js](https://github.com/octokit/octokit.js) - GitHub API client
- [GitHub REST API](https://docs.github.com/en/rest) - For repository and file operations

### Design Considerations
- CLI should feel snappy; minimize network calls during common operations
- Use spinners and progress indicators for long-running operations
- Provide clear, actionable error messages
- Support `--dry-run` flag to preview operations without executing
- Consider adding `--verbose` flag for debugging

### Future Enhancements (Post-MVP)
- Configurable editor support (respect EDITOR environment variable)
- Windows support via WSL or native paths
- Script templates for common patterns
- Automatic NPM version bumping and publishing
- Script grouping/tagging for organization
- Import scripts from existing dotfiles repositories
- Backup/restore functionality
- Integration with GitHub Actions for CI/CD of scripts
