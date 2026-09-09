# BookStack AI V2.0.3 知识治理中心部署方案

本文档用于把 V2.0.3 知识治理中心部署到现有 BookStack 环境中。部署目标是新增独立治理中心页面、治理 API、工具箱入口、审阅门禁、RAGFlow 状态同步、Wiki 编译任务接口和 Markdown 报告能力。

V2.0.3 不替换 BookStack 主程序，不修改 RAGFlow 服务本身，不在 BookStack PHP 后端直接调用大模型。BookStack 侧只负责页面身份、任务导出、审核门禁、入库触发和治理展示；Wiki 编译和二次知识整理由 RAGFlow / DrvAgent / CodeBuddy 工作流承接。

## 1. 部署范围

本包会安装以下内容到 BookStack 根目录：

- `app/AI/Governance`：治理中心 PHP 代码。
- `routes/ai-governance.php`：治理 API 路由。
- `routes/ai-governance-page.php`：治理页面入口路由。
- `database/migrations/*drv_kb*`：治理中心数据表迁移。
- `public/ai-governance`：独立治理中心前端页面与静态资源。
- `public/ai-assistant/ai-assistant-governance-entry.*`：BookStack 悬浮治理助手入口与样式。
- `public/ai-assistant/vendor/bloub`：默认蓝色 Bloub 小人的自包含浏览器运行包、样式、可重建适配源码、上游信息和 MIT 许可证；运行时不访问外部 CDN。
- `public/ai-assistant/grokbot-avatar.js`、`public/ai-assistant/vendor/grokbot`：隔离保留的旧 GrokBot 回滚资产，不再由页面默认加载。
- `routes/web.php`：只追加带标记的两行 `require`，用于加载治理路由。

本包不会删除或覆盖 BookStack 原有数据表，不会写入真实密钥到压缩包，不会修改现有 AI 助手核心脚本。卸载脚本会移除本包拥有的文件与路由标记，但默认保留 `drv_kb_*` 数据表。

## 2. 推荐部署拓扑

### 2.1 生产推荐

```text
Windows 管理机 / 运维机
  -> 复制部署包到 BookStack 容器或服务器
  -> 在 BookStack 根目录执行 install.sh
  -> BookStack 同源访问治理中心与治理 API
  -> RAGFlow 由 BookStack 后端通过 API Key 访问
  -> DrvAgent / CodeBuddy 通过签名 Worker API 领取任务与回传结果
```

生产优先使用 Linux / 容器内安装方式，因为它能直接运行 `php artisan migrate --force` 和 `php artisan optimize:clear`。

### 2.2 Windows 挂载目录方式

如果 BookStack 根目录通过 Windows 盘符挂载，例如 `X:\bookstack`，可以使用 PowerShell 安装脚本复制文件与注册路由。迁移命令仍需要在 BookStack 容器或服务器内执行，除非 Windows 本机可直接运行目标 BookStack 的 PHP 环境。

## 3. 部署前准备

### 3.1 必须备份

部署前请先备份：

1. BookStack 数据库。
2. BookStack `.env`。
3. BookStack `routes/web.php`。
4. BookStack `public/ai-assistant`、`public/ai-governance`、`app/AI/Governance` 等可能被覆盖的目录。
5. `/app/www/public/data` 中已有的治理、入库或历史 JSON 文件。

安装脚本会自动备份被覆盖的同名文件，但数据库备份必须由运维侧先完成。

### 3.2 环境版本

建议环境：

- BookStack：`>=24.05 <26.0`
- PHP：`>=8.1 <8.4`
- Laravel：`>=10 <13`
- RAGFlow：继续使用当前可用的 Dataset 文档上传与删除接口
- 浏览器：Chrome / Edge 最新稳定版

### 3.3 解压部署包

把压缩包解压到临时目录，例如：

```bash
mkdir -p /tmp/bookstack-ai-v1.9.1
unzip BookStack_RAGFlow_v1.9.1_governance_center.zip -d /tmp/bookstack-ai-v1.9.1
cd /tmp/bookstack-ai-v1.9.1
```

