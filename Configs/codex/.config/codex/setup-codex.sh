#!/bin/bash
# Setup script for Codex custom providers
# This script copies the necessary configuration and secrets

set -e

CODEX_DIR="$HOME/.codex"
DOTFILES_CODEX_DIR="$HOME/.config/codex"

echo "Setting up Codex custom providers..."

# Create Codex directory if it doesn't exist
mkdir -p "$CODEX_DIR"

# Copy providers.toml to Codex config if it doesn't exist
if [ ! -f "$CODEX_DIR/providers.toml" ]; then
    if [ -f "$DOTFILES_CODEX_DIR/providers.toml" ]; then
        cp "$DOTFILES_CODEX_DIR/providers.toml" "$CODEX_DIR/providers.toml"
        echo "✓ Copied providers.toml to $CODEX_DIR"
    else
        echo "⚠ providers.toml not found in dotfiles"
    fi
else
    echo "✓ providers.toml already exists"
fi

# Check if secrets.env exists
if [ ! -f "$CODEX_DIR/secrets.env" ]; then
    echo ""
    echo "⚠ secrets.env not found in $CODEX_DIR"
    echo "  Please create it with your API keys:"
    echo ""
    echo "  cat > $CODEX_DIR/secrets.env << 'SECRETS'"
    echo "  # Codex API Keys"
    echo "  XIAOMI_MIMO_API_KEY=your-xiaomi-key-here"
    echo "  OLLAMA_CLOUD_API_KEY=your-ollama-cloud-key-here"
    echo "  OLLAMA_API_KEY="
    echo "  SECRETS"
    echo ""
    echo "  chmod 600 $CODEX_DIR/secrets.env"
else
    echo "✓ secrets.env already exists"
fi

# Add providers to config.toml if not already present
if [ -f "$CODEX_DIR/config.toml" ]; then
    if ! grep -q "\[model_providers.xiaomi\]" "$CODEX_DIR/config.toml"; then
        echo ""
        echo "Adding custom providers to config.toml..."
        cat >> "$CODEX_DIR/config.toml" << 'PROVIDERS'

# ============================================================================
# Custom Providers (added by setup-codex.sh)
# ============================================================================

[model_providers.xiaomi]
name = "Xiaomi MiMo"
base_url = "https://api.xiaomimimo.com/v1"
env_key = "XIAOMI_MIMO_API_KEY"

[model_providers.ollama]
name = "Ollama (Local)"
base_url = "http://localhost:11434/v1"
env_key = "OLLAMA_API_KEY"

[model_providers.ollama-cloud]
name = "Ollama Cloud"
base_url = "https://api.ollama.com/v1"
env_key = "OLLAMA_CLOUD_API_KEY"

# Profiles
[profiles.xiaomi]
model_provider = "xiaomi"
model = "mimo-v2.5-pro"

[profiles.ollama]
model_provider = "ollama"
model = "gemma4:26b"

[profiles.cloud]
model_provider = "ollama-cloud"
model = "kimi-k2.5"
PROVIDERS
        echo "✓ Added custom providers to config.toml"
    else
        echo "✓ Custom providers already in config.toml"
    fi
else
    echo "⚠ config.toml not found - run 'codex' once to create it"
fi

echo ""
echo "Setup complete! Usage:"
echo "  codex --profile xiaomi     # Xiaomi MiMo-V2.5-Pro"
echo "  codex --profile ollama     # Local Ollama models"
echo "  codex --profile cloud      # Ollama Cloud models"
