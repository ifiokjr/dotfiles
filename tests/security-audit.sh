#!/usr/bin/env bash
#
# security-audit.sh — security regression suite for the dotfiles repository.
#
# Every check encodes an attack vector that was found (and fixed) in the
# 2026-10 security audit, or an invariant that must never regress (e.g.
# "the application firewall stays on", "the Tailscale daemon stays
# allowlisted", "actions stay SHA-pinned"). A check failing means someone —
# usually a well-meaning future change — reintroduced a vulnerability.
#
# Usage:
#   tests/security-audit.sh              # audit the repo this script lives in
#   tests/security-audit.sh /path/repo   # audit another checkout
#   tests/security-audit.sh --list       # list checks
#   tests/security-audit.sh --self-test  # adversarial mode: inject each known
#                                        # violation into a scratch copy and
#                                        # prove the matching check catches it
#
# The suite only needs bash + coreutils + git; gitleaks is used when
# available and skipped with a notice otherwise. CI installs it.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT=""
MODE="audit"

usage() {
	sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
	exit "${1:-0}"
}

while [ "$#" -gt 0 ]; do
	case "$1" in
	--list) MODE="list" ;;
	--self-test) MODE="self-test" ;;
	-h | --help) usage 0 ;;
	-*) usage 1 ;;
	*)
		if [ -n "$ROOT" ]; then
			echo "unexpected argument: $1" >&2
			usage 1
		fi
		ROOT="$1"
		;;
	esac
	shift
done
ROOT="${ROOT:-$DEFAULT_ROOT}"

# ---------------------------------------------------------------------------
# Check conventions
# ---------------------------------------------------------------------------
# check_<name> <root>: every failure path must END the function with a
# non-zero status — use `fail "msg"` (or `return 1`) as the final statement of
# the branch. A trailing bare `return 0` after an `||`-style failure would
# swallow the failure; --self-test exists to prove no check regresses to that.
#
# mutate_<name> <scratch-root>: injects the exact violation the check exists
# to catch. Any check without a mutation runs but is not adversarially proven.

CHECKS=()

reg() { CHECKS+=("$1"); }

fail() {
	echo "   violation: $1" >&2
	return 1
}

require_file() {
	[ -f "$1" ] || fail "missing $1"
}

# ── AI-agent permission posture ─────────────────────────────────────────────
# Prompt injection in any file an agent reads is the #1 code-execution vector
# in this repo's threat model; these checks pin the approval posture.

reg agent_claude_bypass
check_agent_claude_bypass() {
	local f="$1/Configs/agents/.claude/settings.json"
	require_file "$f" || return 1
	if grep -Eq '"defaultMode": *"bypassPermissions"' "$f"; then
		fail "Claude Code defaultMode is bypassPermissions"
	elif grep -q 'skipDangerousModePermissionPrompt' "$f"; then
		fail "skipDangerousModePermissionPrompt present (suppresses the dangerous-mode dialog)"
	elif ! grep -Eq '"defaultMode": *"(acceptEdits|default|plan|dontAsk)"' "$f"; then
		fail "permissions.defaultMode missing or not an approval-gated mode"
	else
		return 0
	fi
}
mutate_agent_claude_bypass() {
	sed -i.bak 's/"defaultMode": "acceptEdits"/"defaultMode": "bypassPermissions"/' \
		"$1/Configs/agents/.claude/settings.json"
}

reg agent_opencode_allow_all
check_agent_opencode_allow_all() {
	local f found=0
	for f in "$1"/Configs/agents/.config/opencode/opencode.json \
		"$1"/Configs/agents/.config/opencode-v2/opencode.json; do
		require_file "$f" || return 1
		# v1 object form: "*": "allow" ; v2 array form: wildcard action and
		# resource with "effect": "allow".
		if grep -Eq '^\s*"\*": *"allow"' "$f"; then
			echo "   violation: wildcard allow-all in $f" >&2
			found=1
		fi
		if grep -Eq '"(action|resource)": *"\*"' "$f" && grep -q '"effect": *"allow"' "$f"; then
			echo "   violation: wildcard allow-all rule in $f" >&2
			found=1
		fi
	done
	[ "$found" -eq 0 ]
}
mutate_agent_opencode_allow_all() {
	cat >"$1/Configs/agents/.config/opencode/opencode.json" <<'EOF'
{
	"permission": {
		"*": "allow",
		"external_directory": { "*": "allow" }
	}
}
EOF
}