如果是在 Windows 上解压，请确保文件没有被杀毒软件隔离，且 PowerShell 能访问解压后的 `scripts` 目录。

## 4. 配置环境变量

把本包 `.env.example` 中的变量合并到 BookStack `.env`。真实密钥只写入目标 BookStack `.env`，不要写回部署包。

```dotenv
RAGFLOW_BASE_URL=http://10.222.120.25
RAGFLOW_WEB_URL=http://10.222.120.25/
RAGFLOW_API_KEY=<仅写入目标环境>
RAGFLOW_DEFAULT_DATASET_ID=replace_me
RAGFLOW_CHAT_BASE_URL=http://10.222.120.25
RAGFLOW_CHAT_API_KEY=<留空时复用 RAGFLOW_API_KEY>
RAGFLOW_CHAT_ID=replace_me
RAGFLOW_CHAT_TIMEOUT_SECONDS=120
RAGFLOW_WIDGET_ENABLED=true
RAGFLOW_WIDGET_BASE_URL=http://10.222.120.25
RAGFLOW_WIDGET_PATH=/chats/widget
RAGFLOW_WIDGET_SHARED_ID=<RAGFlow 分享 ID>
RAGFLOW_WIDGET_AUTH=<仅写入目标环境>
RAGFLOW_WIDGET_STREAMING=false
RAGFLOW_WIDGET_MUTED=true
RAGFLOW_WIDGET_ACCENT_COLOR=#2563eb
RAGFLOW_WIDGET_BACKGROUND_COLOR=#ffffff
RAGFLOW_WIDGET_TEXT_COLOR=#111827
RAGFLOW_WIDGET_HEADER_TEXT_COLOR=#ffffff
RAGFLOW_WIDGET_FOOTER_TEXT_COLOR=#111827
RAGFLOW_WIDGET_TITLE=Drv Knowledge Assistant
RAGFLOW_WIDGET_SUBTITLE=Governed enterprise knowledge
RAGFLOW_WIDGET_FOOTER=Drv Knowledge Suite
RAGFLOW_WIDGET_FOOTER_LINK=
RAGFLOW_WIDGET_ALLOWED_PATHS=/chats/widget,/next-chats/widget
RAGFLOW_WIDGET_ALLOW_MEDIA=false
RAGFLOW_WIDGET_LOAD_TIMEOUT_MS=12000
RAGFLOW_MARKDOWN_CHUNK_TOKENS=512
BOOKSTACK_URL=https://bookstack.example.com

BOOKSTACK_TOKEN_ID=replace_me
BOOKSTACK_TOKEN_SECRET=replace_me

AI_GOVERNANCE_WORKER_KEY=replace_with_at_least_32_random_characters

# 逗号分隔；名称匹配的书架按章节作为最小评审单位
AI_GOVERNANCE_CHAPTER_REVIEW_SHELVES=芯片手册

RAGFLOW_INGEST_IMAGES=true
RAGFLOW_IMAGE_MAX_BYTES=10485760
RAGFLOW_IMAGE_ALLOWED_EXTENSIONS=png,jpg,jpeg,webp,gif,svg,bmp
```

### 4.1 RAGFlow 配置

- `RAGFLOW_BASE_URL`：RAGFlow 服务根地址，不要以 `/api/v1` 结尾。
- `RAGFLOW_WEB_URL`：治理中心“打开 RAGFlow”按钮的浏览器地址；为空时回退到 `RAGFLOW_BASE_URL`，只接受 HTTP/HTTPS。
- `RAGFLOW_API_KEY`：BookStack 后端访问 RAGFlow 的 API Key。
- `RAGFLOW_DEFAULT_DATASET_ID`：首次入库且尚无快照时使用的默认 Dataset；已有快照的文档优先沿用其 Dataset。
- `RAGFLOW_WIDGET_*`：悬浮助手使用的官方 RAGFlow Widget；真实 `AUTH` 仅放在目标 `.env`，不写入源码或发布 ZIP。默认路径为 `/chats/widget`，默认不允许麦克风或摄像头。
- `RAGFLOW_CHAT_BASE_URL` / `RAGFLOW_CHAT_API_KEY`：供 Chat Profile 管理和后端兼容接口使用；为空时回退到通用 RAGFlow 配置。浏览器主对话界面使用官方 Widget。

