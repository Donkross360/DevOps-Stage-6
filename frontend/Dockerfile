# Multi-stage build for Vue.js
FROM node:14-alpine AS build
WORKDIR /app

# Install Python and build tools for node-sass native bindings
RUN apk add --no-cache python3 make g++ && \
    ln -sf python3 /usr/bin/python && \
    ln -sf python3 /usr/bin/python2

COPY package*.json ./
# Set PYTHON environment variables for node-gyp (old versions expect python2)
ENV PYTHON=/usr/bin/python3
ENV npm_config_python=/usr/bin/python3
# Try to use pre-built binaries instead of building from source
ENV npm_config_build_from_source=false
# Use npm install instead of npm ci to handle old lockfile issues
RUN npm install
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]