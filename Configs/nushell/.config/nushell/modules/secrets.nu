# secrets.nu - Load environment variables from ~/.env.dotfiles
#
# Parses KEY=VALUE lines from the secrets file and loads them into the
# environment. Handles quoted values, comments, and blank lines.
export def --env load [] {
    let secrets_file = $"($env.HOME)/.env.dotfiles"
    if not ($secrets_file | path exists) { return }
    let env_vars = (
        open $secrets_file | lines | where { |line|
			let trimmed = ($line | str trim)
			($trimmed | is-not-empty) and (not ($trimmed | str starts-with "#"))
		} | each { |line|
			let eq_pos = ($line | str index-of "=")
			if ($eq_pos == -1) { return null }
			let key = ($line | str substring 0..<$eq_pos | str trim)
			let value = ($line
				| str substring ($eq_pos + 1)..
				| str trim
				| str replace -r '^"(.*)"$' '$1'
				| str replace -r "^'(.*)'$" '$1')
			{ $key: $value }
		} | where { $in != null } | reduce --fold {} { |it, acc| $acc | merge $it }
    )
    if ($env_vars | is-not-empty) {
        $env_vars | load-env
    }
}
