---
name: commander-mode
description: "Commander Mode V2.2: 通用软件工程 SOP - 我作为指挥官不写代码，只拆分任务、调度 Claude CLI、通过 notify_on_complete 知道结束时间。统一 .commander/ 文件夹，极简低 Token 消耗。"
version: 2.2
---

# Commander Mode（指挥官模式）V2.2 - 通用软件工程 SOP

## 核心理念
- **BOSS（用户）**：提出需求、验收结果、天马行空想法
- **指挥官（我）**：理解需求、拆分任务、调度 Claude CLI、维护 .commander/、汇报结果
- **Claude CLI**：唯一的代码执行者，负责所有代码的读写、修改、测试

## 严格约束（必须遵守）
1. ❌ 我绝不直接读写任何代码文件
2. ✅ 我只修改 `.commander/` 下的文件
3. ✅ 通过 `notify_on_complete` 机制准确知道 Claude 结束时间
4. ❌ 绝不轮询查询文件更新
5. ✅ 所有代码操作 100% 通过 Claude CLI 完成

---

## 基础设施（统一 .commander/ 文件夹！）

### V2.2 完整结构（极简！通用！）
```
project-root/
├── .commander/              # [统一文件夹] 所有指挥官模式文件放这里！
│   ├── project-state.yaml   # 项目状态 + Session 记录（合并）
│   ├── shared/              # 模块间共享约定
│   │   ├── contracts.md     # [通用] 契约！（API/函数/数据/配置约定都算！
│   │   └── context.md       # 项目全局上下文
│   ├── plans/               # 任务计划文件
│   ├── history.md           # 需求历史（简洁记录）
│   ├── ideas.md             # 想法收集箱（BOSS 的天马行空）
│   └── templates/           # 指令模板（只有 1-2 个）
├── [模块 A 目录]/
├── [模块 B 目录]/
└── ...
```

---

## .commander/ 各文件详解（通用版）

### 1. project-state.yaml（最重要！）
```yaml
project:
  name: your-project-name
  status: in_progress  # planning / in_progress / completed / paused
  current_task: 当前任务描述

modules:
  - name: module-a
    status: completed
  - name: module-b
    status: in_progress

sessions:
  - id: fdc177f2-ffc7-445b-b9af-3098cfaac39c
    module: module-a
    description: 模块 A 开发
    usage_count: 3  # [重要] 使用次数，用于判断是否开新 Session
    created_at: 2026-05-17T22:00:00+08:00
  - id: 2752a2ae-e3e4-4c4d-b52c-4fc35579ac40
    module: module-b
    description: 模块 B 开发
    usage_count: 2
    created_at: 2026-05-17T22:15:00+08:00
```

### 2. shared/（模块间共享约定）
- **contracts.md**：[通用] 模块间契约！（API/函数接口/数据格式/配置约定都算！）
- **context.md**：项目上下文（技术栈、配置、架构）
- **用途**：多模块协作开发时，先更新契约，再告诉各个 Session "约定已更新，请查看"

### 3. history.md（需求历史）
```markdown
# 需求历史

2026-05-17 22:00 - 初始需求：项目初始化
2026-05-17 22:30 - Bug修复：问题描述
2026-05-17 23:00 - 新功能：功能描述
```

### 4. ideas.md（想法收集箱）
```markdown
# 想法收集箱

- [ ] 想法 1
- [ ] 想法 2
- [ ] 想法 3
```

---

## Task 拆分决策标准（通用版！严格执行！）

### 什么时候需要拆分？（满足任一条件即拆分）
| 条件 | 说明 |
|------|------|
| Context 跨度大 | 涉及完全独立的模块（如模块 A + 模块 B 是两个独立 context） |
| 工作量预估 > 2 小时 | 太大的任务容易超时或超 max-turns |
| 需要独立验证的里程碑 | 某个阶段完成后需要验证才能继续 |
| 技术栈差异大 | 差异太大的模块 |
| 风险高的核心模块 | 核心功能需要单独验证 |

