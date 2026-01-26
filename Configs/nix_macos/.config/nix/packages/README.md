# Custom Nix Packages

This directory contains custom Nix derivations for packages that need special handling or aren't available in nixpkgs.

## Available Packages

### pnpm-standalone

Standalone version of pnpm that doesn't depend on Node.js, allowing you to use pnpm to manage Node versions.

**Features:**
- No Node.js dependency (unlike nixpkgs pnpm)
- Fetches directly from GitHub releases
- Supports macOS (arm64/x64) and Linux (arm64/x64)
- Self-contained binary

**Version:** 10.28.2 (released January 26, 2026)

**Usage:**
```nix
# In home.nix
let
  pnpm-standalone = pkgs.callPackage ./packages/pnpm-standalone.nix { };
in
{
  home.packages = [
    pnpm-standalone
    # ... other packages
  ];
}
```

**Updating:**
1. Edit `pnpm-standalone.nix` and change the `version` variable
2. Set the hash for your platform to `lib.fakeSha256`
3. Run `rebuild`
4. Nix will show an error with the correct hash
5. Copy the hash from the error and update `pnpm-standalone.nix`
6. Run `rebuild` again

Example error:
```
error: hash mismatch in fixed-output derivation '/nix/store/...':
  specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
  got:      sha256-3NKbhDlzXW0IUJL+Yoj0vKRfdmHCNYVP9Q4Q8OvGXV8=
```
Copy the "got" hash to the appropriate platform in the `hashes` attribute set.

## Adding New Custom Packages

1. Create a new `.nix` file in this directory
2. Follow the pattern from existing packages
3. Import it in `home.nix` using `pkgs.callPackage`
4. Add it to `home.packages`
5. Document it here in this README

## Why Custom Packages?

Custom packages are useful when:
- Package isn't in nixpkgs
- nixpkgs version has unwanted dependencies
- Need specific version or build configuration
- Want to track latest releases from GitHub
- Binary-only distribution without source builds