治理中心的“入库并解析”会导出审核后的 Wiki Markdown、采集同源图片、写入页面 URL 等来源元数据，然后调用 RAGFlow 解析接口。“发布并同步状态”还会回查排队/解析中文档的真实状态与分块数。管理员执行“从 RAGFlow 移除”时，系统先删除远端 Markdown 与关联图片；远端删除失败不会改写本地状态，成功后保留治理资产和审计记录并禁止误重新发布。

### 4.2 质量门禁说明

质量问题页的“门禁说明”和检查结果来自同一份 `quality-rules.json`，默认规则为：

- 普通审阅至少 70 分，verified 发布至少 90 分。
- 缺少负责人、模块、适用平台、资料分类时每项扣 8 分。
- 缺少“适用范围”“来源”“风险”推荐章节时每项扣 4 分。
- 缺少可追溯来源扣 40 分并硬阻断；文章已废弃、总分未达目标门槛同样硬阻断。
- 草稿、关闭 `rag_enabled`、来源变更待复审和原始资料身份不扣分，但会暂停相应发布步骤；帮助页会单独列出这些流程限制。
- 质量问题卡片会以中文给出最终是否可入库、触发条件及修复方法；章节评审书架按章节聚合，分数取成员最低分，任一成员硬阻断即阻断整章。

### 4.3 BookStack 图片下载配置

文章内图片入库需要 BookStack 后端能下载图片：

- 图片匿名可读时，`BOOKSTACK_TOKEN_ID` / `BOOKSTACK_TOKEN_SECRET` 可以为空。
- 图片需要登录态或 Token 时，请配置 BookStack API Token。
- 只允许同源 BookStack 图片被采集，避免把外部图片或跟踪链接写入 RAGFlow。

### 4.4 Worker 签名密钥

`AI_GOVERNANCE_WORKER_KEY` 用于 DrvAgent / CodeBuddy 工作者接口签名。建议使用至少 32 位随机字符串，例如：

```bash
openssl rand -hex 32
```

密钥变更后，所有 Worker 需要同步更新，否则任务领取、heartbeat、结果回传会被拒绝。

### 4.4 章节评审书架

`AI_GOVERNANCE_CHAPTER_REVIEW_SHELVES` 按书架名称匹配，可用英文逗号配置多个名称。命中的书架以章节为最小评审与质量治理单位；质量页每章只显示一条记录，页面问题在章节内展开查看。没有章节的书籍直属页面仍按单页评审。修改后执行 `php artisan optimize:clear`。

## 5. 部署预检

### 5.1 包完整性检查

在部署包根目录执行：

```powershell
./scripts/verify-package.ps1
```

预期输出类似：

```text
Package verification: PASS (...)
```

该脚本会检查关键文件是否存在，并重新生成 `SHA256SUMS.json`。

### 5.2 BookStack 预检

在能访问 Docker 的机器上执行：

```bash
sh scripts/preflight-bookstack.sh <bookstack_container_name>
```

重点确认：

- 容器内存在 BookStack 根目录，例如 `/app/www`。
- `php artisan` 可执行。
- `routes/web.php` 可写。
- `database/migrations` 可写。
- `.env` 中 RAGFlow、BookStack、Worker 变量已配置。

### 5.3 集成连通性预检

Windows 运维机可执行：

```powershell
./scripts/preflight-integrations.ps1 `
  -BookStackUrl "https://bookstack.example.com" `
  -RagFlowBaseUrl "http://10.222.120.25" `
  -RagFlowApiKey "<ragflow-api-key>"