reg agent_zed_unsandboxed
check_agent_zed_unsandboxed() {
	local f="$1/Configs/zed/.config/zed/settings.json"
	require_file "$f" || return 1
	if grep -Eq '"allow_unsandboxed": *true' "$f"; then
		fail "Zed agent allows unsandboxed execution"
	elif grep -Eq '"allow_fs_write_all": *true' "$f"; then
		fail "Zed agent allows filesystem writes everywhere"
	elif grep -Eq '"trust_all_worktrees": *true' "$f"; then
		fail "Zed trusts every worktree without prompting"
	elif grep -B1 -A3 '"terminal": *{' "$f" | grep -q '"default": *"allow"'; then
		fail "Zed terminal tool is auto-allowed"
	else
		return 0
	fi
}
mutate_agent_zed_unsandboxed() {
	sed -i.bak 's/"allow_unsandboxed": false/"allow_unsandboxed": true/' \
		"$1/Configs/zed/.config/zed/settings.json"
}

reg codex_bypass_flag
check_codex_bypass_flag() {
	local hits
	# The exact flag, in any config, alias, wrapper, hook, or doc that agents
	# or users execute. Prose that merely names the flag is also a discovery
	# surface for agents, so it is not allowlisted.
	hits="$(grep -rn -F -- '--dangerously-bypass-approvals-and-sandbox' \
		"$1/Configs" "$1/Hooks" "$1/cli" "$1/setup" "$1/lib" 2>/dev/null || true)"
	if [ -n "$hits" ]; then
		printf '%s\n' "$hits" | while IFS= read -r hit; do echo "   $hit" >&2; done
		fail "codex sandbox-bypass flag present (alias/wrapper/doc)"
	else
		return 0
	fi
}
mutate_codex_bypass_flag() {
	printf '\nalias co=%s\n' "'codex --dangerously-bypass-approvals-and-sandbox'" \
		>>"$1/Configs/zsh/.zshrc"
}

reg api_key_not_ambient
check_api_key_not_ambient() {
	local f="$1/Configs/agents/.config/agents/agents.env.sh"
	require_file "$f" || return 1
	if grep -Eq '^[[:space:]]*export ZHIPU_API_KEY=' "$f"; then
		fail "ZHIPU_API_KEY is exported into every interactive shell (ambient credential)"
	else
		return 0
	fi
}
mutate_api_key_not_ambient() {
	cat >>"$1/Configs/agents/.config/agents/agents.env.sh" <<'EOF'
	if [ -n "${ZHIPU_API_KEY_X:-}" ]; then
		export ZHIPU_API_KEY="$ZHIPU_API_KEY_X"
	fi
EOF
}

# ── macOS system posture (darwin.nix / tcc.nix) ─────────────────────────────

reg firewall_enabled
check_firewall_enabled() {
	local f="$1/Configs/nix/.config/nix/darwin.nix"
	require_file "$f" || return 1
	if ! grep -A6 'networking.applicationFirewall = {' "$f" | grep -q 'enable = true;'; then
		fail "application firewall is not enabled"
	elif ! grep -A8 'networking.applicationFirewall = {' "$f" | grep -q 'enableStealthMode = true;'; then
		fail "firewall stealth mode is not enabled"
	else
		return 0
	fi
}
mutate_firewall_enabled() {
	sed -i.bak '/networking.applicationFirewall = {/,/};/ s/enable = true;/enable = false;/' \
		"$1/Configs/nix/.config/nix/darwin.nix"
}

