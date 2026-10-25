# agents.env.sh
# Unified environment configuration for AI agents
# Sourced by shell/env.sh
# This centralizes all AI-related environment variables

# ---------------------------------------------------------------------------
# OpenCode Configuration
# ---------------------------------------------------------------------------
# OpenCode reads permissions only from its own config file. There is no env var
# for skipping prompts or trusting directories, so permissions and trusted paths
# live in ~/.config/opencode/opencode.json.

# ---------------------------------------------------------------------------
# Claude Code Configuration
# ---------------------------------------------------------------------------
# Claude Code reads permissions only from settings.json. There is no documented
# env var that sets the default permission mode, so it lives in
# ~/.claude/settings.json under permissions.defaultMode.

# ---------------------------------------------------------------------------
# Pi Agent Configuration
# ---------------------------------------------------------------------------
# Pi uses user-managed settings.json for configuration
# Located at: ~/.pi/agent/settings.json

# ---------------------------------------------------------------------------
# OpenAI/Codex Configuration
# ---------------------------------------------------------------------------
# API keys are managed by Monosecret + 1Password; use msr --reason "<why>" <command> for lazy injection.
# Codex config is the machine-local ~/.codex/config.toml (Codex rewrites it, so it
# cannot be symlinked from the repo). It carries [analytics] enabled = false to
# disable the default Statsig metrics exporter; reapply that on a fresh machine.

# ---------------------------------------------------------------------------
# Z.AI (GLM) for OpenCode
# ---------------------------------------------------------------------------
# OpenCode's Z.AI providers auto-activate from ZHIPU_API_KEY — one variable
# enables zai, zai-coding-plan, zhipuai, and zhipuai-coding-plan. The key is a
# GLM Coding Plan subscription, so select models as zai-coding-plan/glm-5.3
# (the non-plan `zai` endpoint answers 429 with this key). Ollama Cloud needs
# no wiring here: it activates from OLLAMA_API_KEY, exported in shell/env.sh.
#
# The key is deliberately NOT exported into every interactive shell: an
# ambient key is inherited by every process (including every AI agent shell),
# so a prompt injection anywhere can exfiltrate it. OpenCode reads the same
# Keychain item via the auth.json seeded by Hooks/agents/post.sh, and ad-hoc
# shells can inject it on demand with:
#   msr --reason "opencode zai provider" opencode
# or export it manually for the current session only.

# ---------------------------------------------------------------------------
# Future AI Tools
# Add new environment variables here as needed
# ---------------------------------------------------------------------------
