# ─────────────────────────────────────────────
#  Multi-stage build for jenkins-devops
# ─────────────────────────────────────────────

# Stage 1: Install dependencies
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Stage 2: Production image
FROM node:22-alpine AS production

# Add labels for image metadata
LABEL maintainer="chandu7313"
LABEL description="Jenkins DevOps Node.js Express Application"
LABEL version="1.0.0"

# Create a non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy only production dependencies from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy application code
COPY . .

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose application port
EXPOSE 3000

# Health check to verify the container is running correctly
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

# Start the application
CMD ["node", "index.js"]