reg tailscale_allowlisted
check_tailscale_allowlisted() {
	local f="$1/Configs/nix/.config/nix/darwin.nix"
	require_file "$f" || return 1
	# The firewall must stay paired with an explicit tailscaled allowlist:
	# nix-built binaries are unsigned, so signed-software allowances never
	# cover tailscaled and inbound tailnet traffic would be dropped.
	if grep -q 'socketfilterfw --add' "$f"; then
		return 0
	fi
	fail "tailscaled is not allowlisted through the application firewall (Tailscale breaks)"
}
mutate_tailscale_allowlisted() {
	sed -i.bak '/socketfilterfw --add/d' "$1/Configs/nix/.config/nix/darwin.nix"
}

reg sudo_secure_path
check_sudo_secure_path() {
	local f="$1/Configs/nix/.config/nix/darwin.nix"
	require_file "$f" || return 1
	if grep -q 'Defaults secure_path=' "$f"; then
		return 0
	fi
	fail "sudo has no secure_path (user-PATH shims can execute as root)"
}
mutate_sudo_secure_path() {
	sed -i.bak '/Defaults secure_path=/d' "$1/Configs/nix/.config/nix/darwin.nix"
}

reg ssh_hardened
check_ssh_hardened() {
	local f="$1/Configs/nix/.config/nix/darwin.nix"
	require_file "$f" || return 1
	if ! grep -q 'PasswordAuthentication no' "$f"; then
		fail "sshd does not disable password authentication"
	elif ! grep -q 'PermitRootLogin no' "$f"; then
		fail "sshd does not disable root login"
	else
		return 0
	fi
}
mutate_ssh_hardened() {
	sed -i.bak 's/PasswordAuthentication no/PasswordAuthentication yes/' \
		"$1/Configs/nix/.config/nix/darwin.nix"
}

reg tcc_no_terminal_av
check_tcc_no_terminal_av() {
	# Terminals spawn every process below them; camera/microphone granted to a
	# terminal are effectively granted to everything run from it. The terminal
	# block may keep its other grants, but not AV devices.
	local f="$1/Configs/nix/.config/nix/tcc.nix"
	require_file "$f" || return 1
	if grep -A16 '"com.mitchellh.ghostty"' "$f" | grep -Eq '^[[:space:]]*"(camera|microphone)"'; then
		fail "terminal TCC grant includes camera/microphone"
	else
		return 0
	fi
}
mutate_tcc_no_terminal_av() {
	sed -i.bak 's/^[[:space:]]*# "camera"$/          "camera"/' \
		"$1/Configs/nix/.config/nix/tcc.nix"
}

reg risky_packages_absent
check_risky_packages_absent() {
	local f="$1/Configs/nix/.config/nix/home.nix" pkg
	require_file "$f" || return 1
	for pkg in sshpass cloudflared vncdo; do
		if grep -Eq "^[[:space:]]*${pkg}$" "$f"; then
			fail "$pkg is installed (attack-enabler; removed by the 2026-10 audit)"
			return 1
		fi
	done
	return 0
}
mutate_risky_packages_absent() {
	sed -i.bak 's/^\([[:space:]]*\)bottom$/\1bottom\n\1sshpass/' \
		"$1/Configs/nix/.config/nix/home.nix"
}

reg risky_casks_absent
check_risky_casks_absent() {
	local f="$1/Configs/nix/.config/nix/darwin.nix" cask
	require_file "$f" || return 1
	# charles = HTTPS-MITM proxy CA; qbittorrent = torrent client;
	# nordvpn = conflicts with Tailscale; obs = unused screen/AV capture.
	for cask in charles qbittorrent nordvpn obs; do
		if grep -q "\"${cask}\"" "$f"; then
			fail "cask '$cask' is installed (high-risk, unused at audit time)"
			return 1
		fi
	done
	return 0
}
mutate_risky_casks_absent() {
	sed -i.bak 's/"alt-tab"/"alt-tab"\n        "charles"/' \
		"$1/Configs/nix/.config/nix/darwin.nix"
}

# ── Installer / bootstrap integrity ─────────────────────────────────────────

