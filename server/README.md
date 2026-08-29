# StudyAssistant API

模块 9 提供 `/v1` 下的邮箱验证码账号接口。验证码有效 10 分钟且只可使用一次；访问令牌有效 15 分钟；刷新令牌有效 30 天并在每次刷新时轮换。数据库中的 `password_hash` 允许为空，为后续密码登录保留兼容结构。

## 本地启动

1. 将 `.env.example` 复制为 `.env`，替换三个开发密钥。
2. 使用 `docker compose up -d` 启动 PostgreSQL、Redis 和 Mailpit。
3. 执行 `npm install`、`npm run build`、`npm test`。
4. 执行 `npm run start:dev`，API 默认监听 `http://127.0.0.1:3000/v1`。
5. Mailpit 测试收件箱位于 `http://127.0.0.1:8025`。
6. 服务和三个容器运行时，可执行 `npm run test:e2e` 复验真实邮件、登录、令牌轮换、重放拦截、退出和注销链路。

服务不会把邮箱、验证码、访问令牌或刷新令牌写入普通日志。生产环境必须使用 HTTPS、独立强密钥、托管 PostgreSQL/Redis，并将 SMTP 配置替换为正式邮件供应商。

## 接口

- `POST /v1/auth/code/request`
- `POST /v1/auth/code/verify`
- `POST /v1/auth/refresh`
- `POST /v1/auth/logout`
- `DELETE /v1/account`
- `GET /v1/health`
