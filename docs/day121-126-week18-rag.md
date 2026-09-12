# Day 121–126 · 第 18 周索引（RAG 知识库）

桌面：`专用测试环境/39_第18周复盘_RAG知识库.md`  
ADR：桌面 `架构决策/ADR-010-RAG向量库选型.md`

## Day 映射

| Day | 交付 | 状态 |
|-----|------|------|
| 120 | 语料索引 | ✅ [day120](day120-kb-corpus-index.md) / [kb/README](kb/README.md) |
| 121 | 分块与元数据（path/title/week/tags） | ✅ 文档约定 |
| 122 | SQLite FTS 优先方案 | ✅ ADR-010 |
| 123 | 本地嵌入可选路径 | ✅ 文档 |
| 124 | Chroma 可选切换条件 | ✅ ADR-010 |
| 125 | 检索安全：只读、脱敏、拒答密钥 | ✅ |
| 126 | 与诊断 Agent 接口草图 | ✅ 见 Week 20 |

## 管道（目标）

```text
docs/**/*.md + 桌面 ADR/SOP（同步副本或路径映射）
  → chunk + metadata
    → SQLite FTS (± embeddings)
      → query API（只读）
        → MCP / Diagnosis Agent
```

## 非目标

- 不把集群 Secret 当语料  
- 不在本周强制上 Chroma

## 相关

- [day127-133-week19-mcp.md](day127-133-week19-mcp.md)