reg installer_pinned
check_installer_pinned() {
	local f="$1/setup"
	require_file "$f" || return 1
	if grep -q 'install.determinate.systems/nix | sh' "$f"; then
		fail "unpinned curl|sh of the Determinate installer"
		return 1
	fi
	if ! grep -Eq 'NIX_INSTALLER_URL:-https://github.com/DeterminateSystems/nix-installer/releases/download/' "$f"; then
		fail "installer URL is not pinned to a GitHub release asset"
		return 1
	fi
	# shellcheck disable=SC2016  # matching the literal shell text in setup
	if ! grep -q 'installer_actual_sha" != "$nix_installer_sha256' "$f"; then
		fail "installer checksum verification missing"
		return 1
	fi
	return 0
}
mutate_installer_pinned() {
	sed -i.bak 's#local nix_installer_url=.*#local nix_installer_url="https://install.determinate.systems/nix"#' \
		"$1/setup"
}

reg no_mktemp_u
check_no_mktemp_u() {
	local hits
	# mktemp -u prints a name without reserving it: a predictable path in a
	# world-writable directory, prime for symlink races before curl -o.
	hits="$(grep -rn 'mktemp -u' "$1/setup" "$1/lib" "$1/Hooks" \
		"$1/Configs/scripts" 2>/dev/null | grep -v security-audit.sh || true)"
	if [ -n "$hits" ]; then
		printf '%s\n' "$hits" | while IFS= read -r hit; do echo "   $hit" >&2; done
		fail "mktemp -u used (unreserved temp name)"
	else
		return 0
	fi
}
mutate_no_mktemp_u() {
	# shellcheck disable=SC2016  # writing a literal $(...) into the mutated file
	sed -i.bak 's#tmp_dir="$(mktemp -d)"#tmp_dir="$(dirname "$(mktemp -u)")/x"#' \
		"$1/Configs/scripts/.local/bin/setup:runner"
}

reg runner_checksum_verified
check_runner_checksum_verified() {
	local f="$1/Configs/scripts/.local/bin/setup:runner"
	require_file "$f" || return 1
	if ! grep -q 'checksum mismatch' "$f"; then
		fail "actions/runner download is not checksum-verified"
	elif ! grep -q 'mktemp -d' "$f"; then
		fail "runner download does not use a reserved temp directory"
	else
		return 0
	fi
}
mutate_runner_checksum_verified() {
	sed -i.bak '/actual_sha=/d; /checksum mismatch/d' \
		"$1/Configs/scripts/.local/bin/setup:runner"
}

reg clone_ref_visible
check_clone_ref_visible() {
	local f="$1/setup"
	require_file "$f" || return 1
	if ! grep -q 'DOTFILES_REF' "$f"; then
		fail "clone path does not support pinning via DOTFILES_REF"
	elif ! grep -q 'Cloned revision' "$f"; then
		fail "cloned commit is not displayed before cloned code runs"
	else
		return 0
	fi
}
mutate_clone_ref_visible() {
	sed -i.bak '/DOTFILES_REF/d; /Cloned revision/d' "$1/setup"
}

# ── Privilege escalation guards ─────────────────────────────────────────────

reg sudoers_visudo_validated
check_sudoers_visudo_validated() {
	local f="$1/Hooks/nix/post.sh"
	require_file "$f" || return 1
	# shellcheck disable=SC2016  # matching the literal shell text in the hook
	if grep -q 'tee -a "\$sudoers_extra"' "$f"; then
		fail "sudoers fragment written without visudo validation"
	elif ! grep -q 'visudo -cf' "$f"; then
		fail "sudoers fragment not validated with visudo"
	else
		return 0
	fi
}
mutate_sudoers_visudo_validated() {
	python3 - "$1/Hooks/nix/post.sh" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path).read()
old = 'sudo install -m 0440 -o root -g root "$sudoers_tmp" "$sudoers_extra"'
new = 'cat "$sudoers_tmp" | sudo tee -a "$sudoers_extra" >/dev/null'
assert old in text, "mutation target line not found"
open(path, "w").write(text.replace(old, new))
PYEOF
}

