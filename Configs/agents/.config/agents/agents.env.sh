# agents.env.sh
# Unified environment configuration for AI agents
# Sourced by shell/env.sh
# This centralizes all AI-related environment variables

# ---------------------------------------------------------------------------
# OpenCode Configuration
# ---------------------------------------------------------------------------
# OpenCode reads permissions only from its own config file. There is no env var
# for skipping prompts or trusting directories, so permissions and trusted paths
# live in ~/.config/opencode/config.json.

# ---------------------------------------------------------------------------
# Pi Agent Configuration
# ---------------------------------------------------------------------------
# Pi uses user-managed settings.json for configuration
# Located at: ~/.pi/agent/settings.json

# ---------------------------------------------------------------------------
# OpenAI/Codex Configuration
# ---------------------------------------------------------------------------
# API keys are managed by Monosecret + 1Password; use msr --reason "<why>" <command> for lazy injection.
# Codex config typically at ~/.codex/config.json

# ---------------------------------------------------------------------------
# Future AI Tools
# Add new environment variables here as needed
# ---------------------------------------------------------------------------
