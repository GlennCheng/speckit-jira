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
此 workflow 協助工程師將 `plan.md` 拆解為具體、可執行的任務清單。參照 `.specrity/templates/tasks-template.md` 產出 `tasks.md`，並為每個任務在 Jira 建立 Sub-task。

## 前置條件
- `plan.md` 已存在（由 `/specrity.dev.plan` 產出）
- PRD 已存在

---

## 執行步驟

### Step 0: 載入專案設定

#### 0-A: 開場與初步上下文檢查 (Initialization & Context Check)
1. **印出歡迎橫幅**：一旦收到此指令，**第一句話**必須使用 Markdown 的 `text` 區塊，印出以下 ASCII Banner：
   ```text
      ____                  _ __       
     / __/___  ___ ________(_) /___ __ 
    _\ \/ _ \/ -_) __/ __/ / __/ // /  
   /___/ .__/\__/\__/_/ /_/\__/\_, /   
      /_/                     /___/    
   ```
2. **上下文檢測 (Context Sanity Check)**：
   - AI 掃描目前對話視窗 (Session) 的對話記錄。
   - 若發現記憶體中混雜了「其他 Ticket 或不相干任務」的上下文，必須暫停並警告：
     `⚠️ [Specrity 警告] 偵測到當前會話中包含其他任務的上下文，可能會導致生成的內容錯亂。建議另開全新的 Chat。但若確認是相關任務，可回覆繼續。後續取得 Plan 與 PRD 內容後，我會再次進行深度分析。`
   - 等待使用者確認。若上下文乾淨，則印出 `✅ Context check passed.` 並繼續。

#### 0-B: 版本檢查
1. 讀取專案根目錄的 `.specrity-installed`
2. 若不存在 → 提示：`⚠️ 未偵測到 specrity 安裝紀錄。請先執行 ~/specrity/install.sh`
3. 若 `installed_at` 距今超過 30 天 → 提示：`💡 specrity workflow 已安裝 N 天（vX.X.X），建議更新`
4. 不阻擋後續步驟

#### 0-C: 載入設定
1. **強制讀取 `.specrity/.specrity.yml`**（設定優先權：`.specrity/.specrity.yml` → `.env` → 預設值）
2. 決定 `$SPEC_ROOT`（同 pm.specify 邏輯：必須確實解析 config，若為 submodule 需比對 `.gitmodules`，**絕對禁止猜測路徑**）
3. 從 `<TICKET_ID>` 解析 project key，透過 MCP 自動取得 cloudId（若未設定）
4. 讀取 `plan.md` 和 PRD
   - 讀取 `$SPEC_ROOT/plans/<TICKET_ID>/plan.md`
   - 讀取 `$SPEC_ROOT/drafts/<TICKET_ID>/prd.md`（或正式 PRD）
5. 若 `plan.md` 不存在，提示使用者先執行 `/specrity.dev.plan <TICKET_ID>`
6. **深度上下文檢測 (Deep Context Sanity Check)**：
   - AI 必須對比「剛剛載入的 Plan / PRD 內容」與「先前的對話歷史記錄」。
   - 如果發現歷史對話與本次任務**完全無關甚至衝突**，必須中斷流程並拒絕推進：
     `❌ [Specrity 錯誤] 深度分析發現歷史對話與本次任務存在明顯衝突。強烈建議您開啟一個「全新乾淨的 Chat」後重新執行指令，以免拆解任務時發生幻覺。`
7. **強制執行 MCP Jira 更新**（在開始拆解任務之前）：
   > **[CRITICAL INSTRUCTION TO AI]**: 透過 MCP 執行 `addCommentToJiraIssue` 時，`commentBody` 參數 **MUST EXACTLY MATCH (必須完全一致，不可改寫)** 雙引號內的內容：
   ```
   使用 MCP tool: addCommentToJiraIssue
   參數: cloudId = $JIRA_CLOUD_ID, issueIdOrKey = <TICKET_ID>, commentBody = "🤖 [Specrity] 🏗️ 任務拆解（Tasks Breakdown）階段已開始"
   ```

### Step 1: 拆解任務（按 User Story 組織）

1. **必須實際讀取 Template 檔案**：使用檔案讀取工具，去讀取 `$PROJECT_ROOT/.specrity/.specrity/templates/tasks-template.md` 的完整內容作為結構參照
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

1. 參照前一步取得的 `.specrity/templates/tasks-template.md` 內容產出 `tasks.md`
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
   > **[CRITICAL INSTRUCTION TO AI]**: 透過 MCP 執行 `addCommentToJiraIssue` 時，`commentBody` 參數 **MUST STRICTLY FOLLOW (必須嚴格遵守)** 以下 Modern Dashboard 風格排版：
   ```markdown
   > 🤖 **[Specrity] Tasks Breakdown 已建立**
   > ──────────────────────────────────────────────────
   > 📋 **任務分析摘要：**
   > - 總計：N 個任務拆解完畢
   > - Phase 1 (Setup): N 個任務
   > - Phase 2: N 個任務
   > 
   > 🔗 **Jira Sub-tasks 已同步建立：** <SUB-TASK-IDs>
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