reg machine_nix_input_validated
check_machine_nix_input_validated() {
	# CFG_USERNAME/CFG_SYSTEM are parsed from user-writable machine.nix and
	# interpolated into command strings that run under sudo on Linux.
	local f="$1/Hooks/nix/post.sh"
	require_file "$f" || return 1
	if ! grep -q 'a-z0-9_-\]{0,31}' "$f"; then
		fail "machine.nix username is not validated before shell interpolation"
	elif ! grep -Eq '\(aarch64\|x86_64\)-\(darwin\|linux\)' "$f"; then
		fail "machine.nix system is not validated before shell interpolation"
	else
		return 0
	fi
}
mutate_machine_nix_input_validated() {
	sed -i.bak '/a-z0-9_-\]{0,31}/d' "$1/Hooks/nix/post.sh"
	sed -i.bak '/(aarch64|x86_64)-(darwin|linux)/d' "$1/Hooks/nix/post.sh"
}

reg token_files_restricted
check_token_files_restricted() {
	# nix.conf receives a live GitHub token during setup; both writers must
	# keep it out of group/world-readable modes.
	if ! grep -q 'umask 177' "$1/Hooks/nix/post.sh"; then
		echo "   Hooks/nix/post.sh writes nix.conf without umask 177" >&2
		return 1
	fi
	if ! grep -q 'umask 177' "$1/setup"; then
		echo "   setup writes nix.conf without umask 177" >&2
		return 1
	fi
	# The umask must be scoped to a subshell: a { } brace group runs in the
	# current shell, and a leaked umask 177 makes later mkdir -p intermediates
	# mode 600 (no execute) — home-manager activation then dies with EACCES
	# (caught live in CI on 2026-10-22).
	local f
	for f in "$1/Hooks/nix/post.sh" "$1/setup"; do
		if grep -Eq '\{[[:space:]]*umask' "$f"; then
			echo "   $f uses a brace-group umask (leaks into the script)" >&2
			return 1
		fi
	done
	return 0
}
mutate_token_files_restricted() {
	sed -i.bak 's/( umask 177; echo "access-tokens/{ umask 177; echo "access-tokens/' \
		"$1/Hooks/nix/post.sh" "$1/setup"
	sed -i.bak 's/nix.conf" )/nix.conf"; }/' "$1/Hooks/nix/post.sh" "$1/setup"
}

reg authkey_not_in_argv
check_authkey_not_in_argv() {
	local f="$1/Hooks/nix/post.sh"
	require_file "$f" || return 1
	# shellcheck disable=SC2016  # matching the literal shell text in the hook
	if grep -q -- '--authkey "\$TAILSCALE_AUTHKEY"' "$f"; then
		fail "Tailscale authkey passed as argv (visible in ps to all local users)"
	else
		return 0
	fi
}
mutate_authkey_not_in_argv() {
	# shellcheck disable=SC2016  # writing literal shell text into the mutated file
	sed -i.bak 's/sudo env TAILSCALE_AUTHKEY="\$TAILSCALE_AUTHKEY" "\$TS_BIN" up --ssh/sudo "$TS_BIN" up --authkey "$TAILSCALE_AUTHKEY" --ssh/' \
		"$1/Hooks/nix/post.sh"
}

reg uninstall_marker_guard
check_uninstall_marker_guard() {
	local f="$1/Configs/scripts/.local/bin/uninstall:dotfiles"
	require_file "$f" || return 1
	if grep -q 'does not look like the dotfiles repository' "$f"; then
		return 0
	fi
	fail "uninstall rm -rf is not guarded by repo-marker validation"
}
mutate_uninstall_marker_guard() {
	sed -i.bak '/does not look like the dotfiles repository/d; /missing setup, Configs/d' \
		"$1/Configs/scripts/.local/bin/uninstall:dotfiles"
}

# ── CI / repo hygiene ───────────────────────────────────────────────────────

