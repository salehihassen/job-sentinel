# Job Sentinel — self-hosted web UI image (production Next.js server).
#
#   docker build -f deploy/web.Dockerfile -t job-sentinel-web .
#
# NEXT_PUBLIC_API_BASE is inlined at build time. The default (empty) makes the
# UI call /api/* on its own origin, so one image works behind any reverse proxy
# that routes /api, /health and /docs to the API container. Pass an absolute
# URL only if the API lives on a different origin.
FROM node:24-alpine AS build
WORKDIR /app
ARG NEXT_PUBLIC_API_BASE=""
ENV NEXT_TELEMETRY_DISABLED=1 \
    NEXT_PUBLIC_API_BASE=${NEXT_PUBLIC_API_BASE} \
    NEXT_PUBLIC_DEMO=0
COPY web/package.json web/package-lock.json ./
RUN npm ci
COPY web/ ./
RUN npm run build

FROM node:24-alpine
WORKDIR /app
ENV NODE_ENV=production NEXT_TELEMETRY_DISABLED=1
COPY --from=build --chown=node:node /app ./
USER node
EXPOSE 3000
CMD ["npm", "run", "start", "--", "--hostname", "0.0.0.0"]