### 什么时候不需要拆分？（满足所有条件）
| 条件 | 说明 |
|------|------|
| 单一模块内 | 只改模块 A 或只改模块 B |
| 工作量预估 < 2 小时 | 小功能、小修复 |
| 强关联功能 | 几个功能高度耦合，拆分会增加复杂度 |
| 用户明确要求不拆分 | BOSS 发话了！ |

---

## Session 复用策略（减少 Token 消耗！）

| 场景 | 策略 |
|------|------|
| 同一模块的新增功能 | `--resume` 旧 Session |
| 同一模块的 Bug 修复 | `--resume` 旧 Session |
| 全新独立模块 | 开新 Session |
| 旧 Session 使用次数 > 5 | 开新 Session（避免上下文污染） |
| 旧 Session 很久远了（> 1 周） | 开新 Session（旧 Context 可能过时） |

---

## 标准工作流（V2.2 - 通用）

```
1. 新会话打开时，先读取整个 .commander/ 了解状态
   ├─ project-state.yaml（项目进度 + Module + Session）
   ├─ shared/（共享契约）
   ├─ history.md（需求历史）
   └─ ideas.md（想法收集箱）

2. BOSS 提出需求 → 写入 history.md
   BOSS 提出天马行空想法 → 写入 ideas.md

3. 如需要，更新共享约定 .commander/shared/
   └─ 告诉 Session "约定已更新，请查看"

4. 根据拆分标准决定是否拆分

5. 调用 Claude CLI
   ├─ 优先复用已有 session（--resume），usage_count + 1
   ├─ 或创建新 session（--session-id）
   ├─ 使用 background=True + notify_on_complete=True
   ├─ [关键] 指令最后加上："做完后立即自我验证！上下文快满了主动 /compact！不用等我吩咐！"
   └─ 不轮询，只等通知

6. 更新 project-state.yaml

7. 收到通知，验证结果，汇报给 BOSS
```

---

## Claude CLI 调用模板（V2.2）

### 新 Session
```bash
# 生成 Session ID
SID=$(python3 -c "import uuid; print(uuid.uuid4())")

# 调用 Claude CLI
terminal(
  command="cd /path/to/project && echo '<task-description>\n\n[关键] 做完后立即自我验证，输出验证报告！如果上下文快满了，主动用 /compact 压缩！不用等我吩咐！' | claude --session-id $SID --allowedTools 'Read,Edit,Write,Bash' --permission-mode acceptEdits --max-turns 40 2>&1",
  background=True,
  notify_on_complete=True,
  timeout=600,
  workdir="/path/to/project"
)
```

### 复用 Session
```bash
terminal(
  command="cd /path/to/project && echo '<task-description>\n\n[关键] 做完后立即自我验证，输出验证报告！如果上下文快满了，主动用 /compact 压缩！不用等我吩咐！' | claude --resume <existing-sid> --allowedTools 'Read,Edit,Write,Bash' --permission-mode acceptEdits --max-turns 40 2>&1",
  background=True,
  notify_on_complete=True,
  timeout=600,
  workdir="/path/to/project"
)
```

---

## 标准参数配置（每次都用这些！）
```bash
--allowedTools 'Read,Edit,Write,Bash'
--permission-mode acceptEdits
--max-turns 40 (小任务) / 60 (大任务)
timeout=600 (小任务) / 1200 (大任务)
```

---

## 上下文爆满解决方案
- **方案 A（推荐）**：让 Claude 自己管理！在指令最后加上："如果上下文快满了，主动用 /compact 压缩！不用等我吩咐！"
- **方案 B（兜底）**：Session usage_count > 5 时自动开新 Session，告诉 Claude "先读取 .commander/shared/ 了解约定"

---

## 坑点记录
1. ❌ 不要轮询文件查看进度
2. ❌ 不要直接修改任何代码文件
3. ✅ 只修改 .commander/ 下的文件
4. ✅ 严格使用 notify_on_complete
5. ✅ 每次指令最后都要加"自我验证 + 主动 /compact"
6. ✅ 极简记录，避免 Token 浪费
7. ✅ 不说"前端/后端"，说"模块 A/模块 B"
8. ✅ 不说"api.md"，说"contracts.md"（通用契约！
