FROM mcr.microsoft.com/devcontainers/javascript-node:18

# Install additional system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    jq \
    tree \
    htop \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI
RUN curl -fsSL https://claude.ai/install.sh | bash

# Create .claude-dev directory for testing (isolated from host)
RUN mkdir -p /home/vscode/.claude-dev

# Add Claude to PATH for all users
RUN echo 'export PATH="/home/vscode/.local/bin:$PATH"' >> /home/vscode/.bashrc
RUN echo 'export PATH="/home/vscode/.local/bin:$PATH"' >> /home/vscode/.zshrc

# Create some helpful aliases
RUN echo 'alias claude-test="cd /workspaces/claude-auto-tee && npm test"' >> /home/vscode/.bashrc
RUN echo 'alias claude-demo="cd /workspaces/claude-auto-tee && npm run demo"' >> /home/vscode/.bashrc
RUN echo 'alias claude-test="cd /workspaces/claude-auto-tee && npm test"' >> /home/vscode/.zshrc  
RUN echo 'alias claude-demo="cd /workspaces/claude-auto-tee && npm run demo"' >> /home/vscode/.zshrc

# Switch to vscode user
USER vscode

# Set working directory
WORKDIR /workspaces/claude-auto-tee