reg actions_sha_pinned
check_actions_sha_pinned() {
	local f line bad=0
	for f in "$1"/.github/workflows/*.yml; do
		[ -f "$f" ] || continue
		while IFS= read -r line; do
			# GitHub actions pin as @<40-char commit sha> (not @sha256:...).
			if ! grep -Eq '@[0-9a-f]{40}( |$|#)' <<<"$line"; then
				echo "   $f: $line" >&2
				bad=1
			fi
		done < <(grep -E '^[[:space:]]*-?[[:space:]]*uses:' "$f" || true)
	done
	[ "$bad" -eq 0 ]
}
mutate_actions_sha_pinned() {
	local f
	f="$(find "$1/.github/workflows" -name '*.yml' | head -1)"
	sed -i.bak 's/@[0-9a-f]\{40\}/@v9/' "$f"
}

reg no_pull_request_target
check_no_pull_request_target() {
	if grep -rn 'pull_request_target' "$1/.github/workflows" >/dev/null 2>&1; then
		fail "pull_request_target can run fork code with secrets"
	else
		return 0
	fi
}
mutate_no_pull_request_target() {
	local f
	f="$(find "$1/.github/workflows" -name '*.yml' | head -1)"
	sed -i.bak 's/^on:$/on:\n  pull_request_target:\n    branches: [main]\n/' "$f"
}

reg ci_permissions_least_privilege
check_ci_permissions_least_privilege() {
	local f
	for f in "$1"/.github/workflows/*.yml; do
		[ -f "$f" ] || continue
		if grep -Eq 'contents: *write-all' "$f"; then
			fail "$f grants contents: write-all"
			return 1
		fi
		if ! grep -q 'permissions:' "$f"; then
			fail "$f has no permissions block"
			return 1
		fi
	done
	return 0
}
mutate_ci_permissions_least_privilege() {
	local f
	f="$(find "$1/.github/workflows" -name '*.yml' | head -1)"
	sed -i.bak 's/contents: read/contents: write-all/' "$f"
}

reg gitleaks_allowlist_not_tracked
check_gitleaks_allowlist_not_tracked() {
	# .gitleaks.toml allowlists nix.conf (it holds a live token and is
	# gitignored). If the path ever becomes tracked, the allowlist silences
	# every scan for a real secret.
	if git -C "$1" ls-files --error-unmatch \
		"Configs/nix/.config/nix/nix.conf" >/dev/null 2>&1; then
		fail "Configs/nix/.config/nix/nix.conf is tracked but allowlisted in .gitleaks.toml"
		return 1
	fi
	if grep -q 'nix.conf is tracked' "$1/.githooks/pre-push"; then
		return 0
	fi
	fail "pre-push hook lacks the tracked-nix.conf guard"
}
mutate_gitleaks_allowlist_not_tracked() {
	echo "access-tokens = github.com=ghp_fakeTokenForSelfTest1234567890" \
		>"$1/Configs/nix/.config/nix/nix.conf"
	git -C "$1" add -f "Configs/nix/.config/nix/nix.conf"
}

reg docker_base_pinned
check_docker_base_pinned() {
	local f="$1/Dockerfile"
	require_file "$f" || return 1
	if grep -Eq '^FROM [^ ]+@sha256:[0-9a-f]{64}' "$f"; then
		return 0
	fi
	fail "Dockerfile base image is not digest-pinned"
}
mutate_docker_base_pinned() {
	sed -i.bak 's/@sha256:[0-9a-f]\{64\}//' "$1/Dockerfile"
}

reg secrets_scan
check_secrets_scan() {
	# Optional: needs gitleaks. CI installs it; locally it comes with the
	# dotfiles package set.
	if ! command -v gitleaks >/dev/null 2>&1; then
		echo "   (skipped: gitleaks not installed)"
		return 0
	fi
	if (cd "$1" && gitleaks dir --redact --no-banner . >/dev/null 2>&1); then
		return 0
	fi
	fail "gitleaks found potential secrets (run: gitleaks dir --redact .)"
}
mutate_secrets_scan() {
	if command -v gitleaks >/dev/null 2>&1; then
		# The Slack-bot token shape is detected by gitleaks' default rules in
		# every version tested (8.24-8.30); several other common shapes are
		# filtered by entropy thresholds or stopwords. Assembled from parts so
		# the checker file itself contains no literal token for gitleaks to
		# flag in the baseline scan.
		local tok
		tok="xoxb-123456789012""-1234567890123-""abcdefghijklmnopqrstuvwx"
		printf 'slack_token = %s\n' "$tok" \
			>"$1/Configs/fake-secret-for-self-test.txt"
	fi
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

run_check() {
	local name="$1" root="$2"
	"check_$name" "$root" >/dev/null 2>&1
}

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BOLD=$'\033[1m'
NC=$'\033[0m'

audit() {
	local root="$1" name out failed=0 passed=0
	echo "${BOLD}Security audit — $root${NC}"
	for name in "${CHECKS[@]}"; do
		if out=$("check_$name" "$root" 2>&1); then
			echo "  ${GREEN}✓${NC} $name"
			passed=$((passed + 1))
		else
			echo "  ${RED}✗${NC} $name"
			printf '%s\n' "$out" | sed 's/^/     /'
			failed=$((failed + 1))
		fi
	done
	echo ""
	if [ "$failed" -eq 0 ]; then
		echo "${GREEN}All $passed checks passed.${NC}"
		return 0
	fi
	echo "${RED}${failed} check(s) failed, $passed passed.${NC}"
	echo "Each failed check names the violation above; see tests/security-audit.sh header for context."
	return 1
}

self_test() {
	local tmp name total=0 caught=0 unproven=0 ineffective=0
	tmp="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-sec-selftest.XXXXXX")"
	echo "${BOLD}Adversarial self-test: injecting each violation into a scratch copy${NC}"

	for name in "${CHECKS[@]}"; do
		total=$((total + 1))
		# Fresh copy per mutation so mutations cannot mask each other.
		rm -rf "$tmp/copy"
		mkdir -p "$tmp/copy"
		# Exclude .git: the copy gets its own throwaway git repo below
		# (gitleaks_allowlist_not_tracked needs a real index).
		if command -v rsync >/dev/null 2>&1; then
			rsync -a --exclude=.git --exclude=.cache "$ROOT/" "$tmp/copy/" 2>/dev/null
		else
			(cd "$ROOT" && tar -cf - --exclude=.git --exclude=.cache .) |
				(cd "$tmp/copy" && tar -xf -)
		fi
		(cd "$tmp/copy" && git init -q && git add -A >/dev/null 2>&1)

		if ! run_check "$name" "$tmp/copy"; then
			echo "  ${RED}✗${NC} $name: baseline already failing (fix the repo before trusting this suite)"
			ineffective=$((ineffective + 1))
			continue
		fi
		if ! declare -f "mutate_$name" >/dev/null; then
			unproven=$((unproven + 1))
			echo "  ${YELLOW}~${NC} $name: no mutation defined (check runs but is not adversarially proven)"
			continue
		fi
		"mutate_$name" "$tmp/copy"
		if run_check "$name" "$tmp/copy"; then
			echo "  ${RED}✗${NC} $name: mutation NOT caught — check is ineffective"
			ineffective=$((ineffective + 1))
		else
			caught=$((caught + 1))
			echo "  ${GREEN}✓${NC} $name: mutation caught"
		fi
	done

	rm -rf "$tmp"
	echo ""
	echo "Self-test: $caught mutations caught, $ineffective ineffective, $unproven without mutation (total $total)."
	if [ "$ineffective" -gt 0 ]; then
		echo "${RED}Some checks failed their adversarial test; fix the check, not the count.${NC}"
		return 1
	fi
	echo "${GREEN}Every defined mutation was detected.${NC}"
	return 0
}

case "$MODE" in
list)
	printf '%s\n' "${CHECKS[@]}"
	;;
audit)
	audit "$ROOT"
	;;
self-test)
	self_test
	;;
esac
