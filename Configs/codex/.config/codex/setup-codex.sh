#!/usr/bin/env bash
# Setup script for Codex global settings and custom providers.
# Ollama is built in to Codex and does not need a custom provider.
set -euo pipefail

CODEX_DIR="$HOME/.codex"
DOTFILES_CODEX_DIR="${DOTFILES_CODEX_DIR:-$HOME/.config/codex}"
CONFIG="$CODEX_DIR/config.toml"
TEMP_CONFIG=""

cleanup() {
	if [ -n "$TEMP_CONFIG" ]; then
		rm -f "$TEMP_CONFIG"
	fi
}
trap cleanup EXIT

ensure_agent_limits() {
	TEMP_CONFIG="$(mktemp "${TMPDIR:-/tmp}/codex-config.XXXXXX")"

	awk '
		function print_limit(key, value, line, indent, comment) {
			indent = line
			sub(/[^[:space:]].*$/, "", indent)
			comment = line
			sub(/^[^#]*/, "", comment)
			print indent key " = " value (comment == "" ? "" : " " comment)
		}

		function add_missing_table_limits() {
			if (!found_threads) {
				print "max_threads = 32"
				found_threads = 1
			}
			if (!found_depth) {
				print "max_depth = 2"
				found_depth = 1
			}
		}

		function add_missing_dotted_limits() {
			if (!found_threads) {
				print "agents.max_threads = 32"
				found_threads = 1
			}
			if (!found_depth) {
				print "agents.max_depth = 2"
				found_depth = 1
			}
		}

		BEGIN {
			in_root = 1
		}

		{
			if (in_root && $0 ~ /^[[:space:]]*(agents|"agents"|\047agents\047)[[:space:]]*=/) {
				print "Cannot safely update inline Codex agents configuration: " $0 > "/dev/stderr"
				unsupported = 1
				exit 2
			}

			if (in_root && $0 ~ /^[[:space:]]*(agents|"agents"|\047agents\047)[[:space:]]*\.[[:space:]]*(max_threads|"max_threads"|\047max_threads\047)[[:space:]]*=/) {
				print_limit("agents.max_threads", 32, $0)
				found_agents = 1
				found_dotted_agents = 1
				found_threads = 1
				next
			}

			if (in_root && $0 ~ /^[[:space:]]*(agents|"agents"|\047agents\047)[[:space:]]*\.[[:space:]]*(max_depth|"max_depth"|\047max_depth\047)[[:space:]]*=/) {
				print_limit("agents.max_depth", 2, $0)
				found_agents = 1
				found_dotted_agents = 1
				found_depth = 1
				next
			}

			if ($0 ~ /^[[:space:]]*\[[[:space:]]*(agents|"agents"|\047agents\047)[[:space:]]*\][[:space:]]*(#.*)?$/) {
				if (in_root && found_dotted_agents) {
					add_missing_dotted_limits()
				}
				in_root = 0
				in_agents = 1
				found_agents = 1
				print
				next
			}

			if ($0 ~ /^[[:space:]]*\[/) {
				if (in_agents) {
					add_missing_table_limits()
					in_agents = 0
				}
				if (in_root) {
					if (found_dotted_agents) {
						add_missing_dotted_limits()
					}
					in_root = 0
				}
			}

			if (in_agents && $0 ~ /^[[:space:]]*(max_threads|"max_threads"|\047max_threads\047)[[:space:]]*=/) {
				print_limit("max_threads", 32, $0)
				found_threads = 1
				next
			}

			if (in_agents && $0 ~ /^[[:space:]]*(max_depth|"max_depth"|\047max_depth\047)[[:space:]]*=/) {
				print_limit("max_depth", 2, $0)
				found_depth = 1
				next
			}

			print
		}

		END {
			if (unsupported) {
				exit 2
			}
			if (in_agents) {
				add_missing_table_limits()
			} else if (in_root && found_dotted_agents) {
				add_missing_dotted_limits()
			} else if (!found_agents) {
				if (NR > 0) {
					print ""
				}
				print "[agents]"
				print "max_threads = 32"
				print "max_depth = 2"
			}
		}
	' "$CONFIG" >"$TEMP_CONFIG"

	# Write through an existing symlink and preserve app-managed file metadata.
	cat "$TEMP_CONFIG" >"$CONFIG"
	rm -f "$TEMP_CONFIG"
	TEMP_CONFIG=""
	echo "✓ Ensured Codex multi-agent limits (max_threads = 32, max_depth = 2)"
}

echo "Setting up Codex configuration..."

mkdir -p "$CODEX_DIR"
if [ ! -e "$CONFIG" ]; then
	(umask 077 && touch "$CONFIG")
fi

ensure_agent_limits

# Check whether the optional plaintext fallback exists. Monosecret is preferred.
if [ ! -f "$CODEX_DIR/secrets.env" ]; then
	echo "ℹ  Optional $CODEX_DIR/secrets.env fallback not found; use 'ssr codex' for 1Password-backed keys"
else
	echo "✓ secrets.env fallback exists"
fi

# Add providers to config.toml if not already present.
if ! grep -q "\[model_providers.xiaomi\]" "$CONFIG"; then
	echo "Adding custom providers to config.toml..."
	if [ -f "$DOTFILES_CODEX_DIR/providers.toml" ]; then
		printf '\n' >>"$CONFIG"
		cat "$DOTFILES_CODEX_DIR/providers.toml" >>"$CONFIG"
		echo "✓ Added custom providers"
	else
		echo "⚠ providers.toml not found in dotfiles"
	fi
else
	echo "✓ Custom providers already configured"
fi

echo ""
echo "Profiles available:"
echo "  codex --profile mimo            # Xiaomi MiMo-V2.5-Pro"
echo "  codex --profile mimo-flash      # Xiaomi MiMo-V2-Flash"
echo "  codex --profile ollama-gemma4   # Local Gemma4 26B"
echo "  codex --profile ollama-deepseek # Local DeepSeek R1"
echo "  codex --profile cloud-kimi      # Kimi K2.5 via Ollama Cloud"
