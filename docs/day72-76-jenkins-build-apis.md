# Day 72–76 · 构建 API / 状态 / UI / 通知 / 历史

## API（cloudops-cicd）

| Day | Path | 说明 |
|-----|------|------|
| 72 | `POST /api/v1/cicd/builds/match` | 单服务匹配 |
| 72 | `POST /api/v1/cicd/builds/dry-run` | 批量匹配 |
| 72 | `POST /api/v1/cicd/builds` | 触发（可 `dry_run`） |
| 73 | 异步队列轮询 + `JENKINS_MAX_CONCURRENT` | 状态 `queued/RUNNING/SUCCESS/FAILURE` |
| 75 | `POST /api/v1/cicd/builds/notify` | 成功不带 build URL，失败带 URL |
| 76 | `GET /api/v1/cicd/builds` / `{id}` | `build_history` 表（Postgres）或内存 |

## UI（Day 74）

`cloudops-web` 首页「批量构建」：清单 → dry-run → 触发 → 历史。

## 环境变量

见 `services/cloudops-cicd/README.md`：`JENKINS_*`、`WEBHOOK_INFO_URL`、`SEND_WEBHOOK`。
