# 子模組已加好 — 請在 dream_career_gen 建立 API 並部署

> 您已在 dream_career_gen 加入 Rid3510 為**子模組**（資料夾名稱應為 `rid3510`）。這份是「接下來怎麼建立程式、怎麼部署」的步驟。**請在 dream_career_gen 專案裡**依此操作，或把整份給該專案的 AI 執行。

---

## 一、知識庫從哪裡讀（重要）

- **不要**再複製檔案到 `config/rid3510/`。
- 知識庫已經在 **子模組** 裡，路徑是：**`Rails.root.join("rid3510")`**。
  - YAML 檔：`Rails.root.join("rid3510", "rag-intent-paths.yaml")`
  - 某個 .md：YAML 裡寫的路徑例如 `docs/07-行政E化/03-官網FAQ.md` → 讀取 `Rails.root.join("rid3510", "docs", "07-行政E化", "03-官網FAQ.md")`（或 `Rails.root.join("rid3510", "docs/07-行政E化/03-官網FAQ.md")`，依你路徑寫法）。

底下所有「讀取知識庫」的地方，**根目錄都用 `Rails.root.join("rid3510")`**。

---

## 二、要建立的東西（在 dream_career_gen 裡）

### 1. 路由（只新增一行）

在 `config/routes.rb` **只加這一行**（不刪不改其他）：

```ruby
post "stage1/reply", to: "rid3510/reply#create"
```

*本專案已實作為 `post "stage1/reply" => "api/rid3510/reply#create"`，效果相同。*

### 2. 意圖辨識

新增檔案 **`app/services/rid3510/intent_detector.rb`**（若沒有 `rid3510` 資料夾請先建）：

- 方法：`self.detect(message)`，回傳意圖字串。
- 規則（依序比對，先符合先回傳）：
  - 訊息含「總監」或「屆」或「歷年」 → `"3510歷史"`
  - 含「登入」或「LINE」或「綁定」，或（「報名」且「活動」）→ `"E化操作"`
  - 含「年會」或「RYLA」或「活動」或「日期」或「訓練」→ `"現有活動"`
  - 含「目標」，或「社員」且「成長」，或「卓越獎」→ `"工作目標"`
  - 含「獎助金」或「DDF」或「基金」→ `"基金與獎助金"`
  - 含「四大考驗」或「DG」，或（「扶輪」且（「是什麼」或「意思」））→ `"扶輪知識"`
  - 以上皆否 → `"fallback"`
- 訊息先 `strip`，空字串回 `"fallback"`。

### 3. 知識庫讀取（從子模組 rid3510/ 讀）

新增 **`app/services/rid3510/knowledge_service.rb`**：

- 讀取 YAML：`Rails.root.join("rid3510", "rag-intent-paths.yaml")`，解析出 `intent_paths`、`fallback_paths`。
- 方法 `context_for_intent(intent, max_chars: 6000)`：
  - 依 `intent` 從 `intent_paths` 取路徑陣列，沒有則用 `fallback_paths`。
  - 每個路徑是相對「知識庫根」的字串（例如 `docs/07-行政E化/03-官網FAQ.md`），實際讀檔路徑 = `Rails.root.join("rid3510", path)`。
  - 逐檔讀取 .md 內容，合併成一個字串，總長度不超過 `max_chars`，回傳該字串。

### 4. 回覆服務（呼叫 Gemini）

新增 **`app/services/rid3510/reply_service.rb`**：

- 方法：`self.call(message)`，回傳 `{ reply: 字串, intent: 字串 }`。
- **日期對齊**：在組 prompt 前，先依**系統日期**推算「當前扶輪年度」（扶輪年度為 7/1～隔年 6/30）。例如：2026 年 2 月 → 當前年度為 `2025-26`；2026 年 8 月 → `2026-27`。把這段說明放進送給 Gemini 的 user 內容**開頭**，讓「目前總監／這屆／今年」回答對齊正確年度。  
  - 推算邏輯：`today = Time.current` 或 `Date.current`；若 `today.month >= 7` 則年度為 `"#{today.year}-#{(today.year+1) % 100}"`，否則為 `"#{today.year-1}-#{today.year % 100}"`（後段若需兩位數可格式化為 `%02d`）。  
  - 日期說明字串範例：`【系統日期】今日為 YYYY年M月D日。當前扶輪年度為 2025-26。使用者問「目前總監」「這屆總監」「今年」時請依此年度回答。`
