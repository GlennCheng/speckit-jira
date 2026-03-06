---
description: "工程師讀取 PRD → 分析程式碼 → 偵測缺陷（迴圈） → 產出 plan.md 實作計畫（整合 analyze 一致性檢查）"
---

# /specrity.dev.plan <TICKET_ID>

## 設計理念

> **此流程專為工程師設計。技術決策在此階段進行。**
> RD 基於 PM 產出的 PRD 做技術分析與規劃。
> 整合原生 spec-kit 的 `plan` + `analyze` 兩個指令：
> - **plan**：技術選型、架構設計、實作步驟
> - **analyze**：PRD ↔ plan 一致性檢查、覆蓋率驗證
> 若 PRD 有缺陷，**RD 主動回報 PM**，而非自行假設。

## 概述
此 workflow 協助工程師基於 PRD 產出技術實作計畫。AI 會分析現有程式碼庫，進行技術研究（`research.md`）、資料模型定義（`data-model.md`）、偵測 PRD 缺陷（支援跨 Session 持久化的迴圈），最終參照 `.specrity/templates/plan-template.md` 產出 `plan.md`。

## 前置條件
- PRD 已存在（由 `/specrity.pm.specify` 產出）

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
     `⚠️ [Specrity 警告] 偵測到當前會話中包含其他任務的上下文，可能會導致生成的內容錯亂。建議另開全新的 Chat。但若確認是相關任務，可回覆繼續。後續取得 PRD 內容後，我會再次進行深度分析。`
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

### Step 1: 狀態偵測（State Detection）

檢查 `$SPEC_ROOT/plans/<TICKET_ID>/` 是否存在：

#### 情況 A：不存在 → NEW 模式
1. 尋找 PRD：
   - 優先檢查 feature branch 上的正式 PRD
   - 若無，檢查 `drafts/<TICKET_ID>/prd.md`
   - 若都沒有，嘗試從 Jira 取得（降級模式）
2. 若完全找不到 PRD，提示使用者先執行 `/specrity.pm.specify <TICKET_ID>`
3. 建立 `plans/<TICKET_ID>/` 目錄，初始化：
   ```
   plans/<TICKET_ID>/
   ├── state.yml           # phase: researching, analyze_rounds: 0
   ├── analyze-log.md      # 缺陷偵測紀錄
   ├── research.md         # 技術研究紀錄（Step 2-B 產出）
   └── data-model.md       # 資料模型定義（Step 2-C 產出）
   ```
4. **強制執行 MCP Jira 更新**（在開始研究與分析之前）：
   > **[CRITICAL INSTRUCTION TO AI]**: 透過 MCP 執行 `addCommentToJiraIssue` 時，`commentBody` 參數 **MUST EXACTLY MATCH (必須完全一致，不可改寫)** 雙引號內的內容：
   ```
   使用 MCP tool: addCommentToJiraIssue
   參數: cloudId = $JIRA_CLOUD_ID, issueIdOrKey = <TICKET_ID>, commentBody = "🤖 [Specrity] 🛠️ 技術分析與實作計畫（Plan）階段已開始"
   ```

#### 情況 B：存在 + `phase: analyzing` → RESUME 模式
1. 讀取 `state.yml` → 知道上次分析到哪
2. 讀取 `analyze-log.md` → 載入過去的缺陷紀錄和 PM 回應
3. 比對 PRD 是否已更新（與上次快照比對）
4. 顯示恢復摘要：
   ```
   📋 恢復 HTGO2-123 的計畫流程
   - 已進行 N 輪 Analyze
   - 上次發現 M 個缺陷
   - PRD 自上次已更新 ✅ / 未更新 ⏳
   ```

#### 情況 C：存在 + `phase: completed` → 已完成
1. 提示 plan.md 已存在
2. 詢問：(1) 查看現有 plan  (2) 重新分析（覆蓋）

### Step 2: 讀取 PRD + 技術研究

#### 2-A: 讀取 PRD 與程式碼分析
1. 讀取 PRD 完整內容
2. 從 Jira 取得最新 Ticket 資訊（MCP tool: `getJiraIssue`）
3. **深度上下文檢測 (Deep Context Sanity Check)**：
   - AI 必須對比「剛剛載入的 PRD / Ticket 內容」與「先前的對話歷史記錄」。
   - 如果發現歷史對話中的任務需求、架構討論，**與本次 PRD 完全無關甚至衝突**（AI 判斷將導致嚴重的幻覺或資訊混亂），必須中斷流程並拒絕推進：
     `❌ [Specrity 錯誤] 深度分析發現歷史對話與本次 PRD 任務存在明顯衝突。強烈建議您開啟一個「全新乾淨的 Chat」後重新執行指令，以避免實作計畫失真。`
   - 除非使用者強行命令略過，否則停留在此階段。
4. 比對 PRD 與 Jira 一致性，若有差異則提醒
4. 掃描專案結構，識別相關模組
5. 找出會被影響的檔案和函式
6. 識別可能的技術風險和依賴項

#### 2-B: 技術研究（Research）

對於 PRD 涉及的技術選型，進行研究並記錄決策：

1. 識別需要決策的技術問題（框架、API 設計、資料流等）
2. 為每個問題列出選項、優缺點、推薦選擇
3. 產出 `research.md`：
   ```markdown
   # Technical Research: <feature name>

   ## Decision 1: [topic]
   **Context**: [why this decision is needed]
   **Options**:
   - A: [option] — pros / cons
   - B: [option] — pros / cons
   **Decision**: [chosen option]
   **Rationale**: [why]
   ```
4. 更新 `state.yml`：`phase: modeling`

