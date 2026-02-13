# print_utils.nu - Shared print utilities for dotfiles scripts
#
# Provides consistent colored output across all scripts.
# Usage: use nu_modules/print_utils.nu *
# Print info message with blue arrow prefix
export def info [message: string] { print $"(ansi blue)==>(ansi reset) ($message)" }
# Print success message with green checkmark prefix
export def success [message: string] { print $"(ansi green)✓(ansi reset) ($message)" }
# Print error message with red x prefix
export def err [message: string] { print $"(ansi red)✗(ansi reset) ($message)" }
# Print warning message with yellow ! prefix
export def warn [message: string] { print $"(ansi yellow)!(ansi reset) ($message)" }
# Print header message with bold cyan styling
export def header [message: string] { print $"(ansi cyan_bold)==>(ansi reset) (ansi attr_bold)($message)(ansi reset)" }
