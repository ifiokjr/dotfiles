# agents.env.sh
# Unified environment configuration for AI agents
# Sourced by shell/env.sh
# This centralizes all AI-related environment variables

# ---------------------------------------------------------------------------
# OpenCode Configuration
# ---------------------------------------------------------------------------
# Allow all file access without permission prompts
export OPENCODE_DANGEROUSLY_SKIP_PERMISSIONS=true
export OPENCODE_ALLOW_ALL_BASH=true

# Trusted directories - these paths are automatically allowed
# Note: The config file at ~/.config/opencode/config.json is the source of truth
# These env vars provide fallback behavior
export OPENCODE_TRUSTED_DIRECTORIES="/Users/ifiokjr/Developer:/Users/ifiokjr/Developer/.dotfiles:/tmp"

# ---------------------------------------------------------------------------
# Pi Agent Configuration
# ---------------------------------------------------------------------------
# Pi uses user-managed settings.json for configuration
# Located at: ~/.pi/agent/settings.json

# ---------------------------------------------------------------------------
# Claude CLI Configuration (if applicable)
# ---------------------------------------------------------------------------
# Claude stores config in ~/.config/claude/
# Currently managed through Claude Desktop app

# ---------------------------------------------------------------------------
# OpenAI/Codex Configuration
# ---------------------------------------------------------------------------
# API keys should be in ~/.env.dotfiles (not committed)
# Codex config typically at ~/.codex/config.json

# ---------------------------------------------------------------------------
# Future AI Tools
# Add new environment variables here as needed
# ---------------------------------------------------------------------------
