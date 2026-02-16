# RID3510 聊天：Context Caching 與 Redis 10 輪對話

本文件說明若要為 RID3510 聊天服務加上 **Gemini Context Caching**（正確回應、降低成本）與 **Redis 紀錄 10 輪對話**，您需要協助的事項與實作要點。

---

## 一、目前狀態

| 項目 | 現況 |
|------|------|
| API | `POST /stage1/reply` 或 `POST /api/rid3510/reply`，body: `{ "message": "使用者輸入" }` |
| 回覆流程 | 意圖辨識 → 知識庫 context → **單次** Gemini `generateContent`（無歷史） |
| 對話識別 | 無；每次請求獨立，不帶 session / conversation_id |
| Redis | 專案內**未使用** Redis（Gemfile 無 redis，deploy/CI 中 Redis 為註解） |
| Context Caching | 未使用；每通請求都重新傳入完整知識庫文字 |

---

## 二、您需要協助的事項

### 1. Redis 服務與連線

- **提供 Redis 連線方式**  
  - 本機開發：若已有 Redis，請提供連線字串（例如 `redis://localhost:6379/0`）。  
  - 雲端（與現有 GCP 部署一致）：是否已有 **Cloud Memorystore (Redis)** 或打算使用 **Redis Cloud / 其他託管 Redis**？  
- **環境變數**  
  - 約定名稱：`REDIS_URL`（例如 `redis://localhost:6379/0` 或 `redis://:password@host:6379/0`）。  
  - 若暫無 Redis：可先以「僅多輪對話邏輯 + 記憶體暫存」實作，之後再接上 Redis（介面預留）。

**需要您回覆：**  
- [x] 本機可忽略；直接上雲。  
- [x] 使用 **GCP Cloud Memorystore**，依 [docs/23-GCP-CLOUD-MEMORYSTORE-REDIS.md](23-GCP-CLOUD-MEMORYSTORE-REDIS.md) 申請與設定；環境變數 `REDIS_URL=redis://IP:6379/0`（有 AUTH 時 `redis://:AUTH@IP:6379/0`）。

---

### 2. 對話識別（conversation_id）

多輪對話需要「同一對話」的識別碼：

- **方案 A（建議）**：由 **客戶端** 產生並傳遞  
  - 請求 body 改為可選帶 `conversation_id`，例如：  
    `{ "message": "使用者輸入", "conversation_id": "optional-uuid-or-string" }`  
  - 若客戶端未帶，後端產生一組並在回應中回傳，例如：  
    `{ "reply": "...", "intent": "...", "conversation_id": "新產生的 id" }`  
  - 網頁 `/rid3510/chat`、LINE/Make 等呼叫端之後同一對話都帶同一個 `conversation_id`。

- **方案 B**：由後端用 **session 或 cookie** 推導  
  - 僅適用於「同一瀏覽器、同一 session」的網頁；LINE/Make 等無 cookie，需另訂識別方式（例如 LINE userId + 某 thread 識別）。

**需要您回覆：**  
- [x] **同意**方案 A：客戶端可選帶 `conversation_id`，未帶則後端產生並在回應中回傳。

---

### 3. Context Caching（Gemini）

- **目的**：把「系統提示 + 知識庫內容」做成快取，重複請求時不用再傳一次大段文字，可正確回應又降成本。  
- **實作要點**：  
  - 使用 Gemini `cachedContents.create` 建立快取（內容為：系統提示 + 日期對齊說明 + 知識庫文字）。  
  - 可依 **意圖** 建多個 cache（例如每個意圖一份），或先做一個「fallback + 常用意圖合併」的單一 cache。  
  - `generateContent` 時改為帶 `cachedContent` 名稱，並只傳「當次使用者訊息」或「多輪歷史 + 當次訊息」。  
- **您需要提供的**：  
  - 確認 **GEMINI_API_KEY** 權限與配額可用（Context Caching 會呼叫 `cachedContents` API）。  
  - 若專案有使用 **Vertex AI** 而非 Google AI (generativelanguage.googleapis.com)，需改用 Vertex 的 context cache 端點與參數。

