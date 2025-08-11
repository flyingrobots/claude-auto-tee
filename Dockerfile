FROM node:18-alpine

# Install bash and other utilities
RUN apk add --no-cache bash curl git

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Make scripts executable
RUN chmod +x src/hook.js install.js test/test.js

# Create a test user (non-root for safety)
RUN addgroup -g 1001 -S testuser && \
    adduser -S testuser -u 1001 -G testuser

# Switch to test user
USER testuser

# Create fake .claude directories for testing
RUN mkdir -p /home/testuser/.claude
RUN mkdir -p /app/.claude

CMD ["npm", "test"]