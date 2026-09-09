# Drv Knowledge Suite V2.0.2 完整交付包说明

构建日期：2026-09-04。

本交付包将 V2.0.2 项目源码、独立组件制品、离线依赖、RAGFlow 芯片手册清洗器，以及 A2、A3、A5、M3、E2 五份原始基线和最终清洗结果放在同一个压缩包中，便于直接迁移到公司内网验证。

## 目录说明

- `artifacts/`：Skills、Governance、Contracts 独立组件包、完整源码包、SBOM 和组件制品哈希清单。
- `sanitizer/`：可独立离线运行的清洗器、RAGFlow 文档级参数模板和操作规范。
- `manual-source-baseline/`：本轮五份问题文档的只读原始基线，用于复核来源哈希；不得直接覆盖或替换现有知识库文件。
- `cleaned-manuals/`：五份文档的 BookStack 清洗稿、RAGFlow 专用分片、审计结果、映射信息和哈希清单。
- `deployment/`：V2 部署手册和 RAGFlow v0.27 P0 部署说明。
- `PACKAGE_SHA256SUMS.json`：本交付目录内全部文件的 SHA-256。

## 内网使用顺序

1. 先校验顶层压缩包旁的 `.sha256` 文件，再校验 `PACKAGE_SHA256SUMS.json`。
2. 解压 `artifacts/drv-knowledge-suite-v2.0.2-source.zip`，按 `deployment/DEPLOYMENT_V2.md` 配置内网地址、证书和 Secret。不得把真实凭据写回发布物。
3. 已有 BookStack 数据库必须先备份；V2 部署使用现有数据库连接和迁移机制，不应重新初始化或覆盖文章库。
4. 在并行 RC 数据集验证五份手册。只上传 `cleaned-manuals/<文档>/ragflow/part-*.md`，不要把 `document.cleaned.md` 直接上传 RAGFlow。
5. 对每个 RAGFlow 文档应用 `sanitized-chip-manual-v1` 文档级配置：`naive`、`chunk_token_num=256`、分隔符为单换行，关闭 GraphRAG、RAPTOR、自动关键词和自动问题。
6. 五份文档均解析为 `DONE`，并完成抽样召回与来源链接检查后，再替换正式数据集中的旧文档。

## 清洗器离线运行

清洗器只依赖 Python 标准库：

```bash
python sanitizer/ragflow_sanitize.py audit manual-source-baseline/01_A2.md
python sanitizer/ragflow_sanitize.py clean manual-source-baseline/01_A2.md output/01_A2
python sanitizer/ragflow_sanitize.py gate output/01_A2
```

正式批量接入应先执行 `audit`。当 `requires_sanitization=true` 时，必须清洗并通过 `gate`，不能靠调高 embedding 限制或静默截断正文放行。

## 镜像说明

本包没有混入旧的 `2.0.0-rc.3` OCI 镜像。V2.0.2 BookStack 与 Worker 镜像已在 Linux x86_64 云验证机从本包源码构建，并导出为带 SHA-256 的 OCI 离线制品。内网导入后使用固定的 `2.0.2` tag；切换镜像前仍需备份 MariaDB 与 BookStack `/config`，且不得重新初始化数据库卷。

## 验收边界

本地验收覆盖清洗器单元测试、五份真实文档结构门禁、组件发布检查、哈希一致性和解压复验。云端已使用 Fake RAGFlow 验证 BookStack Intake、Worker 编译、审核、发布替换、文档级解析参数、A 实时召回、来源 URL 与悬浮机器人 Chat。真实 RAGFlow 与 one-api 的最终生产兼容性仍必须在公司内网 RC 数据集完成解析与召回测试后才能确认。
