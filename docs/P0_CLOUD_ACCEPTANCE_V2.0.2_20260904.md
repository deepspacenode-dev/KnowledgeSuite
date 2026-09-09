# Drv Knowledge Suite V2.0.2 P0 云端验收报告

验收日期：2026-09-04  
环境：Linux x86_64、Docker Compose、BookStack、MariaDB、V2 Governance、V2 Worker、Fake RAGFlow。

## 验收结论

V2.0.2 的 P0 范围已在云测试环境完成闭环验证，可以进入公司内网的真实 RAGFlow RC 验证。P1 功能未在本轮继续实施。

本次 P0 包含：

- BookStack 页面 URL、`source_key` 与 `content_ref` 贯穿 Intake、Worker、RAGFlow、A 召回和机器人 Chat。
- BookStack 悬浮机器人通过同源代理调用 RAGFlow Chat，浏览器不持有 RAGFlow 凭据。
- A 召回启用领域识别、RAGFlow 元数据条件和客户端交叉校验，阻断明确的跨领域候选。
- BookStack 命名标签映射为受控的 `owner/module/platform/chip/project`，并通过 V2 合同传到 Worker 与 RAGFlow。
- RAGFlow Markdown 文档级解析参数固定为 `naive`、单换行、512 tokens，并关闭自动关键词、自动问题、GraphRAG、RAPTOR 与 parent-child。

## 实测主链路

使用 BookStack 页面 14（`V2.0.2 P0 RAGFlow 链路验证 20260904`）执行：

1. 页面写入 `module=network`、`platform=linux`、`project=drv-knowledge-suite`、`owner=admin` 命名标签。
2. Intake 6 原子生成 source version 3 与 compile task 6。
3. Worker 领取任务并返回 draft-only `wiki-result.v2`；任务状态为 `succeeded`。
4. Wiki asset 8 version 3 的 Front Matter 完整保留领域元数据。
5. 管理员审核为 `reviewed`，质量门禁允许发布。
6. RAG 发布执行 `updated`，先删除旧文档，再上传并启动解析。
7. Fake RAGFlow 文档状态为 `ready`，`module=network`，页面 URL 与 `bookstack_page:14` 正确。
8. A 使用查询“网络无流量如何排查”进行 live recall，返回 1 条 network 案例，置信度 0.8695，来源 URL 可点击。
9. 悬浮机器人 Chat 返回 HTTP 200、1 条页面引用，URL 与 `source_key` 同页面一致。

## 缺陷修复

- 修复 Intake 查询只返回创建快照、任务实际成功但仍显示 `queued` 的问题。
- 修复 `AiShelfPolicy` 可选依赖被容器注入为 null，导致 `【AI】` 书架始终被误拒的问题。
- 修复 Worker 把领域元数据无条件写为空值，导致严格过滤误伤正确结果的问题。
- 标签与领域元数据已纳入治理版本指纹；修改标签会触发新的 source version 与重审流程。

## 回归证据

- A：`RETRIEVAL_SUMMARY total=39 failed=0`；`SUITE_TEST_SUMMARY total=10 failed=0`。
- 清洗器：24 项单元测试通过；五份芯片手册结构门禁在完整交付包中留存。
- B：133 项 Node 测试中 132 项通过，1 项仅因 Windows 本机缺少 Playwright 浏览器可执行文件而跳过。
- Contracts：12 项通过；Release：12 项通过；Worker：5 项通过。
- BookStack 镜像构建时完成全部治理 PHP 文件语法检查；云端执行了 PHP 领域标签纯函数检查与真实 Laravel/MariaDB 主链路。

## 数据与回滚安全

- 部署只重建 BookStack 与 Worker 容器，没有重建 MariaDB。
- MariaDB 容器 ID 在部署前后保持一致：`a6cb5c6bce4c678765b5217d851b7189840f0bd3840d47890b27b479c1117e39`。
- 原有 5 个 Book、5 个 Shelf、3 篇 Page 均保留；当前第 4 篇为本次 P0 验证页。
- 当前治理数据：8 个 asset、8 条 review、6 个 intake、6 个 compile task。
- 部署前备份位于 `/home/ubuntu/backups/20260904-v202-p0-preupgrade`，备份哈希已校验。
- 临时验收管理员已删除，不随交付物保留。

## 内网最终验收边界

Fake RAGFlow 只验证接口、错误恢复、元数据、解析状态与链接契约，不代表真实 embedding、one-api 和 RAGFlow parser 性能。内网上线前还需：

1. 只替换 RAGFlow 地址、Secret、证书和数据集映射，不修改业务源码。
2. 执行 RAGFlow 版本探针与 Chat/Workflow 能力探针。
3. 在隔离 RC 数据集中解析五份已清洗芯片手册，并确认全部 `DONE`。
4. 执行 network、SoC、存储等跨领域对照查询，确认正确命中与错误候选阻断。
5. 冒烟通过后再把 `2.0.2` 固定镜像切入正式 Compose。