```

该检查用于提前发现 DNS、TLS、RAGFlow API Key、BookStack URL 等连通性问题。

## 6. 安装方式 A：Linux / 容器内安装

进入部署包根目录后执行：

```bash
sh scripts/install.sh /app/www
```

如果 BookStack 根目录不是 `/app/www`，替换为实际路径：

```bash
sh scripts/install.sh /var/www/bookstack
```

安装脚本会执行：

1. 校验 BookStack 根目录。
2. 备份同名目标文件到 `backups/install-YYYYMMDD-HHMMSS`。
3. 复制治理中心 PHP、前端、路由和迁移文件。
4. 向 `routes/web.php` 追加带标记的路由引用。
5. 执行 `php artisan migrate --force`。
6. 执行 `php artisan optimize:clear`。

如果只想先复制文件，暂不迁移：

```bash
SKIP_MIGRATE=true sh scripts/install.sh /app/www
```

之后手动执行：

```bash
cd /app/www
php artisan migrate --force
php artisan optimize:clear
```

## 7. 安装方式 B：Windows 挂载目录安装

如果 BookStack 根目录可以从 Windows 访问，例如 `X:\bookstack`，先预演：

```powershell
./scripts/install.ps1 -BookStackRoot X:\bookstack -WhatIf
```

确认目标路径正确后执行：

```powershell
./scripts/install.ps1 -BookStackRoot X:\bookstack -Confirm
```

如果 Windows 本机不能运行 BookStack 的 PHP 环境，可跳过迁移：

```powershell
./scripts/install.ps1 -BookStackRoot X:\bookstack -SkipMigrate -Confirm
```

随后进入 BookStack 容器执行：

```bash
cd /app/www
php artisan migrate --force
php artisan optimize:clear
```

## 8. 验证 BookStack 治理入口

治理服务提供者会在已登录的 BookStack 页面自动注入以下同源、带版本号的静态资源，不需要修改“自定义 HTML 头部内容”：

```html
<link rel="stylesheet" href="/ai-assistant/ai-assistant-governance-entry.css?v=20260908-v203-widget-v1">
<link rel="stylesheet" href="/ai-assistant/vendor/bloub/bloub-avatar.css?v=20260905-bloub-v1">
<script defer src="/ai-assistant/vendor/bloub/bloub-avatar.iife.js?v=20260905-bloub-v1"></script>
<script defer src="/ai-assistant/ai-assistant-governance-entry.js?v=20260908-v203-widget-v1"></script>
```

登录后刷新 BookStack 页面，右下角会显示蓝色 Bloub 小人；它不会迁移到旧工具栏，也不会覆盖已有按钮。处理、进展和异常事件会经过爆散切换到思考、通知和警示状态；无事件时会在六种默认表情之间低频轮换。点击小人展开当前页面治理状态与审核入库、知识图谱、知识缺口、日周报等入口。Git 后台备份和文档转换在 V2.0 中仅显示为 V2.1 规划能力。登录页不会加载该入口。

治理中心正式入口：

```text
/ai-governance-dashboard.html
```

当前页模式入口示例：

```text
/ai-governance-dashboard.html?page_id=123&mode=current_page
```

## 9. 部署后验证

### 9.1 页面验证

访问：

```text
https://bookstack.example.com/ai-governance-dashboard.html
```

预期：

- 页面可以打开。
- 左侧导航包含治理总览、知识资产、人员贡献、质量门禁、RAG 状态、知识缺口、报告中心。
- 页面不显示 `V1.9.1 UI Mockup`。
- 非管理员登录时写操作按钮不可用或被拒绝。
- 管理员登录时可执行审阅、缺口创建、质量检查、报告生成等写操作。
- 文档审阅、人员贡献、质量、RAG、报告和知识图谱均可按书架筛选。
- 芯片手册书架显示“章节评审”，章节操作会批量处理其有效页面。
- 知识图谱以 DrvDocs 为中心呈球形云分布，而不是从上到下的纵向层级。

如果管理员审阅返回 HTTP 419，请先强制刷新页面并确认部署了最新 `api-client.js`。静态治理页会从 `/summary` 获取会话 CSRF token；Cookie 中的 `XSRF-TOKEN` 会通过 `X-XSRF-TOKEN` 请求头发送。

### 9.2 API 验证

在已登录 BookStack 的浏览器中访问：

```text
https://bookstack.example.com/api/ai-governance/v1/auth/whoami
https://bookstack.example.com/api/ai-governance/v1/dashboard/summary
```

预期：

- `auth_whoami` 返回当前用户身份与 `can_write`。
- `dashboard_summary` 返回 KPI、待办、RAG 状态和最近事件。

### 9.3 命令行集成测试

如果 Windows 能访问 BookStack：

```powershell
./scripts/test-in-bookstack.ps1 `
  -BookStackUrl "https://bookstack.example.com" `
  -Cookie "bookstack_session=..."
