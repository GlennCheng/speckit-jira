---
description: "讀取 plan + tasks → 按 User Story Phase 逐步實作 → 自動勾選進度 → 更新 Jira"
---

# /specrity.dev.implement <TICKET_ID> [--task <TASK_NUMBER>]

## 設計理念

> **整合原生 spec-kit 的 `implement` 指令。**
> 按 `tasks.md` 的 User Story Phase 順序執行。
> MVP 優先：P1 Story 完成後停下來驗證，再繼續 P2。
> 每個 Phase Checkpoint 確保 Story 可獨立運作。

## 概述
此 workflow 協助工程師按 User Story Phase 逐步實作 `tasks.md` 中的任務。AI 會讀取 plan 和 tasks，按 Phase 順序（或指定任務）進行實作，自動更新進度。

## 前置條件
- `tasks.md` 已存在（由 `/specrity.dev.tasks` 產出）
- `plan.md` 已存在
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
     `⚠️ [Specrity 警告] 偵測到當前會話中包含其他任務的上下文，可能會導致生成的內容錯亂。建議另開全新的 Chat。但若確認是相關任務，可回覆繼續。後續取得 Plan 與任務清單後，我會再次進行深度分析。`
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
4. 讀取 `$SPEC_ROOT/plans/<TICKET_ID>/tasks.md` — 取得任務清單和進度
5. 讀取 `$SPEC_ROOT/plans/<TICKET_ID>/plan.md` — 取得技術方案
6. 讀取 PRD — 取得需求背景
7. 若缺少必要檔案，提示使用者執行對應的前置指令
8. **深度上下文檢測 (Deep Context Sanity Check)**：
   - AI 必須對比「剛剛載入的任務清單 / Plan 內容」與「先前的對話歷史記錄」。
   - 如果發現歷史對話與本次實作任務**完全無關甚至衝突**，必須中斷流程並拒絕推進：
     `❌ [Specrity 錯誤] 深度分析發現歷史對話與本次實作任務存在明顯衝突。強烈建議您開啟一個「全新乾淨的 Chat」後重新執行指令，以免實作時發生幻覺或改錯程式碼。`
   - 除非使用者強行命令略過，否則停留在此階段。
9. **強制執行 MCP Jira 更新**（在進入選擇任務對話之前，且僅在第一次執行時或有指定任務階段時發送）：
   ```
   使用 MCP tool: addCommentToJiraIssue
   參數: cloudId = $JIRA_CLOUD_ID, issueIdOrKey = <TICKET_ID>, commentBody = "🤖 [Specrity] 🚀 程式碼實作（Implementation）階段已開始"
   ```

### Step 1: 選擇要實作的任務
1. 掃描 `tasks.md` 中未完成的任務（`- [ ]`）
2. 若指定了 `--task <TASK_NUMBER>`，直接跳到該任務
3. 否則，使用 **Modern Dashboard (現代卡片)** 風格，按 Phase 分組顯示未完成任務：
   ```markdown
   > 🚀 **Specrity Implementation Dashboard** | <TICKET_ID>
   > ──────────────────────────────────────────────────
   > 📋 **未完成的任務清單：**
   > 
   > 🔹 **Phase 2: Foundational**
   >   - [ ] 1. T003 建立共用 utility (S)
   > 
   > 🔹 **Phase 3: User Story 1 🎯 MVP**
   >   - [ ] 2. T005 [P] [US1] 建立 User model (M)
   >   - [ ] 3. T006 [P] [US1] 建立 API endpoint (M)
   > 
   > ──────────────────────────────────────────────────
   > 👉 **系統建議從 [Phase 2 - 1. T003] 開始**（因其後續依賴尚未完成）。
   > 
   > 💬 *請輸入任務編號開始實作，或直接按 `Enter` 接受建議。*
   ```
4. 確認要實作的任務（檢查依賴是否已完成，若未完成則警告）

### Step 2: 實作任務
1. 讀取該任務的完成條件和技術方案
2. 分析相關程式碼
3. 逐步實作：
   - 建立/修改必要的檔案
   - 撰寫測試（若適用）
   - 確認符合完成條件
4. 每完成一個子步驟，在聊天中回報進度

### Step 3: 驗證完成
1. 執行相關測試（若有）
2. 確認所有完成條件都已滿足
3. 詢問工程師確認：
   ```
   ✅ Task N: <title> 已完成。
   完成條件確認：
   - [x] <criteria 1>
   - [x] <criteria 2>

   要標記為完成嗎？
   ```

### Step 4: 更新進度
1. 更新 `tasks.md`：將該任務的 `- [ ] 完成` 改為 `- [x] 完成`
2. 若 Jira MCP 可用：
   - 在對應的 Sub-task 加 comment：「實作已完成」
   - Transition Sub-task 狀態為 "Done"
   - 在主 Ticket 加 comment：
     ```
     ✅ Task N: <title> 已完成
     進度：M/N 任務完成
     ```
3. 若當前 Phase 的所有任務都完成，觸發 **Phase Checkpoint**：
   ```markdown
   > 🏁 **Phase Checkpoint** | Phase 3: User Story 1 🎯 MVP
   > ──────────────────────────────────────────────────
   > ✅ T005 [US1] 建立 User model
   > ✅ T006 [US1] 建立 API endpoint
   > ✅ T007 [US1] 整合前端
   > 
   > 💡 **User Story 1 已可獨立驗證：**
   > [在此列出 PRD 中對於此 Story 的測試情境]
   > 
   > ──────────────────────────────────────────────────
   > 👉 **強烈建議**：停下來執行本機測試與驗證 MVP 後，再繼續開發。
   > 
   > 💬 *下一步： (1) 繼續下一個 Phase / (2) 停止，先去驗證 MVP / (3) 指定任務*
   ```
4. 若所有任務都完成：
   - 更新主 Ticket 狀態為 "Done"（或 "Code Review"）
   - 在 Jira 加上 comment：
     ```markdown
     > 🤖 **[Specrity] 任務全數實作完成**
     > ──────────────────────────────────────────────────
     > 🎉 所有的 Sub-tasks 與 Tasks 皆已打勾。
     > 已經準備好進入 Code Review 或測試驗證階段。
     ```

### Step 5: 詢問下一步
1. 顯示剩餘未完成任務（按 Phase 分組）
2. 詢問：
   ```
   還有 N 個任務未完成。
   (1) 繼續下一個任務
   (2) 選擇特定任務
   (3) 結束（稍後繼續）
   ```

---

## Jira 降級處理

若 Atlassian MCP Server 連線失敗：

```
⚠️ 無法連接 Jira MCP Server。
tasks.md 進度已更新，但 Jira 狀態需要手動更新。

以下 Sub-tasks 需要手動更新為 Done：
- <SUB-TASK-ID>: <task title>
```

---

## 預期產出
- 實作的程式碼變更
- 更新後的 `tasks.md`（勾選完成的任務）
- Jira Sub-task 更新（若 MCP 可用）
- Jira 主 Ticket 進度更新
