# Drv Knowledge Suite V2.0 云端内网部署模拟验收报告

日期：2026-08-31（Asia/Shanghai）  
目标环境：Linux x86_64、Docker Compose、BookStack `v26.03.3`、MariaDB `11.4.9`  
验证入口：`http://<cloud-bookstack-host>:6875`  
结论：在目标机已预载基础镜像、RAGFlow 未配置的条件下，BookStack 治理镜像、V2 Intake、HMAC Worker、离线编译、幂等重放和任务停机恢复均已通过真实容器验证。该结果可作为云端 RC 功能基线，但不等同于已经验证从零开始的完全断网部署；正式发布前仍需在公司内网补做 OCI 离线导入、RAGFlow、普通用户权限和 A 侧 SQLite outbox 联调。

> 2026-08-31 UI 验收补充：RC.1 的治理静态文件和受保护路由已存在，但入口资源未被 BookStack 页面自动加载，且原入口脚本依赖当前环境不存在的工具箱锚点，因此“知识治理中心”未显示。RC.2 已修复为认证页自动注入、CSP nonce 兼容和独立悬浮按钮回退，并以 `--network=none` 在目标机完成镜像构建和滚动替换。容器内运行时验证确认匿名页不注入、认证页 CSS/JS 与 CSP nonce 正确；真实浏览器验证确认 BookStack 首页右下角入口可见且可进入治理总览。治理回归为 123/123，通过 405 文件发布安全扫描和 176/176 组件哈希复验。

## 1. 部署基线与备份

- 原 BookStack 镜像：`lscr.io/linuxserver/bookstack:version-v26.03.3`
- 原 BookStack 固定 digest：`sha256:123be84437ee5e9dd4b36466f1812a3ba9b99ed31b3b451702f2dd09f5fc36c1`
- 当前治理镜像：`drvknowledge/bookstack-governance:2.0.0-rc.2`
- 当前治理镜像 ID：`sha256:9d9e5ff32c0efddd3f59c6b88c10bd3bcde8c8b8aad58c1ec4e13db91850dcb1`
- 上一治理镜像：`drvknowledge/bookstack-governance:2.0.0-rc.1`，镜像 ID `sha256:5a8785b718a6bbee00117c1f70c56679ba8b7afca5a73bde76838b70a2ec913b`，保留用于应用级回滚。
- Worker 镜像：`drvknowledge/worker:2.0.0-rc.1`
- Worker 镜像 ID：`sha256:826847e4aaea814ad1354811ccad9caac9c95a336b8da4c3e804a69a053c74cd`
- 当前发布目录：`/home/ubuntu/releases/drv-knowledge-suite-v2.0.0-rc.2`
- 初始 RC 发布目录：`/home/ubuntu/releases/drv-knowledge-suite-v2.0.0-rc.1`
- 运行目录：`/home/ubuntu/apps/bookstack`
- 初始备份目录：`/home/ubuntu/backups/drv-v2-cloud-20260830T151627Z`
- RC.2 升级前备份目录：`/home/ubuntu/backups/drv-v2-ui-20260830T171645Z`
- 两轮数据库全量备份和 `/config` 数据备份均已执行 `sha256sum -c`，结果为 `OK`。
- Worker HMAC 密钥只保存在服务器 `/home/ubuntu/apps/bookstack/.env.drv-v2`，权限为 `0600`；本报告和仓库未记录密钥。

## 2. 网站结构恢复

通过 BookStack API 幂等创建并复查以下结构：

| 书架 | 书籍 | Shelf ID | Book ID |
| --- | --- | ---: | ---: |
| `【AI】经验案例` | `经验案例库` | 6 | 1 |
| `【AI】手册资料` | `芯片手册` | 7 | 2 |
| `【AI】技术资料` | `技术专题` | 8 | 3 |
| `【AI】项目资料` | `项目文档` | 9 | 4 |
| `【SYS】工程工具` | `工程工具` | 10 | 5 |

同一恢复脚本重复执行后未产生重复书架或书籍。

## 3. 治理部署结果

- BookStack、MariaDB 与 Worker 使用 Compose 管理。
- BookStack 与 Worker 位于同一 `bookstack_internal` 网络。
- MariaDB 原容器和原绑定目录未重建。
- 治理迁移已创建 9 张 `drv_kb_*` 表：assets、audit_events、compile_tasks、gaps、intakes、quality_checks、rag_snapshot、reports、reviews。
- `/login` 返回 HTTP 200；根路径返回到登录页的正常 302。
- 未签名的 Worker claim 请求返回 HTTP 401 和 `SIGNATURE_INVALID`。
- RAGFlow 地址和凭据保持为空，治理状态稳定为 `not_ingested`，不会误标记已发布。
- 发布安全扫描覆盖 403 个文件并通过，已生成 SPDX 2.3 SBOM；SBOM 当前为本地 RC 证据，尚未纳入签名发布包。

