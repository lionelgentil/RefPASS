FROM node:18-alpine

WORKDIR /app

# Install dependencies directly without package-lock.json issues
RUN npm install express@4.18.2 cors@2.8.5

# Copy application code
COPY . .

# Create data directory
RUN mkdir -p data

# Expose port
EXPOSE $PORT

# Start the application
CMD ["node", "server.js"]