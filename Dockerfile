# syntax=docker/dockerfile:1.12

# Digest-pinned to the ubuntu:24.04 manifest list (multi-arch): a floating tag
# silently repoints whenever the publisher pushes. This image is test-only
# (ephemeral CI sandbox with a NOPASSWD test user); never reuse it as a base
# for anything long-lived.
FROM ubuntu:24.04@sha256:68ee22004a9109b44973313b02ff7b1de250f1de0f5ecb628d73f579aaff33ac

# Install minimal dependencies
RUN apt-get update && apt-get install -y curl xz-utils git sudo && rm -rf /var/lib/apt/lists/*

# Create non-root user with passwordless sudo (nix installer requirement)
RUN useradd -m -s /bin/bash testuser && echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to testuser for the rest
USER testuser
# Copy dotfiles into container
COPY --chown=testuser:testuser . /home/testuser/.dotfiles
WORKDIR /home/testuser/.dotfiles

RUN --mount=type=secret,id=github_token,required=false \
    GITHUB_TOKEN="$(cat /run/secrets/github_token 2>/dev/null || true)" \
    SETUP_ALLOW_NIX_HOOK_FAILURE=true \
    ./setup --no-confirm --lite

# Run initial setup verification, then the uninstall/reset cycle test.
CMD ["bash", "-lc", "set -e; echo '=== Phase 1: Integration verification ==='; tests/docker-integration-test.sh; echo ''; echo '=== Phase 2: Setup/Uninstall/Reset Cycle ==='; tests/setup-uninstall-reset-test.sh"]
