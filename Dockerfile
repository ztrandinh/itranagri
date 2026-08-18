# ITRAN OS — Next.js 16 standalone
FROM node:22-alpine AS base
RUN corepack enable && apk add --no-cache postgresql17-client
WORKDIR /app
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN pnpm build
FROM node:22-alpine AS run
RUN apk add --no-cache postgresql17-client tzdata && corepack enable
ENV NODE_ENV=production TZ=Asia/Ho_Chi_Minh PORT=3000 SCHEDULER=1
WORKDIR /app
COPY --from=base /app/.next/standalone ./
COPY --from=base /app/.next/static ./.next/static
COPY --from=base /app/public ./public
COPY --from=base /app/supabase ./supabase
COPY --from=base /app/scripts ./scripts
COPY --from=base /app/node_modules/tsx ./node_modules/tsx
EXPOSE 3000
CMD ["node", "server.js"]
