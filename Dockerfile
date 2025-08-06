FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Clear npm cache and install with specific flags
RUN npm cache clean --force && \
    npm config set registry https://registry.npmjs.org/ && \
    npm install --no-optional --no-audit --no-fund --legacy-peer-deps

# Copy application code
COPY . .

# Create data directory
RUN mkdir -p data

# Expose port
EXPOSE $PORT

# Start the application
CMD ["npm", "start"]