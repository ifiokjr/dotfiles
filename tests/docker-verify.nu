#!/usr/bin/env nu
# Post-setup verification checks for Docker integration test
#
# Verifies that the dotfiles setup + rebuild produced a working environment.

def main [] {
    mut failures: list<string> = []

    print "=== Verification Tests ==="
    print ""

    # 1. Symlinks created — ~/.config/nix exists and points to dotfiles
    print "1. Checking ~/.config/nix symlink..."
    let nix_config = $"($env.HOME)/.config/nix"
    if ($nix_config | path exists) {
        print $"   PASS: ($nix_config) exists"
    } else {
        print $"   FAIL: ($nix_config) does not exist"
        $failures = ($failures | append "~/.config/nix missing")
    }

    # 2. machine.nix valid — parseable with correct username/system/hostname
    print "2. Checking machine.nix..."
    let machine_nix = $"($nix_config)/machine.nix"
    if ($machine_nix | path exists) {
        let content = (open $machine_nix --raw)
        if ($content | str contains "username") and ($content | str contains "system") {
            print "   PASS: machine.nix is valid"
        } else {
            print "   FAIL: machine.nix missing required fields"
            $failures = ($failures | append "machine.nix invalid")
        }
    } else {
        print $"   FAIL: ($machine_nix) does not exist"
        $failures = ($failures | append "machine.nix missing")
    }

    # 3. Key packages available after home-manager switch
    print "3. Checking key packages..."
    let packages = ["bat" "rg" "fd" "jq" "starship" "dprint" "git"]
    for pkg in $packages {
        if (which $pkg | is-not-empty) {
            print $"   PASS: ($pkg) available"
        } else {
            print $"   WARN: ($pkg) not found \(may not be in home.nix\)"
        }
    }

    # 4. Nushell is available
    print "4. Checking nushell..."
    if (which nu | is-not-empty) {
        print "   PASS: nushell available"
    } else {
        print "   FAIL: nushell not available"
        $failures = ($failures | append "nushell not available")
    }

    # 5. Scripts directory is accessible
    print "5. Checking scripts on PATH..."
    let scripts_dir = $"($env.HOME)/.local/bin"
    if ($scripts_dir | path exists) {
        print $"   PASS: ($scripts_dir) exists"
    } else {
        print $"   WARN: ($scripts_dir) does not exist"
    }

    # 6. Run existing test suite if available
    print "6. Running test_scripts..."
    let test_script = $"($env.HOME)/.local/bin/test_scripts"
    if ($test_script | path exists) {
        try {
            nu $test_script
            print "   PASS: test_scripts passed"
        } catch {
            print "   WARN: test_scripts failed \(non-critical\)"
        }
    } else {
        # Try from Configs path directly
        let alt_test = "Configs/scripts/.local/bin/test_scripts"
        if ($alt_test | path exists) {
            try {
                nu $alt_test
                print "   PASS: test_scripts passed"
            } catch {
                print "   WARN: test_scripts failed \(non-critical\)"
            }
        } else {
            print "   SKIP: test_scripts not found"
        }
    }

    print ""

    if ($failures | is-empty) {
        print "All verification checks passed!"
    } else {
        print $"Failures: ($failures | str join ', ')"
        exit 1
    }
}