## 4. 真实业务 E2E

### 4.1 Intake、离线编译和幂等

验证页面：BookStack page `11`，`V2 云端离线闭环验证`。

1. 使用个人 BookStack API Token 创建页面。
2. 按 BookStack 实际导出的 Markdown 计算 SHA-256。
3. 调用 `POST /api/ai-governance/v2/intakes`，返回 HTTP 202、intake `1`、task `1`。
4. Worker 使用 HMAC claim `wiki-task.v2`，以 `offline-source-preserving` 生成 draft-only `wiki-result.v2`。
5. 批量状态接口返回：
   - Compile：`succeeded`
   - Review：`pending_review`
   - RAG：`not_ingested`
   - Quality：`0`
6. 使用相同 `Idempotency-Key` 和相同请求再次提交，返回 HTTP 200，`replayed=true`，仍指向 intake `1` 和 task `1`。

数据库一致性结果：source asset `1`、wiki asset `2`、task `1` 为 `succeeded`，review 为 `pending_review/warning`，没有绕过人工审核或触发 RAG 发布。

### 4.2 Worker 停机与恢复

验证页面：BookStack page `12`，`V2 Worker 队列恢复验证`。

1. 停止 Worker。
2. 创建页面并提交 Intake，返回 HTTP 202、intake `2`、task `2`。
3. 等待后状态仍为 `queued`，任务未丢失。
4. 恢复 Worker。
5. 约 5 秒后状态变为 `succeeded / pending_review / not_ingested`，wiki asset 为 `4`。

该验证覆盖了 Worker 暂时不可用时的数据库持久队列与自动恢复。A 侧在 B 完全不可用时的 SQLite outbox 仍需在内网使用真实 Skills/CLI 终端补测。

## 5. 现场发现与修复

### 5.1 Compose 环境文件覆盖

现场表现：仅指定 `.env.drv-v2` 会替代 Compose 默认加载的 `.env`，使原 BookStack 数据库和 APP 变量变为空值。

修复：所有叠加部署命令统一使用：

```bash
docker compose --env-file .env --env-file .env.drv-v2 \
  -f compose.yaml -f compose.governance.yaml ...
```

部署计划文档已同步修正。

### 5.2 Laravel 缓存目录与 PUID/PGID

现场表现：首次治理镜像切换后 `/login` 返回 HTTP 500，Laravel 日志显示 `/app/www/bootstrap/cache` 不可写。

根因：LinuxServer 基础镜像在启动期把 `abc` 用户映射为部署者配置的 `PUID/PGID`；镜像构建期 `chown abc:abc` 使用的是基础镜像原始 UID/GID，不能保证运行期仍可写。

修复：新增 `/custom-cont-init.d/90-drv-governance-permissions`，在用户映射完成后重新设置缓存目录属主和权限。验证结果：

- 启动日志显示自定义初始化脚本退出码为 0。
- 缓存目录实际 UID/GID 为运行期 `1000:1000`。
- 以 `abc` 执行 `php artisan optimize:clear` 成功。
- 随后访问 `/login` 返回 HTTP 200，新生成的 `services.php` 属于 `1000:1000`。
- 已增加部署回归测试，防止后续镜像遗漏启动期权限脚本。

### 5.3 云覆盖文件网络遗漏

现场表现：Worker 容器持续运行但任务不被领取；探针显示 `Temporary failure in name resolution`。

根因：本次云环境增量覆盖文件未声明 BookStack 的已有内部网络，Worker 被放入 Compose 默认网络。仓库正式 `deploy/compose.yaml` 原本已正确声明统一网络。

修复：云覆盖文件为 Worker 增加 `bookstack_internal`。重新创建 Worker 后，任务在一个轮询周期内完成。

## 6. 回滚可行性

- 原 `compose.yaml` 保持不变，并可独立渲染出原 BookStack 与 MariaDB 镜像。
- 原 BookStack 固定镜像仍在本机镜像缓存中。
- 数据库和 BookStack `/config` 备份校验通过。
- 可执行回滚顺序：停止并移除 Worker，使用原 `compose.yaml` 重新创建 BookStack；`drv_kb_*` 表保留，不执行破坏性回滚。
- 本次没有实际执行最终回滚，因为验证环境需要保留 RC 供后续 RAGFlow 和人工审核联调。