- 步驟：  
  ① 用 `Rid3510::IntentDetector.detect(message)` 得到 `intent`。  
  ② 用 `Rid3510::KnowledgeService.new.context_for_intent(intent)` 得到 `context`。  
  ③ system 固定為：「你是國際扶輪 3510 地區的知識庫助理。請根據以下「知識庫內容」簡潔回答使用者的問題。若資料中無答案，請說明並建議聯繫地區 e 化主委或地區辦事處。回答請用繁體中文。」  
  ④ user 內容 = **日期說明字串（見上）** + 「【知識庫內容】」+ context（前約 8000 字）+ 「【使用者問題】」+ message。  
  ⑤ 用 **`ApiKeys.gemini_api_key`** 呼叫 Gemini `generateContent`（可參考既有 `app/services/gemini_service.rb`：POST、header `x-goog-api-key`、模型如 `gemini-2.0-flash`），取得回覆文字。  
  ⑥ 回傳 `{ reply: 回覆文字, intent: intent }`。若呼叫失敗，回傳 `{ reply: "查詢時發生錯誤，請稍後再試或聯繫地區 e 化主委。", intent: intent }`。

### 5. Controller

新增 **`app/controllers/rid3510/reply_controller.rb`**（目錄 `app/controllers/rid3510/` 若沒有請先建）：

- `create` action：從 `params[:message]` 取得使用者輸入（JSON body 的 `message`）。
- 若 `message` 空白，可回傳 `render json: { reply: "請提供 message 內容。", intent: "fallback" }, status: :ok`（或 400，依需求）。
- 否則呼叫 `result = Rid3510::ReplyService.call(params[:message])`，再 `render json: result, status: :ok`。

*本專案已實作為 `app/controllers/api/rid3510/reply_controller.rb`，行為一致。*

---

## 三、本機測試

在 dream_career_gen 專案：

1. 啟動 server：`ruby bin/rails server`
2. 用 curl 或 Postman 打：  
   **POST** `http://localhost:3000/stage1/reply`  
   **Body（JSON）**：`{ "message": "今年地區年會什麼時候" }`  
3. 應得到 200，且 JSON 有 `reply`（內容與知識庫有關）、`intent`（如 `現有活動` 或 `fallback`）。
4. 再打 **Body** `{ "message": "目前總監是誰" }`，確認回覆的年度為**今日所屬扶輪年度**（見 [19-驗證與重新部署步驟.md](19-驗證與重新部署步驟.md)）。

若本機正常，再進行部署。

---

## 四、部署（建立上線）

dream_career_gen 若本來就是用 **push 到 Git 就觸發 GCP Cloud Build 並部署到 Cloud Run**，則：

1. 在 dream_career_gen 專案資料夾執行：

   ```bash
   git add .
   git status
   ```

   確認有新增的檔案（routes、app/services/rid3510/*、app/controllers/rid3510/*），以及子模組 `rid3510` 已存在且已 commit 過。

2. 送交並推送：

   ```bash
   git commit -m "新增 RID3510 stage1/reply API，從子模組 rid3510 讀取知識庫"
   git push
   ```

3. 到 GCP Console 的 **Cloud Build** 看建置是否成功；再到 **Cloud Run** 看服務是否已更新。

4. 部署完成後，API 網址為：  
   **`https://您的 Cloud Run 服務網址/stage1/reply`**  
   例如：`https://dream-career-service-xxxx.run.app/stage1/reply`

5. 再用 curl 或 Postman 打一次 **POST** 該網址、Body `{ "message": "今年地區年會什麼時候" }`，確認回傳正常。

---

## 五、給 AI 的一句話指令（在 dream_career_gen 專案用）

若您要在 dream_career_gen 專案請 AI 做，可以這樣說：

> 請依專案內（或 Rid3510 專案）的「子模組已加好-請建立與部署」這份文件，在 dream_career_gen 裡新增 RID3510 階段 1 回覆 API：路由 `POST /stage1/reply`，從**子模組 rid3510/** 讀取 `rag-intent-paths.yaml` 與 docs，意圖辨識、KnowledgeService、ReplyService、Rid3510::ReplyController 都依該文件實作，並用既有 ApiKeys.gemini_api_key 呼叫 Gemini。完成後請說明如何本機測試與如何部署（git push 觸發 Cloud Build）。

---

## 六、相關文件

| 文件 | 說明 |
|------|------|
| 本文件 | 子模組已加好後，建立 API 與部署的步驟 |
| [18-SIMPLE-CHAT-SERVICE.md](18-SIMPLE-CHAT-SERVICE.md) | RID3510 stage1/reply 與模擬網頁、環境參考 |
| [19-驗證與重新部署步驟.md](19-驗證與重新部署步驟.md) | 改過程式後重新部署與驗證「目前總監」日期對齊 |
| rid3510 子模組 | [讓另一個專案讀取本 repo 的檔案](rid3510/docs/讓另一個專案讀取本repo的檔案-一步一步.md)（子模組更新方式） |

完成上述「二、要建立的東西」與「四、部署」後，Make 即可把「取得回覆」改為呼叫 **`https://您的 Cloud Run 網址/stage1/reply`**。
