# syntax=docker/dockerfile:1.7

# 构建阶段：使用 Debian 确保 better-sqlite3 编译成功
FROM node:20-slim AS builder
WORKDIR /app

# 安装编译工具（Debian 版本）
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    gcc \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 复制所有文件
COPY . .

# 安装依赖（使用 npm，避免 pnpm 问题）
RUN npm install --prefer-offline --no-audit --no-fund

# 验证 better-sqlite3 编译结果
RUN echo "🔍 检查 better-sqlite3 编译文件..." && \
    ls -la node_modules/better-sqlite3/build/Release/ 2>/dev/null && \
    echo "✅ better-sqlite3 编译成功" || \
    (echo "❌ better-sqlite3 编译失败" && exit 1)

# 构建应用
RUN NITRO_PRESET=node-server npm run build

# 运行阶段：最小化 Debian 镜像
FROM node:20-slim AS runner
WORKDIR /app

# 设置环境变量
ENV NODE_ENV=production
ENV PORT=3000
ENV HOST=0.0.0.0
ENV NITRO_LOG_LEVEL=info

EXPOSE 3000

# 运行时依赖（better-sqlite3 需要）
RUN apt-get update && apt-get install -y \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# 从构建阶段复制所有必要文件
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/.output ./.output
COPY --from=builder /app/package.json ./

# 创建 data 目录并设置权限（用于 SQLite 持久化）
RUN mkdir -p /app/data && chmod 777 /app/data

# 最终验证 better-sqlite3 是否可用
RUN echo "🔍 最终验证 better-sqlite3..." && \
    node -e "try { require('better-sqlite3'); console.log('✅ better-sqlite3 可用'); } catch(e) { console.log('❌', e.message); process.exit(1); }"

CMD ["node", "--enable-source-maps", ".output/server/index.mjs"]
