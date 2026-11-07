# =========================
# Stage 1: Build Angular App
# =========================
# Angular 22 requires Node ^22.22.3 || ^24.15.0, so node:20 is no longer supported.
FROM node:24-alpine AS build

WORKDIR /src

# Copy dependency descriptors first (better cache)
COPY package*.json ./
COPY angular.json ./
COPY tsconfig*.json ./

# Install dependencies using BuildKit cache
RUN --mount=type=cache,id=npm-cache,target=/root/.npm \
    npm ci

# Copy full source and build
COPY . .
RUN npx ng build --configuration production


# =========================
# Stage 2: NGINX Base Image
# =========================
FROM nginx:alpine AS base

# Install required packages & timezone
RUN apk add --no-cache ca-certificates tzdata && \
    ln -snf /usr/share/zoneinfo/Asia/Dhaka /etc/localtime && \
    echo "Asia/Dhaka" > /etc/timezone

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf


# =========================
# Stage 3: Final Runtime
# =========================
FROM base AS final

# Create required directories & permissions (Kubernetes-safe)
RUN mkdir -p \
      /var/cache/nginx \
      /var/cache/nginx/client_temp \
      /var/cache/nginx/proxy_temp \
      /var/cache/nginx/fastcgi_temp \
      /var/cache/nginx/uwsgi_temp \
      /var/cache/nginx/scgi_temp \
      /var/log/nginx \
      /tmp \
      /usr/share/nginx/html && \
    chown -R 102:102 \
      /var/cache/nginx \
      /var/log/nginx \
      /tmp \
      /usr/share/nginx

# Copy Angular build output (application builder emits to dist/<project>/browser)
COPY --from=build /src/dist/handson-yousuf/browser/ /usr/share/nginx/html/handson-yousuf/

# FIX ownership so non-root nginx can read everything safely
RUN chown -R 102:102 /usr/share/nginx/html/handson-yousuf

# Remove default nginx index if exists
RUN rm -f /usr/share/nginx/html/index.html

# 8080 = app, 8081 = health/status
EXPOSE 8080 8081

# Run as non-root user (matches Kubernetes securityContext)
USER 102

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
