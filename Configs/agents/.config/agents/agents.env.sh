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
# Codex config typically at ~/.codex/config.json

# ---------------------------------------------------------------------------
# Z.AI (GLM) for OpenCode
# ---------------------------------------------------------------------------
# OpenCode's Z.AI providers auto-activate from ZHIPU_API_KEY — one variable
# enables zai, zai-coding-plan, zhipuai, and zhipuai-coding-plan. The key is a
# GLM Coding Plan subscription, so select models as zai-coding-plan/glm-5.3
# (the non-plan `zai` endpoint answers 429 with this key). Ollama Cloud needs
# no wiring here: it activates from OLLAMA_API_KEY, exported in shell/env.sh.
#
# Read from the same Keychain item Codex uses for its ZAI provider
# (model_providers.ZAI.auth in the Codex config) rather than duplicating the
# secret. Guarded so a missing item is silent, and skipped when already set.
if [ "$(uname -s)" = "Darwin" ] && [ -z "${ZHIPU_API_KEY:-}" ]; then
	_zhipu_key=$(/usr/bin/security find-generic-password \
		-a "${USER}" -s codex-zai-api-key -w 2>/dev/null || true)
	if [ -n "$_zhipu_key" ]; then
		export ZHIPU_API_KEY="$_zhipu_key"
	fi
	unset _zhipu_key
fi

# ---------------------------------------------------------------------------
# Future AI Tools
# Add new environment variables here as needed
# ---------------------------------------------------------------------------
