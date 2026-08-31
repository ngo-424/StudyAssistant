# 时芽 API

服务端提供 `/v1` 下的邮箱验证码账号、增量同步和跨设备接续接口。验证码有效 10 分钟且只可使用一次；访问令牌有效 15 分钟；刷新令牌有效 30 天并在每次刷新时轮换。数据库中的 `password_hash` 允许为空，为后续密码登录保留兼容结构。

## 本地启动

1. 将 `.env.example` 复制为 `.env`，替换三个开发密钥。
2. 使用 `docker compose up -d` 启动 PostgreSQL、Redis 和 Mailpit。
3. 执行 `npm install`、`npm run build`、`npm test`。
4. 执行 `npm run start:dev`，API 默认监听 `http://127.0.0.1:3000/v1`。
5. Mailpit 测试收件箱位于 `http://127.0.0.1:8025`。
6. 服务和三个容器运行时，可执行 `npm run test:e2e` 复验真实邮件、登录、令牌轮换、重放拦截、退出和注销链路。
7. 可执行 `npm run test:sync-e2e` 与 `npm run test:continuation-e2e` 复验多设备同步和接续控制权认领。

服务不会把邮箱、验证码、访问令牌或刷新令牌写入普通日志。生产启动会拒绝回环地址、明文 Redis、未启用数据库 TLS、占位发件域名或缺失密钥；正式入口仍必须由反向代理提供 HTTPS。

## 接口

- `POST /v1/auth/code/request`
- `POST /v1/auth/code/verify`
- `POST /v1/auth/refresh`
- `POST /v1/auth/logout`
- `DELETE /v1/account`
- `POST /v1/sync/push`
- `GET /v1/sync/pull`
- `POST /v1/continuation/prepare`
- `POST /v1/continuation/claim`
- `GET /v1/continuation/status`
- `GET /v1/health`
