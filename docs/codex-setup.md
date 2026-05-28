# Codex Custom Providers Setup

Codex supports Xiaomi MiMo, local Ollama, and Ollama Cloud models via custom providers.

## Quick Setup

```bash
~/.config/codex/setup-codex.sh
```

## Available Profiles

| Profile           | Provider       | Model              | Description                            |
| ----------------- | -------------- | ------------------ | -------------------------------------- |
| `mimo`            | Xiaomi MiMo    | mimo-v2.5-pro      | Flagship reasoning model (1M context)  |
| `mimo-flash`      | Xiaomi MiMo    | mimo-v2-flash      | Fast, low-cost model                   |
| `mimo-omni`       | Xiaomi MiMo    | mimo-v2.5          | Multimodal (text, image, audio, video) |
| `ollama-gemma4`   | Ollama (local) | gemma4:26b         | Local Gemma4 26B                       |
| `ollama-deepseek` | Ollama (local) | deepseek-r1:latest | Local DeepSeek R1                      |
| `ollama-gemma3`   | Ollama (local) | gemma3:27b         | Local Gemma3 27B                       |
| `cloud-kimi`      | Ollama Cloud   | kimi-k2.5          | Kimi K2.5 via Ollama Cloud             |
| `cloud-glm`       | Ollama Cloud   | glm-5.1            | GLM 5.1 via Ollama Cloud               |

## Usage

```bash
codex --profile mimo              # Xiaomi MiMo-V2.5-Pro
codex --profile ollama-gemma4     # Local Gemma4 26B
codex --profile cloud-kimi        # Kimi K2.5 via cloud
```

## Secrets

API keys are managed via **SecretSpec + 1Password** (not plaintext on disk).

```bash
# Run Codex with secrets injected from 1Password:
ssr codex --profile mimo

# Or load all secrets into shell first:
ssload
```

Keys are in `secretspec.toml` → `op://Development/dotfiles` vault (`ai` path):

- `XIAOMI_MIMO_API_KEY`
- `OLLAMA_CLOUD_API_KEY`

A fallback `~/.codex/secrets.env` (mode 600, not in git) can be used when 1Password is unavailable.

## Getting API Keys

- **Xiaomi MiMo**: [platform.xiaomimimo.com](https://platform.xiaomimimo.com/console/api-keys)
- **Ollama Cloud**: [ollama.com](https://ollama.com)
- **Local Ollama**: No key needed — just run `ollama serve`

## Notes

- Ollama is a **built-in** Codex provider — no custom definition needed
- Use `--local-provider ollama` or `--oss` for local models without a profile
- Xiaomi MiMo and Ollama Cloud are custom providers defined in config.toml
