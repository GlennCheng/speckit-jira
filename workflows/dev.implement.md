---
description: "讀取 plan + tasks → 按 User Story Phase 逐步實作 → 自動勾選進度 → 更新 Jira"
---

# /dev.implement <TICKET_ID> [--task <TASK_NUMBER>]

## 設計理念

> **整合原生 spec-kit 的 `implement` 指令。**
> 按 `tasks.md` 的 User Story Phase 順序執行。
> MVP 優先：P1 Story 完成後停下來驗證，再繼續 P2。
> 每個 Phase Checkpoint 確保 Story 可獨立運作。

## 概述
此 workflow 協助工程師按 User Story Phase 逐步實作 `tasks.md` 中的任務。AI 會讀取 plan 和 tasks，按 Phase 順序（或指定任務）進行實作，自動更新進度。

## 前置條件
- `tasks.md` 已存在（由 `/dev.tasks` 產出）
- `plan.md` 已存在
- PRD 已存在

---

## 執行步驟

### Step 0: 載入專案設定

#### 0-A: 版本檢查
1. 讀取專案根目錄的 `.speckit-jira-installed`
2. 若不存在 → 提示：`⚠️ 未偵測到 speckit-jira 安裝紀錄。請先執行 ~/speckit-jira/install.sh`
3. 若 `installed_at` 距今超過 30 天 → 提示：`💡 speckit-jira workflow 已安裝 N 天（vX.X.X），建議更新`
4. 不阻擋後續步驟

#### 0-B: 載入設定
1. 讀取 `.speckit-jira.yml`（設定優先權：`.speckit-jira.yml` → `.env` → 預設值）
2. 決定 `$SPEC_ROOT`（同 pm.specify 邏輯）
3. 從 `<TICKET_ID>` 解析 project key，透過 MCP 自動取得 cloudId（若未設定）
2. 讀取 `tasks.md` — 取得任務清單和進度
3. 讀取 `plan.md` — 取得技術方案
4. 讀取 PRD — 取得需求背景
5. 若缺少必要檔案，提示使用者執行對應的前置指令

### Step 1: 選擇要實作的任務
1. 掃描 `tasks.md` 中未完成的任務（`- [ ]`）
2. 若指定了 `--task <TASK_NUMBER>`，直接跳到該任務
3. 否則，按 Phase 分組顯示未完成任務：
   ```
   📋 未完成的任務：

   ━━ Phase 2: Foundational ━━
   1. T003 建立共用 utility (S)

   ━━ Phase 3: User Story 1 🎯 MVP ━━
   2. T005 [P] [US1] 建立 User model (M)
   3. T006 [P] [US1] 建立 API endpoint (M)
   4. T007 [US1] 整合前端 (L)

   ━━ Phase 4: User Story 2 ━━
   5. T008 [P] [US2] 建立報表模組 (S)

   → 建議從 Phase 2 開始（依賴未完成）
   要從哪個任務開始？（輸入編號，或直接 Enter 從建議開始）
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
   ```
   🏁 Phase 3 Checkpoint: User Story 1 🎯 MVP
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ✅ T005 [US1] 建立 User model
   ✅ T006 [US1] 建立 API endpoint
   ✅ T007 [US1] 整合前端

   User Story 1 可獨立驗證：[PRD 中的測試方法]

   建議：停下來驗證 MVP 再繼續。
   (1) 繼續下一個 Phase (User Story 2)
   (2) 停止，先驗證 MVP
   (3) 選擇特定任務
   ```
4. 若所有任務都完成：
   - 更新主 Ticket 狀態為 "Done"（或 "Code Review"）
   - 加上 comment：「所有任務已完成，準備 Code Review」

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
