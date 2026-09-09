# RAGFlow v0.27.1 P0 部署与迁移

本文用于 Drv Knowledge Suite 2.0.3 的内网部署。运行期不依赖公网、CDN 或在线包仓库。

## 1. 安全边界

- 旧 RAGFlow 数据集只读保留，不覆盖、不删除、不批量重解析。
- 新建名称带 `_v2` 的并行数据集，验证通过后只切换环境变量中的数据集 ID。
- BookStack 正文仍保存在原数据库与 `/config` 卷中；治理镜像只增加 `drv_kb_*` 表和扩展文件，不初始化或覆盖既有文章。
- RAGFlow API Key 只配置在 A 的本地环境和 B 的 BookStack 后端，不能写入前端 JavaScript、发布包或文档实例。

## 2. 必填环境变量

```dotenv
BOOKSTACK_APP_URL=http://bookstack.internal:6875
BOOKSTACK_PUBLIC_URL=http://bookstack.internal:6875
RAGFLOW_BASE_URL=http://10.222.120.25
RAGFLOW_API_KEY=<replace-me>
RAGFLOW_DEFAULT_DATASET_ID=<wiki-v2-dataset-id>
RAGFLOW_CHAT_ID=<drv-chat-id>
RAGFLOW_CHAT_TIMEOUT_SECONDS=120
RAGFLOW_MARKDOWN_CHUNK_TOKENS=512
```

A 组件还需要为 cases、manuals、tech notes、project docs 和 docs 分别设置 `RAGFLOW_DATASET_ID_*`。模板中的 Retrieval 参数已经与 v0.27.1 对齐，不要改回已废弃的请求字段 `top_k`。

## 3. 并行迁移

先查看不会写远端的迁移计划：

```bash
kb rag migration-plan --json
kb rag profiles --json
```

在 RAGFlow 内创建 `_v2` 数据集，保持旧数据集不变。通过 BookStack 治理发布重新导出 Wiki；发布会先上传，再写入 `page_url/source_key/content_ref/module/chip/platform/project` 等元数据，最后显式启动解析。

对于需人工导入的历史文档，先上传文件，再应用 Profile 和启动解析：

```bash
kb rag document apply \
  --dataset-id <dataset-id> \
  --document-id <document-id> \
  --profile technical-manual-pdf-v1 \
  --page-id <page-id> \
  --page-url http://bookstack.internal/books/<book>/page/<page> \
  --module network \
  --chip rtl8367s \
  --confirm --json

kb rag parse --dataset-id <dataset-id> --document-id <document-id> --confirm --json
```

所有远端写命令都要求 `--confirm`。解析 Profile 的 SHA-256 会随结果返回，便于验收时确认参数版本。

## 4. 创建 BookStack 悬浮助手 Chat

以下命令使用仓库内 `ragflow-chat-assistant.v1.json` 创建 Assistant，并返回 Chat ID：

```bash
kb rag chat create \
  --dataset-id <cases-v2-id> \
  --dataset-id <manuals-v2-id> \
  --dataset-id <tech-notes-v2-id> \
  --dataset-id <project-docs-v2-id> \
  --confirm --json
```

将返回的 `chat_id` 写入 A、B 和 Compose 的 `RAGFLOW_CHAT_ID`。以后 Prompt 或检索参数升级时执行幂等更新：

```bash
kb rag chat sync --chat-id <chat-id> --dataset-id <dataset-id> --confirm --json
```

浏览器只请求 BookStack 同源接口 `/api/ai-governance/v2/chat/completions`。BookStack 后端持有 RAGFlow Key，并把 RAGFlow 会话加密绑定到当前 BookStack 用户。

## 5. 验收与切换

至少验证：

1. BookStack 页面发布后 RAGFlow 文档状态从 `UNSTART` 进入解析并最终为 `DONE`。
2. 文档元数据包含当前 `BOOKSTACK_PUBLIC_URL` 下的 `page_url`。
3. A 召回结果可点击返回 BookStack 原文；明确查询芯片或模块时不混入其他已标记领域。
4. 悬浮机器人能连续对话，回答带 BookStack 来源链接，浏览器网络请求中没有 RAGFlow API Key。
5. 断开 B 或 RAGFlow 后，原文阅读和 A 本地手册仍可用，待同步数据不丢失。

全部通过后，替换 `RAGFLOW_DATASET_ID_*`、`RAGFLOW_DEFAULT_DATASET_ID` 和 `RAGFLOW_CHAT_ID`，只重启 A/B 服务。旧 ID 与旧数据集至少保留一个验收周期。

## 6. 回滚

回滚只需恢复旧的数据集 ID 和旧 Chat ID，再重启 A/B。不要删除 `_v2` 数据集，也不要回滚 BookStack 文章数据库。若治理镜像需要回退，先执行既有备份脚本，再切换固定镜像 tag；数据库卷和 `/config` 卷保持不变。
