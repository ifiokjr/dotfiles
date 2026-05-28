#!/bin/bash
# Setup script for Codex custom providers (Xiaomi MiMo, Ollama Cloud)
# Ollama is built-in to Codex and does not need a custom provider.
set -e

CODEX_DIR="$HOME/.codex"
DOTFILES_CODEX_DIR="$HOME/.config/codex"
CONFIG="$CODEX_DIR/config.toml"

echo "Setting up Codex custom providers..."

mkdir -p "$CODEX_DIR"

# Check if secrets.env exists
if [ ! -f "$CODEX_DIR/secrets.env" ]; then
	echo ""
	echo "⚠  secrets.env not found in $CODEX_DIR"
	echo "   Create it with your API keys:"
	echo ""
	echo "   cat > $CODEX_DIR/secrets.env << 'EOF'"
	echo "   XIAOMI_MIMO_API_KEY=tp-your-key-here"
	echo "   OLLAMA_CLOUD_API_KEY=your-ollama-cloud-key"
	echo "   EOF"
	echo "   chmod 600 $CODEX_DIR/secrets.env"
	echo ""
else
	echo "✓ secrets.env exists"
fi

# Add providers to config.toml if not already present
if [ -f "$CONFIG" ]; then
	if ! grep -q "\[model_providers.xiaomi\]" "$CONFIG"; then
		echo "Adding custom providers to config.toml..."
		if [ -f "$DOTFILES_CODEX_DIR/providers.toml" ]; then
			echo "" >>"$CONFIG"
			cat "$DOTFILES_CODEX_DIR/providers.toml" >>"$CONFIG"
			echo "✓ Added custom providers"
		else
			echo "⚠ providers.toml not found in dotfiles"
		fi
	else
		echo "✓ Custom providers already configured"
	fi
else
	echo "⚠ config.toml not found — run 'codex' once to create it, then re-run this script"
fi

echo ""
echo "Profiles available:"
echo "  codex --profile mimo            # Xiaomi MiMo-V2.5-Pro"
echo "  codex --profile mimo-flash      # Xiaomi MiMo-V2-Flash"
echo "  codex --profile ollama-gemma4   # Local Gemma4 26B"
echo "  codex --profile ollama-deepseek # Local DeepSeek R1"
echo "  codex --profile cloud-kimi      # Kimi K2.5 via Ollama Cloud"
