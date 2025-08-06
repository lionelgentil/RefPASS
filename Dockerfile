FROM node:18-alpine

WORKDIR /app

# Copy package files first
COPY package.json ./
COPY package-lock.json ./

# Debug: Show what we're working with
RUN echo "=== Package.json contents ===" && \
    cat package.json && \
    echo "=== Node and npm versions ===" && \
    node --version && \
    npm --version

# Install dependencies with error handling
RUN npm cache clean --force && \
    npm config set registry https://registry.npmjs.org/ && \
    npm install --production=false --verbose && \
    echo "=== Installed packages ===" && \
    npm list --depth=0 && \
    echo "=== Checking express specifically ===" && \
    ls -la node_modules/ | grep express || echo "Express not found!"

# Copy application code
COPY . .

# Create data directory
RUN mkdir -p data

# Expose port
EXPOSE $PORT

# Start the application
CMD ["npm", "start"]