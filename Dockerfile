FROM ubuntu:24.04

# Install minimal dependencies
RUN apt-get update && apt-get install -y curl xz-utils git sudo && rm -rf /var/lib/apt/lists/*

# Create non-root user with passwordless sudo (nix installer requirement)
RUN useradd -m -s /bin/bash testuser && echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to testuser for the rest
USER testuser
# Copy dotfiles into container
COPY --chown=testuser:testuser . /home/testuser/.dotfiles
WORKDIR /home/testuser/.dotfiles

RUN ./setup --skip-nix --no-confirm

CMD ["bash", "-lc", "tests/docker-integration-test.sh"]
