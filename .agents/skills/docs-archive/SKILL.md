---
name: docs-archive
description: >
  Use this skill whenever the user wants to archive, distill, or save the current conversation's content for future reference.
  TRIGGER on: requests to 归档/提炼/存档 the conversation; requests to save (存一下/存下来/保存) discussion findings, error corrections, lessons learned, or project context from the chat; end-of-session requests to preserve valuable knowledge discovered during the conversation; requests mentioning 总结对话/归档本次对话/提炼本次对话/保存到记忆/踩坑记录/经验教训.
  This skill extracts conversation-derived insights (corrections, user feedback, project background) and writes structured .md files to the project's docs/archive/ directory with numbered naming and index.md index.
  Do NOT trigger for: writing standalone docs/READMEs/tech specs, PR reviews, code fixes, or creating new skills.
---

# docs-archive: 对话提炼归档技能

## 核心目标

将当前会话中有价值的内容提炼成结构化的 Markdown 存档，供后续对话参考复用。遵循**优先覆盖/更新同类型已有内容，其次才新建**的原则。

## 适用场景

- 用户明确要求"归档"、"提炼"、"存档"、"总结对话"、"保存到记忆"
- 用户希望保留本次对话中的经验教训、背景知识
- 长时间工作后希望提炼有价值的内容

## 项目目录检测

**目标目录通过动态检测获取**：

1. 从当前会话上下文中获取工作目录（AI 会话中为项目根目录）
2. 目标目录 = `<工作目录>/docs/archive/`
3. 如果 `docs/archive/` 目录不存在，先创建它

**注意**：此 skill 设计为项目级别使用，每个项目有独立的 `docs/archive/` 目录存放归档文件。不同项目的归档互不干扰。

## 三类提炼目标

### A. 错误纠正 (correction)
**来源**：AI 犯错后被纠正，之后正常运行的内容。

**提炼要点**：
- 场景：什么情况下犯了什么错（高层描述，不贴代码）
- 错误做法：之前错误的动作/方法（描述意图，不贴代码片段）
- 正确做法：纠正后的正确动作/方法（描述意图，不贴代码片段）
- 需求：从中得出的设计原则或约束（可被后续复用）

### B. 用户主动纠错 (user-feedback)
**来源**：用户主动纠正 AI 的行为、偏好、做法，纠错后 AI 的行为符合用户预期。

**提炼要点**：
- 场景：在什么上下文中用户进行了纠错
- 用户预期：用户期望 AI 如何表现/回应
- 需求：基于纠错得出的用户偏好或工作方式（规则化表述）

### C. 项目背景 (context)
**来源**：用户在不同时间点为问题补充的项目模块背景、架构说明、技术栈、团队约定等。

**提炼要点**：
- 场景：这个背景在什么情况下会被用到（帮助判断何时检索这条记忆）
- 需求：模块要解决什么问题，核心设计意图是什么
- 关键约束：重要的设计决策或限制条件（不展开代码细节）

## 执行流程

### Step 1: 检测项目目录并读取对话历史

1. 从当前会话上下文获取工作目录（项目根目录）
2. 确定目标目录：`<工作目录>/docs/archive/`，如不存在则创建
3. 从当前会话中提取所有用户消息和助手回复，构建完整的对话上下文

### Step 2: 提炼内容

对每一段对话进行分类识别：

1. **先搜索现有存档**：读取 `docs/archive/index.md` 索引，了解已有哪些存档文件
2. **逐一判断**：对每段有价值的内容，判断属于哪一类（A/B/C）
3. **判断覆盖还是新建**：
   - 如果某条新归档的内容与已有存档**主题相关且可合并**（如同样的错误类型），则追加到已有文件
   - 如果是全新主题，则新建文件
4. **生成结构化内容**：按各类型的模板格式写入

### Step 3: 编号生成规则

**文件编号**：在 `docs/archive/` 目录下维护一个 `__counter__` 文件（纯文本，只含一个整数），记录当前最大编号。每次新建文件时读取后递增，生成 `correction_001.md`、`user-feedback_002.md`、`context_003.md` 这样的文件名。

**编号格式**：
- `correction_<NNN>.md` — 错误纠正，3 位序号
- `user-feedback_<NNN>.md` — 用户主动纠错，3 位序号
- `context_<NNN>.md` — 项目背景，3 位序号

**示例**：`correction_001.md`、`user-feedback_002.md`、`context_003.md`、`correction_004.md`（序号在同类型内递增，不同类型各自独立计数）

### Step 4: 写入存档文件

目标目录：`<当前工作目录>/docs/archive/`

文件命名：`{type}_{NNN}.md`（type 为 correction/user-feedback/context，NNN 为 3 位序号）

每个文件的头部 frontmatter：
```markdown
---
name: <名称>
description: <一句话描述>
type: correction | user-feedback | context
created: <ISO日期时间>
updated: <ISO日期时间>
---
```

### Step 5: 更新索引

读取现有 `index.md`，在对应分类下追加新条目。条目按时间顺序排列。

**index.md 格式**：
```markdown
# Archive Index

## corrections
- [correction_001.md](correction_001.md) — <description>

## user-feedbacks
- [user-feedback_002.md](user-feedback_002.md) — <description>

## contexts
- [context_003.md](context_003.md) — <description>
```

## 写入模板

### correction 模板
```markdown
---
name: <名称>
description: <一句话描述>
type: correction
created: <ISO日期时间>
updated: <ISO日期时间>
---

# 错误纠正

## 场景
<什么情况下犯了什么错>

## 错误做法
<描述错误的动作/方法意图，不贴代码>

## 正确做法
<描述正确的动作/方法意图，不贴代码>

## 需求
<设计原则或约束，供后续复用>
```

### user-feedback 模板
```markdown
---
name: <名称>
description: <一句话描述>
type: user-feedback
created: <ISO日期时间>
updated: <ISO日期时间>
---

# 用户主动纠错

## 场景
<什么上下文中进行了纠错>

## 用户预期
<用户期望 AI 如何表现/回应>

## 需求
<用户偏好或工作方式，规则化表述>
```

### context 模板
```markdown
---
name: <名称>
description: <一句话描述>
type: context
created: <ISO日期时间>
updated: <ISO日期时间>
---

# 项目背景

## 场景
<这个背景在什么情况下会被用到>

## 需求
<模块要解决什么问题，核心设计意图>

## 关键约束
<重要的设计决策或限制条件，不展开代码细节>
```

## 关键原则

1. **优先覆盖/更新**：同类型已有存档存在且主题相关时，追加到同类文件中而非新建。文件内部按时间顺序追加新条目，每个条目以 `---` 分隔。
2. **编号驱动命名**：使用全局递增编号代替主题命名，避免文件名冲突，也使顺序可追溯。
3. **抽象化表述**：归档内容只讲"做什么、为什么"，不讲具体代码或对话片段。便于未来 AI 在新场景中复用原则，而非复制粘贴代码。
4. **内容为王**：只有真正有价值的内容才归档——错误纠正要有明确结论，用户纠错要有清晰偏好，背景介绍要有实际复用价值。
5. **时间戳**：创建时写入 `created` 字段，每次更新只更新 `updated` 字段。
6. **场景驱动**：每条归档优先描述"何时会用到这条记忆"，而非"当时发生了什么"。
7. **项目隔离**：不同项目的 `docs/archive/` 目录完全独立，互不干扰。