**需要您回覆：**  
- [x] 使用 **Google AI**（generativelanguage.googleapis.com）與 `ApiKeys.gemini_api_key`。  
- [x] **先做一份合併意圖的 cache**（系統提示 + 日期對齊 + 合併知識庫內容），之後可再擴充多意圖。

---

### 4. 10 輪對話的定義

- **一輪**：一則使用者訊息 + 一則助理回覆。  
- **10 輪**：保留最近 10 輪（即最多 10 則 user + 10 則 model，共 20 則訊息），超過則捨棄最舊的。  
- 儲存於 Redis：例如 key `rid3510:chat:{conversation_id}`，value 為 JSON 陣列或 list，每筆一輪（user 內容、model 內容、意圖等）。  
- 呼叫 Gemini 時：把這 10 輪歷史組成 `contents` 的多輪格式，再加上「當前這則使用者訊息」，讓模型能正確延續對話。

**需要您回覆：**  
- [x] **固定 10 輪**（最近 10 輪 user+model）。  
- [x] **寫入時可忽略無意義回合**：僅當「使用者訊息有意義」且「助理回覆為實質內容」時才寫入 Redis；錯誤訊息、請提供 message、系統忙碌等不計入一輪，不佔 10 輪名額。

---

## 三、實作時會動到的檔案（供您與工程師對齊）

| 項目 | 預計變更 |
|------|----------|
| **Gemfile** | 新增 `redis` gem。 |
| **環境 / 部署** | 讀取 `REDIS_URL`；本機與 Cloud Run（或 GCP）需可連到 Redis。 |
| **API 請求/回應** | Body 支援 `conversation_id`（選填）；回應帶 `conversation_id`（新對話時回傳新 id）。 |
| **Rid3510::ReplyController** | 從 params 取 `conversation_id`，傳入 ReplyService。 |
| **Rid3510::ReplyService** | 接收 `conversation_id`；從 Redis 讀/寫最近 10 輪；呼叫 Gemini 時改為多輪 `contents` + 可選 Context Caching。 |
| **Conversation store** | 新增類別或模組（例如 `Rid3510::ConversationStore`），以 Redis 存取 `rid3510:chat:{id}`，介面可支援未來換成記憶體或其它後端。 |
| **Context Caching** | 新增服務或方法：建立 cached content（系統+知識庫）、在 `generateContent` 使用 cached content；可依意圖或合併意圖建立。 |
| **前端 rid3510_chat.html.erb** | 第一次請求不帶 `conversation_id`，收到後存於 `window.rid3510ConversationId`，之後同一頁面請求都帶該 id。 |
| **無意義回合** | 見 `Rid3510::ConversationStore::MEANINGLESS_REPLY_PREFIXES`；僅當回覆非錯誤/提示時才寫入 Redis，不佔 10 輪。 |

---

## 四、建議步驟

1. **您回覆上述「需要您回覆」的勾選與簡短說明**（Redis 有無、conversation_id 方案、Vertex 與否、10 輪定義）。  
2. **工程師／AI** 依回覆：  
   - 設計 `conversation_id` 與 Redis key 格式；  
   - 實作 ConversationStore（Redis + 10 輪邏輯）；  
   - 實作 Context Caching（cachedContents.create + generateContent 使用 cache）；  
   - 修改 ReplyService 組多輪 history + 當次 message，並回傳 `conversation_id`。  
3. **您** 提供 Redis 連線（本機 + 雲端）並在環境變數設定 `REDIS_URL`。  
4. 部署後驗證：同一 `conversation_id` 連續多輪，回應正確且僅保留 10 輪。

---

## 五、參考

- GCP Cloud Memorystore 申請與設定：**[docs/23-GCP-CLOUD-MEMORYSTORE-REDIS.md](23-GCP-CLOUD-MEMORYSTORE-REDIS.md)**  
- Gemini Context Caching：<https://ai.google.dev/gemini-api/docs/caching>  
- 本專案 RID3510 回覆流程：`app/services/rid3510/reply_service.rb`、`app/controllers/api/rid3510/reply_controller.rb`  
- 金鑰與環境：`docs/05-API-KEYS-INJECTION.md`、`docs/18-SIMPLE-CHAT-SERVICE.md`
