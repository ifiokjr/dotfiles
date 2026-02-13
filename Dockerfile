FROM ubuntu:24.04

# Install minimal dependencies
RUN apt-get update && apt-get install -y curl xz-utils git sudo && rm -rf /var/lib/apt/lists/*

# Create non-root user with passwordless sudo (nix installer requirement)
RUN useradd -m -s /bin/bash testuser && echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install Nix as testuser (cached in Docker layer)
USER testuser
RUN curl -fsSL https://install.determinate.systems/nix | sh -s -- install linux --no-confirm
ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"

# Pre-install nushell for the test scripts
RUN . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && nix profile install nixpkgs#nushell

# Copy dotfiles into container
COPY --chown=testuser:testuser . /home/testuser/.dotfiles
WORKDIR /home/testuser/.dotfiles

CMD ["bash", "-lc", "tests/docker-integration-test.sh"]