## 7. 未覆盖项与发布门槛

以下项目不是本次失败，而是受当前测试条件限制尚未执行：

- RAGFlow 版本探针、上传、解析、删除失败保护和 `ready/stale/failed` 全状态链路。
- 正式 `verified` 审核与仅 `【AI】` 书架允许 RAG 发布的端到端验证。
- 普通用户 Token 的页面权限拒绝；当前仅提供管理员 Token。本次已覆盖 Worker 未签名越权拒绝。
- A 侧 CLI 在 B 完全离线时写入 SQLite outbox、恢复后的幂等重放。
- A `1.0.8` 与 B `1.9.1` 的真实历史数据升级演练。
- OCI 镜像和完整离线留存包已经生成并通过哈希与压缩流校验；仍需在一台全新内网主机实际执行 `docker load`、wheelhouse 安装和主链路冒烟测试。
- 制品签名尚未接入，当前完整性由 SHA-256、SBOM、固定基础镜像 digest 和版本化源码提交共同保证。
- 管理员需在本轮验证结束后撤销本次 BookStack API Token，并轮换 SSH 登录凭据；此项必须由环境管理员执行，当前报告不将其标记为已完成。

## 8. 当前验收判断

当前云端 RC 已证明“固定 BookStack 镜像 + 独立 Worker + 无 RAGFlow 离线编译 + 数据库治理真源”的运行模型可行，前提是目标机已经具备所需基础镜像。进入公司内网时应保持业务源码不变，通过离线 OCI 制品导入相同镜像，仅替换 `.env`、Secret、证书、RAGFlow 地址及数据集映射，并按第 7 节完成完全断网部署门槛验证。

## 9. RC.2 最终部署、界面与留存验收

### 9.1 真实主链路

- 新建验收页面：BookStack page `13`，名称 `RC2 部署与界面验收`。
- 首次 Intake 返回 HTTP `202`；使用相同 `Idempotency-Key` 重放返回 HTTP `200`、`replayed=true`，两次任务 ID 均为 `3`。
- Offline Worker 在一个轮询周期内完成任务，数据库记录为 `succeeded / offline / retry_count=0`，无错误码。
- 权威状态查询返回 `succeeded / pending_review / not_ingested`，符合 RAGFlow 空配置预期。
- `drv_kb_*` 表仍为 9 张；页面 `13` 生成 source asset `5` 和 wiki asset `6`，Intake `3` 关联 compile task `3`。
- 真实治理总览更新为 3 份原始资料、3 份 Wiki、3 份待审阅，浏览器控制台无错误。

### 9.2 界面验证

- Codex 内置浏览器确认未登录访问受保护入口会跳转登录页，认证边界生效。
- 内置浏览器在本地演示数据模式逐项加载：治理总览、文档审阅、人员贡献、质量问题、RAG 状态、知识图谱、知识缺口和报告生成；8 个主视图标题、内容和路由均正确，控制台无警告或错误。
- 文档审阅组合筛选验证通过：选择 `芯片手册` 与 `待审阅` 后仅保留 `DDR 配置` 一项。
- 系统诊断弹窗可以打开和关闭；窄屏 `390 × 844` 下总览内容、导航按钮和指标卡仍可见。
- 已认证真实页面确认 BookStack 首页右下角存在唯一“知识治理中心”入口，计算样式为 `position: fixed; right: 24px; bottom: 76px; z-index: 1000`，点击后进入真实治理总览。

### 9.3 离线留存包

- 最终完整包：`drv-knowledge-suite-v2.0.0-rc.2-offline-bundle-validated.zip`，外层 SHA-256 记录在同名 `.sha256` 旁路文件中，避免制品清单自引用。
- 包内 13 个受管制品逐项哈希通过，外层 ZIP 共 15 个条目；源码归档 561 个条目，不包含 `.env`、私钥、PEM 或 `.git`。
- BookStack OCI：`drv-knowledge-bookstack-v2.0.0-rc.2.oci.tar.zst`，SHA-256 `17c7ff471d7e1a2fab92041db915e48505045a384450378bd5219bdfffe9abd8`。
- Worker OCI：`drv-knowledge-worker-v2.0.0-rc.1.oci.tar.zst`，SHA-256 `4a0ed3e2b741cba8f42484de3fb33f17a942804fa01cb812e0d4143ef6d7d864`。
- 两个 OCI 压缩流均通过 `zstd -t`，镜像文件同时保留在目标机版本目录和本地 `dist`。