```

如果在容器内验证，请至少执行：

```bash
cd /app/www
php artisan route:list | grep ai-governance
php artisan migrate:status | grep drv_kb
```

### 9.4 RAGFlow 验证

在治理中心执行“同步 RAG 状态”或触发 reviewed / verified Wiki 条目入库。预期：

- 首次入库返回 `created`。
- 内容不变重复入库返回 `skipped`。
- 内容或图片变化返回 `updated`。
- Dataset 变化返回 `moved`。
- 旧文档删除失败时返回失败，不上传新文档。
- 文章图片入库后，RAG snapshot 中记录 `image_document_ids`。

### 9.5 Worker 验证

DrvAgent / CodeBuddy Worker 需要按 HMAC 签名访问：

```text
GET  /api/ai-governance/v1/internal/tasks/next
POST /api/ai-governance/v1/internal/tasks/{task_id}/heartbeat
POST /api/ai-governance/v1/internal/tasks/{task_id}/result
POST /api/ai-governance/v1/internal/events
```

验证要求：

- 无签名请求被拒绝。
- 签名错误请求被拒绝。
- 正确签名可领取 Wiki 编译任务。
- Worker 回传 Wiki 只能进入 `draft`，不能直接变为 reviewed / verified。

## 10. 旧 JSON 数据迁移

如果已有 V1.7 / V1.8 / V1.9 JSON 状态文件，先 dry-run：

```bash
php scripts/migrate-json.php --bookstack-root=/app/www --data-dir=/app/www/public/data
```

确认输出无误后执行：

```bash
php scripts/migrate-json.php \
  --bookstack-root=/app/www \
  --data-dir=/app/www/public/data \
  --actor-id=1 \
  --apply
