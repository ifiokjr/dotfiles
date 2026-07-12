#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETUP_SCRIPT="$ROOT_DIR/Configs/codex/.config/codex/setup-codex.sh"
PROVIDERS_DIR="$ROOT_DIR/Configs/codex/.config/codex"
HOOK_SCRIPT="$ROOT_DIR/Hooks/codex/post.sh"
GROUP_METADATA="$ROOT_DIR/Configs/codex.group.toml"
TEST_DIR="$(mktemp -d)"
TEST_HOME="$TEST_DIR/home"
CONFIG="$TEST_HOME/.codex/config.toml"

cleanup() {
	rm -rf "$TEST_DIR"
}
trap cleanup EXIT

fail() {
	echo "codex setup test failed: $1" >&2
	exit 1
}

require_line() {
	local line="$1"
	grep -Fqx -- "$line" "$CONFIG" || fail "missing line: $line"
}

require_count() {
	local expected="$1"
	local pattern="$2"
	local actual

	actual="$(grep -Ec "$pattern" "$CONFIG" || true)"
	[ "$actual" -eq "$expected" ] || fail "expected $expected matches for $pattern, found $actual"
}

run_setup() {
	HOME="$TEST_HOME" DOTFILES_CODEX_DIR="$PROVIDERS_DIR" bash "$SETUP_SCRIPT" >/dev/null
}

validate_toml() {
	local config_path="${1:-$CONFIG}"

	# Nushell reads CONFIG_PATH at runtime; Bash must not expand the command body.
	# shellcheck disable=SC2016
	CONFIG_PATH="$config_path" nu -c '
		let config = (open --raw $env.CONFIG_PATH | from toml)
		if $config.agents.max_threads != 32 {
			error make { msg: "agents.max_threads was not set to 32" }
		}
		if $config.agents.max_depth != 2 {
			error make { msg: "agents.max_depth was not set to 2" }
		}
	' || fail "generated config is not valid TOML with the expected limits"
}

mkdir -p "$TEST_HOME"

# A fresh installation creates config.toml with both managed settings and providers.
run_setup
[ -f "$CONFIG" ] || fail "fresh setup did not create config.toml"
validate_toml
require_count 1 '^\[agents\]$'
require_count 1 '^max_threads[[:space:]]*='
require_count 1 '^max_depth[[:space:]]*='
require_count 1 '^\[model_providers\.xiaomi\]$'

# Existing app-managed settings, sections, and comments are preserved while the
# two managed values are updated.
cat >"$CONFIG" <<'EOF'
model = "app-managed-model"
# Keep this app-managed comment.

[agents]
max_threads = 4 # retain this explanation
custom_setting = "keep-me"
max_depth = 9

[projects."/tmp/example"]
trust_level = "trusted"
EOF

run_setup
validate_toml
require_line 'model = "app-managed-model"'
require_line '# Keep this app-managed comment.'
require_line 'max_threads = 32 # retain this explanation'
require_line 'custom_setting = "keep-me"'
require_line 'trust_level = "trusted"'
require_count 1 '^\[agents\]$'
require_count 1 '^max_threads[[:space:]]*='
require_count 1 '^max_depth[[:space:]]*='
require_count 1 '^\[model_providers\.xiaomi\]$'

# A second run produces no further config changes.
cp "$CONFIG" "$TEST_DIR/config.once.toml"
run_setup
cmp -s "$TEST_DIR/config.once.toml" "$CONFIG" || fail "setup is not idempotent"

# Quoted table/key syntax and root-level dotted keys remain valid TOML.
cat >"$CONFIG" <<'EOF'
["agents"]
"max_threads" = 3
'max_depth' = 7
other = true
EOF
run_setup
validate_toml
require_line '["agents"]'
require_line 'other = true'

cat >"$CONFIG" <<'EOF'
agents."max_threads" = 3 # keep dotted style valid
model = "app-managed-model"

[features]
multi_agent = true
EOF
run_setup
validate_toml
require_line 'agents.max_threads = 32 # keep dotted style valid'
require_line 'agents.max_depth = 2'
require_line 'multi_agent = true'

# An unsupported inline table fails safely instead of creating duplicate TOML keys.
cat >"$CONFIG" <<'EOF'
model = "leave-this-file-alone"
agents = { max_threads = 3, max_depth = 1 }
EOF
cp "$CONFIG" "$TEST_DIR/inline-agents.toml"
if HOME="$TEST_HOME" DOTFILES_CODEX_DIR="$PROVIDERS_DIR" bash "$SETUP_SCRIPT" >/dev/null 2>&1; then
	fail "inline agents configuration should require manual normalization"
fi
cmp -s "$TEST_DIR/inline-agents.toml" "$CONFIG" || fail "failed inline update changed config.toml"

# Updating a symlinked config writes through it instead of replacing the link.
SYMLINK_TARGET="$TEST_DIR/symlinked-config.toml"
printf 'model = "symlink-managed"\n' >"$SYMLINK_TARGET"
rm -f "$CONFIG"
ln -s "$SYMLINK_TARGET" "$CONFIG"
run_setup
[ -L "$CONFIG" ] || fail "setup replaced a symlinked config.toml"
validate_toml "$SYMLINK_TARGET"
grep -Fqx 'model = "symlink-managed"' "$SYMLINK_TARGET" || fail "symlink target content was not preserved"

# The deployed hook resolves the setup script from ~/.config/codex.
HOOK_HOME="$TEST_DIR/hook-home"
mkdir -p "$HOOK_HOME/.config"
ln -s "$PROVIDERS_DIR" "$HOOK_HOME/.config/codex"
HOME="$HOOK_HOME" bash "$HOOK_SCRIPT" >/dev/null
validate_toml "$HOOK_HOME/.codex/config.toml"

# Group metadata keeps Codex setup in both user-facing developer presets.
# Nushell reads GROUP_METADATA at runtime; Bash must not expand the command body.
# shellcheck disable=SC2016
GROUP_METADATA="$GROUP_METADATA" nu -c '
	let metadata = (open --raw $env.GROUP_METADATA | from toml)
	if "dev" not-in $metadata.presets or "workstation" not-in $metadata.presets {
		error make { msg: "codex group is missing a required setup preset" }
	}
' || fail "Codex group metadata does not cover fresh developer installations"

echo "codex setup test passed"