## 10. RC.3 GrokBot 上下文助手重构验收（2026-09-02）

### 10.1 设计与功能结果

- 原独立“治理中心按钮”已重构为常驻 GrokBot 上下文助手，机器人本身即为治理入口，不再依赖旧工具箱锚点。
- 采用经许可证核验的 GrokBot 表情几何资源，并改造为 Drv 蓝白视觉；上游版本、MIT/BSD-3-Clause 许可证及原始提交号随发布物离线留存。
- 助手包含 25 种表情和 39 个业务状态。知识资产、知识图谱、知识缺口、日周报分别映射到工作、雷达、好奇和写作状态；编译、审核、RAG、上传、成功与异常状态有独立反馈。
- G3 交互已实现：机器人在 260px 范围内跟随鼠标方向注视，眼球响应幅度高于头部，离开范围后平滑回正；触摸设备和 `prefers-reduced-motion` 环境自动降级。
- 面板统一承载六项规划功能。知识资产、知识图谱、知识缺口、日周报接入现有治理页面；Git 后台备份和文档转换明确显示为 V2.1 规划项，未提供误导性假入口。
- 页面上下文状态通过 V2 批量状态接口读取，编译、审核和 RAG 状态不再由前端自行推断。

### 10.2 自动化与真实浏览器验证

- Governance Node 回归共 126 项：125 通过、0 失败、1 项独立 Playwright 启动测试因本机未安装浏览器执行文件而按环境门禁跳过。
- 已使用 Codex 内置浏览器执行等价真实浏览器验收：桌面与 `390 × 844` 窄屏均可打开助手和六功能面板，控制台无错误，移动端无水平溢出。
- 指针跟随实测中，近距离移动后眼球位移约 `5.79px`，头部位移约 `0.70px`、旋转约 `1.71deg`；移出范围后恢复到近零位置。
- 状态切换实测覆盖知识图谱 `radar` 与完成态 `celebrate`，表情和动效均随状态更新。
- Skills 全量测试已在仅使用本地 Windows x86_64 CPython 3.12 wheelhouse 的临时虚拟环境中通过；发布测试 11/11 通过。
- 发布安全扫描通过；secret、外部 URL/CDN、许可证、SBOM 与制品完整性检查均未发现阻断项。

### 10.3 云端模拟内网部署

- 升级前备份目录：`/home/ubuntu/backups/20260902-grokbot-rc3`，包含数据库、环境文件、Compose 覆盖文件和 SHA-256 清单。
- 发布目录：`/home/ubuntu/releases/drv-knowledge-suite-v2.0.0-rc.3`。
- 固定镜像：`drvknowledge/bookstack-governance:2.0.0-rc.3`；镜像 ID 为 `sha256:560140d00d00bf2d8cc2e55f3a154b26f2e350839ce47fdfe69eda1de887c22d`。
- 仅重建 BookStack 服务，未重建 MariaDB、未覆盖 `/config`，启动日志显示无待执行迁移且容器健康。
- 升级前后数据计数一致：book `5`、bookshelf `5`、page `3`、governance assets `6`、governance reviews `3`，证明此次前端镜像更新未覆盖既有文章与治理数据。
- 容器内治理路由共 33 条；GrokBot 入口脚本、头像脚本和表情数据均存在。线上提供的头像脚本 SHA-256 与本地发布源一致。
- RAGFlow 地址仍按计划留空，因此本次 RC.3 不触发 RAG 发布；离线编译、人工审核边界和待同步状态保持原行为。

### 10.4 RC.3 制品

- BookStack OCI：`drv-knowledge-bookstack-v2.0.0-rc.3.oci.tar.zst`，SHA-256 `25b8e33584beae51a41c03b3bcb5a4280891bc4feb66a24542e734efeb37e873`。
- OCI 已在 Linux 发布主机由实际部署镜像导出，云端旁路哈希与回传后的本地文件哈希一致。
- 完整离线包 `drv-knowledge-suite-v2.0.0-rc.3-offline-bundle.zip` 将 A Skills `2.0.1`、Worker OCI `2.0.0-rc.1`、B Governance `2.0.0`、BookStack OCI `2.0.0-rc.3`、Contracts `2.0.0`、SBOM、部署文档和当前源码提交绑定在同一清单内。
- 云端升级后的回滚方式保持不变：将 `compose.governance.yaml` 的 BookStack tag 切回 `2.0.0-rc.2` 并仅重建 BookStack 服务；数据库与 `/config` 不做破坏性操作。
