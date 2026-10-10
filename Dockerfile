# Runs the WorkFlow Companion MCP server over stdio. Used by MCP directories
# (Glama) to build and health-check the server: it starts and lists its tools
# without signing in. To use it for real, install from npm and run setup:
#   npx -y @opticell/workflow-companion setup
FROM node:20-alpine
WORKDIR /app
COPY src/index.js ./index.js
ENV WF_MODE=cloud
ENTRYPOINT ["node", "index.js"]
