# ITRAN AGRI — Next.js 16 standalone
FROM node:22-alpine AS base
RUN corepack enable && apk add --no-cache postgresql17-client
WORKDIR /app
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN pnpm build
FROM node:22-alpine AS run
# su-exec: khởi động container bằng root CHỈ để chỉnh quyền 2 volume bind-mount (/backups,
# /uploads — do host tạo, mặc định thuộc root), sau đó hạ quyền hẳn xuống "node" trước khi
# chạy app (docker-entrypoint.sh). App KHÔNG BAO GIỜ chạy với quyền root.
RUN apk add --no-cache postgresql17-client tzdata su-exec && corepack enable
ENV NODE_ENV=production TZ=Asia/Ho_Chi_Minh PORT=3000 SCHEDULER=1
WORKDIR /app
COPY --from=base --chown=node:node /app/.next/standalone ./
COPY --from=base --chown=node:node /app/.next/static ./.next/static
COPY --from=base --chown=node:node /app/public ./public
COPY --from=base --chown=node:node /app/supabase ./supabase
COPY --from=base --chown=node:node /app/scripts ./scripts
COPY --from=base --chown=node:node /app/node_modules/tsx ./node_modules/tsx
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
EXPOSE 3000
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["node", "server.js"]