```

迁移规则：

- 旧 raw page 审阅只迁移为 `legacy.review.imported` 审计证据。
- 旧质量检查只迁移为 `legacy.quality.imported` 审计证据。
- 不把旧 raw page 自动升级为 reviewed / verified Wiki。
- 知识缺口按标题、来源和 hash 幂等导入。
- 历史报告按 hash 幂等导入。

## 11. 权限与安全

治理中心复用 BookStack 登录态：

- 未登录用户不能访问治理 API 的受保护数据。
- 普通用户默认只读。
- 写操作要求 BookStack 管理员态。
- 管理员检查沿用 BookStack 权限和管理页面探测机制。
- API Key、Token、Cookie 不写入报告，不写入前端，不写入压缩包。

生产建议：

1. 只通过 HTTPS 暴露 BookStack。
2. RAGFlow API Key 使用最小权限。
3. Worker Secret 单独管理，避免与 RAGFlow API Key 共用。
4. 定期轮换 Worker Secret 和 RAGFlow API Key。
5. 对 `/api/ai-governance/v1/internal/*` 做访问日志审计。

## 12. 回滚方案

### 12.1 PowerShell 回滚

先预演：

```powershell
./scripts/uninstall.ps1 -BookStackRoot X:\bookstack -WhatIf
```

确认后执行：

```powershell
./scripts/uninstall.ps1 -BookStackRoot X:\bookstack -Confirm
```

### 12.2 Linux / 容器内回滚

```bash
sh scripts/uninstall.sh /app/www
```

卸载脚本会：

- 删除本包安装的治理 PHP 文件。
- 删除本包安装的治理前端文件。
- 删除本包安装的路由文件。
- 从 `routes/web.php` 删除 `DRVDOCS_AI_GOVERNANCE_START/END` 标记块。
- 保留 `drv_kb_*` 数据表。

如需恢复被覆盖文件，请查看安装备份目录中的：

```text
backups/install-YYYYMMDD-HHMMSS/install-manifest.json
```

### 12.3 数据库回滚

默认不建议自动删除 `drv_kb_*` 表，因为这些表包含审阅、质量、缺口、报告、Wiki 编译任务和 RAG snapshot 历史证据。

如果必须删除，请先导出数据库，再由 DBA 手动确认后处理。

## 13. 常见问题

### 13.1 访问治理中心 404

检查：

```bash
cd /app/www
php artisan route:list | grep ai-governance
grep -n "DRVDOCS_AI_GOVERNANCE" routes/web.php
```

如果没有路由标记，重新执行安装脚本或手动确认 `routes/web.php` 追加内容。

### 13.2 前端打开但数据为空

检查：

- 当前用户是否已登录 BookStack。
- 浏览器控制台是否有 API 401 / 403 / 500。
- `/api/ai-governance/v1/dashboard/summary` 是否可返回 JSON。
- BookStack 缓存是否已清理：`php artisan optimize:clear`。

### 13.3 写操作提示无权限

检查当前用户是否为 BookStack 管理员。普通用户只能查看治理状态，不能执行审阅、质量检查、RAG 同步、缺口更新、报告生成等写操作。

### 13.4 RAGFlow 同步失败

检查：

- `RAGFLOW_BASE_URL` 是否可从 BookStack 容器访问。
- `RAGFLOW_API_KEY` 是否有效。
- RAGFlow Dataset ID 是否存在。
- RAGFlow 当前版本是否接受目标文件类型。
- 网络代理、防火墙、TLS 证书是否阻断。

### 13.5 图片入库失败

检查：

- `RAGFLOW_INGEST_IMAGES=true`。
- 图片扩展名在 `RAGFLOW_IMAGE_ALLOWED_EXTENSIONS` 内。
- 图片大小未超过 `RAGFLOW_IMAGE_MAX_BYTES`。
- BookStack Token 是否可下载当前页面图片。
- 图片 URL 是否为 BookStack 同源地址。

### 13.6 Worker 无法领取任务

检查：

- `AI_GOVERNANCE_WORKER_KEY` 是否一致。
- HMAC 签名算法是否为 SHA-256。
- 请求时间戳是否过期。
- Worker 是否访问了 `/api/ai-governance/v1/internal/*` 路由。

## 14. 生产验收清单

上线前逐项确认：

- [ ] 已完成 BookStack 数据库备份。
- [ ] 已完成 `.env` 与 `routes/web.php` 备份。
- [ ] `.env` 已配置 RAGFlow、BookStack URL、Worker Secret 和图片入库变量。
- [ ] `scripts/verify-package.ps1` 通过。
- [ ] BookStack 容器内 `php artisan migrate --force` 通过。
- [ ] BookStack 容器内 `php artisan route:list` 可看到治理中心路由。
- [ ] `/ai-governance-dashboard.html` 可访问。
- [ ] `auth_whoami` 能区分普通用户与管理员。
- [ ] 工具箱中出现“知识治理中心”入口。
- [ ] 质量检查、审阅、缺口、报告至少各验证一次。
- [ ] RAGFlow `created/skipped/updated/moved` 至少验证主要路径。
- [ ] 图片入库至少验证一篇含图片文章。
- [ ] Worker 签名接口完成无签名拒绝、错误签名拒绝、正确签名通过验证。
- [ ] 回滚脚本已在预演模式验证路径正确。

## 15. 上线建议

建议采用分阶段上线：

1. 先在测试 BookStack 环境安装，验证页面、权限、迁移和 RAGFlow 连通性。
2. 选择 3 到 5 篇 reviewed / verified Wiki 条目做小范围入库验证。
3. 开启工具箱入口给管理员试用，不立即开放普通用户写操作。
4. 接入 DrvAgent / CodeBuddy Worker，只允许生成 draft。
5. 一周后根据质量 warning、RAG 状态和知识缺口报表调整模板与门禁规则。

这样可以把 V2.0.3 作为知识治理中心先稳定落地，再逐步接入更重的 Wiki 编译与二次知识整理链路。
