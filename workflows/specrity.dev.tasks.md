---
description: "讀取 plan + spec → 按 User Story 拆解為具體任務 → 產出 tasks.md → 建立 Jira Sub-tasks"
---

# /specrity.dev.tasks <TICKET_ID>

## 設計理念

> **整合原生 spec-kit 的 `tasks` + `taskstoissues` 兩個指令。**
> 任務按 **User Story** 組織，每個 Story 可獨立實作和測試。
> 採用 `T001 [P] [US1]` 統一格式，自動建立 Jira Sub-tasks 並回填 ID。
> MVP 優先：P1 User Story 先做，驗證後再做 P2、P3。

## 概述
此 workflow 協助工程師將 `plan.md` 拆解為具體、可執行的任務清單。參照 `templates/tasks-template.md` 產出 `tasks.md`，並為每個任務在 Jira 建立 Sub-task。

## 前置條件
- `plan.md` 已存在（由 `/specrity.dev.plan` 產出）
- PRD 已存在

---

## 執行步驟

### Step 0: 載入專案設定

#### 0-A: 版本檢查
1. 讀取專案根目錄的 `.specrity-installed`
2. 若不存在 → 提示：`⚠️ 未偵測到 specrity 安裝紀錄。請先執行 ~/specrity/install.sh`
3. 若 `installed_at` 距今超過 30 天 → 提示：`💡 specrity workflow 已安裝 N 天（vX.X.X），建議更新`
4. 不阻擋後續步驟

#### 0-B: 載入設定
1. 讀取 `.specrity.yml`（設定優先權：`.specrity.yml` → `.env` → 預設值）
2. 決定 `$SPEC_ROOT`（同 pm.specify 邏輯）
3. 從 `<TICKET_ID>` 解析 project key，透過 MCP 自動取得 cloudId（若未設定）
4. 讀取 `plan.md` 和 PRD
2. 讀取 `plan.md`
3. 讀取 PRD（作為需求參考）
4. 若 `plan.md` 不存在，提示使用者先執行 `/specrity.dev.plan <TICKET_ID>`

### Step 1: 拆解任務（按 User Story 組織）

1. **必須實際讀取 Template 檔案**：使用檔案讀取工具，去讀取 `$SPEC_ROOT/templates/tasks-template.md` 的完整內容作為結構參照
2. 讀取 PRD 的 User Stories（取得 Priority 和 Acceptance Scenarios）
3. 讀取 `plan.md` 的實作步驟
4. 按以下 Phase 結構組織任務：

   | Phase | 內容 | 依賴 |
   |-------|------|------|
   | **Setup** | 專案初始化、基礎結構 | 無 |
   | **Foundational** | 所有 Story 共用的基礎設施 | Setup |
   | **User Story 1** (P1 🎯 MVP) | P1 的實作任務 | Foundational |
   | **User Story 2** (P2) | P2 的實作任務 | Foundational |
   | **Polish** | 跨 Story 的優化 | 所有 Story |

5. 每個任務應包含：
   - **ID + 標記**：`T001 [P] [US1]`（P = 可平行，US1 = User Story 1）
   - 清晰的標題（含檔案路徑）
   - 完成條件
   - 預估複雜度（S/M/L）
   - 依賴關係（哪些任務要先完成）

### Step 2: 產出 tasks.md

1. 參照前一步取得的 `templates/tasks-template.md` 內容產出 `tasks.md`
2. 確保：
   - 每個 User Story Phase 有 **Checkpoint**（可獨立驗證）
   - 每個 task 都能追溯到 PRD 的 FR 或 User Story
   - **MVP 策略**：P1 Story 完成後可獨立部署驗證
   - 任務順序反映 Dependency graph
3. 儲存到 `plans/<TICKET_ID>/tasks.md`
4. 展示給工程師確認

### Step 3: 建立 Jira Sub-tasks（若 MCP 可用）
1. 取得 Jira 可用的 issue types：
   ```
   使用 MCP tool: getJiraProjectIssueTypesMetadata
   參數: projectIdOrKey = $JIRA_PROJECT_KEY
   ```
2. 對每個 Task 建立 Sub-task：
   ```
   使用 MCP tool: createJiraIssue
   參數:
     projectKey = $JIRA_PROJECT_KEY
     issueTypeName = "Sub-task"
     parent = <TICKET_ID>
     summary = <task title>
     description = <completion criteria>
   ```
3. 將建立的 Sub-task ID 回填到 `tasks.md` 中
4. 儲存更新後的 `tasks.md`

### Step 4: 更新 Jira 主 Ticket
1. 在主 Ticket 加上 comment：
   ```
   📋 Tasks breakdown 已建立：
   - 共 N 個任務
   - Phase 1: N 個任務
   - Phase 2: N 個任務
   - Sub-tasks 已建立：<SUB-TASK-IDs>
   ```
2. 若可用，更新 Jira 狀態為 "Task Review"
3. 告知工程師結果

---

## Jira 降級處理

若 Atlassian MCP Server 連線失敗：

```
⚠️ 無法連接 Jira MCP Server。
Sub-tasks 將不會自動建立。
tasks.md 已產出，你可以手動在 Jira 建立 Sub-tasks。
```

僅產出 `tasks.md`，跳過 Jira Sub-task 建立。

---

## 預期產出
- `tasks.md` — 具體任務清單（含完成條件、複雜度、依賴）
- Jira Sub-tasks（若 MCP 可用）
- Jira comment 摘要
