# login.nu - Login shell initialization
#
# This file runs only when nushell is started with `nu --login`.
# Nushell is the default login shell (set via chsh). Nix environment
# bootstrap is handled in env.nu, which detects missing NIX_PROFILES
# and replicates nix-darwin's set-environment script natively.
#
# This file is intentionally minimal.
