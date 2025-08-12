FROM alpine:latest

# Install bash, node.js for testing, and other utilities
RUN apk add --no-cache bash nodejs npm curl git

# Create app directory
WORKDIR /app

# Copy source code (minimal - just the bash script and tests)
COPY . .

# Make the bash script executable
RUN chmod +x src/claude-auto-tee.sh

# Create a test user (non-root for safety)
RUN addgroup -g 1001 -S testuser && \
    adduser -S testuser -u 1001 -G testuser

# Switch to test user
USER testuser

# Create fake .claude directories for testing
RUN mkdir -p /home/testuser/.claude
RUN mkdir -p /app/.claude

# Run tests (note: uses Node.js for test framework, but production tool is pure bash)
CMD ["npm", "test"]