#### 2-C: 資料模型定義（Data Model）

若此 feature 涉及資料變更：

1. 從 PRD requirements 提取實體（entities）
2. 定義欄位、關聯、約束
3. 產出 `data-model.md`：
   ```markdown
   # Data Model: <feature name>

   ## Entities
   ### [Entity Name]
   - field_1: type — description
   - field_2: type — description
   
   ## Relationships
   - [Entity A] 1:N [Entity B]

   ## State Transitions (if applicable)
   [State A] → [Event] → [State B]
   ```
4. 更新 `state.yml`：`phase: analyzing`

若此 feature 不涉及資料變更，跳過此步驟，`data-model.md` 可留空或標記 N/A。

### Step 3: 缺陷偵測 + 一致性檢查（Analyze Loop）

整合原生 spec-kit 的 `analyze` 指令。類似 `/specrity.pm.specify` 的 Clarify 迴圈，支援跨 Session 持久化。

#### 偵測項目（PRD 缺陷與待評估事項）
- 缺少接受標準（Acceptance Criteria）
- 邏輯矛盾（功能 A 和功能 B 衝突）
- 技術不可行（現有架構不支持）
- 缺少邊界條件（大量資料、併發、錯誤處理）
- 安全性考量缺失（權限、資料保護）
- API 規格不完整（缺少 request/response 定義）
- **[NEEDS RCA] 標記**：若 PRD 有 `[NEEDS RCA]` 標記（如：需評估解法建議是否合適），需進行技術分析並決定最佳解法

#### 一致性檢查（整合自原生 analyze）

| 檢查維度 | 說明 |
|---------|------|
| **Coverage** | 每個 FR 是否都有對應的實作步驟？ |
| **術語一致性** | PRD vs research vs data-model 用詞是否統一？ |
| **矛盾偵測** | PRD 和技術研究有無衝突？ |
| **模糊偵測** | plan 中有無未量化的模糊詞（「快速」、「穩定」）？ |
| **依賴分析** | 外部服務/API 的失敗模式是否考慮？ |

#### 迴圈流程
```
偵測缺陷 → 有缺陷？
             │
             ├── 否 → 跳到 Step 4（產出 plan.md）
             │
             └── 是 → 整理缺陷清單
                        │
                        ▼
                  寫入 analyze-log.md（持久化！）
                        │
                        ▼
                  詢問工程師：
                  (1) 僅標註在 plan 中（不阻擋，繼續產 plan）
                  (2) 回報 PM 並等待修改（進入等待狀態）
                        │
                  ┌─────┴──────┐
                  ▼            ▼
            標註在 plan    Jira Comment 回報 PM
            → Step 4       → 更新 state.yml
                             phase: waiting_pm
                           → 提示工程師：
                             「已回報 PM，PM 修改 PRD 後
                              請重新執行 /specrity.dev.plan HTGO2-123」
                           → 結束（等 PM 改完再 Resume）

（PM 修改 PRD 後，工程師重新執行 /specrity.dev.plan）
  → 進入 RESUME 模式
  → 偵測到 PRD 已更新
  → 重新分析（Analyze Round 2）
  → 確認缺陷已修復 → Step 4
```

#### 持久化檔案
```
plans/<TICKET_ID>/
├── state.yml
│     phase: analyzing | waiting_pm | completed
│     analyze_rounds: 2
│     last_prd_hash: abc123
│     defects_found: 3
│     defects_resolved: 2
│
├── analyze-log.md
│     ## Round 1 (2026-03-03)
│     ### 發現的缺陷
│     1. ⚠️ 缺少並發處理的邊界條件
│     2. ⚠️ API response 格式未定義
│     ### 處理方式：回報 PM
│     ### PM 回應：已更新 PRD（2026-03-04）
│
│     ## Round 2 (2026-03-05)
│     ### 重新分析
│     1. ✅ 並發處理已補充
│     2. ✅ API response 已定義
│     ### 結果：所有缺陷已解決
│
└── plan.md  ← Step 4 完成後才產出
```

### Step 4: 產出 plan.md

1. **必須實際讀取 Template 檔案**：使用檔案讀取工具，去讀取 `$PROJECT_ROOT/.specrity/.specrity/templates/plan-template.md` 的完整內容，作為結構參照
2. 基於 PRD、research.md、data-model.md、程式碼分析、和缺陷偵測結果，填充 template
3. 確保 plan 中的每個實作步驟都能追溯到 PRD 的 FR
4. 儲存 `plan.md` 到 `plans/<TICKET_ID>/plan.md`
5. 更新 `state.yml`：`phase: completed`
6. 展示 plan.md 給工程師確認

### Step 5: 更新 Jira
1. 在 Jira 加上 comment：「Implementation Plan 已建立」
2. 若可用，更新 Jira 狀態為 "Planning"
3. 告知工程師結果

---

## Jira 降級處理

若 Atlassian MCP Server 連線失敗：

```
⚠️ 無法連接 Jira MCP Server。
請手動提供 PRD 內容：

（貼上 PRD markdown 後按 Enter 繼續）
```

跳過 Jira 更新步驟，僅產出 plan.md。

---

## 預期產出

```
plans/<TICKET_ID>/
├── state.yml           # 狀態追蹤
├── analyze-log.md      # 缺陷偵測紀錄（跨 Session 持久化）
├── research.md         # 技術研究紀錄
├── data-model.md       # 資料模型定義
├── contracts/          # API 規格（選擇性）
└── plan.md             # 技術實作計畫（參照 plan-template）
```

- Jira comment（若 MCP 可用）
- PRD 缺陷報告（若有發現）

