# 18. 簡單聊天服務（索引與環境參考）

> 在現有 dream_career_gen 專案中新增**簡單聊天服務**，使用**雲端網址**與 **Gemini API**，與既有夢想職人照服務**不衝突**、**共用同一環境**。本文件供 AI 引用相同環境資訊完成建置。

---

## 一、目的與範圍

| 項目 | 說明 |
|------|------|
| **功能** | 簡單聊天服務（使用者輸入訊息 → 呼叫 Gemini API → 回傳回覆） |
| **需使用** | 雲端網址（本專案已部署之 GCP Cloud Run）、Gemini API |
| **與現有服務關係** | 不衝突：新增路徑與 controller，與夢想職人照、Rotary 評分等並存；共用同一 Rails 專案、同一金鑰與部署 |

---

## 二、環境與建置參考（供 AI 引用）

### 1. 技術棧與版本

| 項目 | 版本／說明 |
|------|-------------|
| **Ruby** | 3.4.7（見專案根目錄 `.ruby-version`） |
| **Rails** | 8.1.x（見 `Gemfile`） |
| **資料庫** | SQLite（開發／測試） |
| **前端** | Importmap、Turbo、Stimulus（見 `Gemfile`） |

### 2. 金鑰與讀取方式

| 用途 | 環境變數名稱 | 程式讀取方式 | 說明 |
|------|--------------|--------------|------|
| **Gemini API** | `GEMINI_API_KEY` | `ApiKeys.gemini_api_key` | 必填；聊天服務需此金鑰 |

- **讀取邏輯**：`config/initializers/api_keys.rb`  
  優先使用環境變數 `ENV["GEMINI_API_KEY"]`，沒有則從 Rails credentials `Rails.application.credentials.dig(:gemini, :api_key)` 讀取。
- **本機開發**：PowerShell 設 `$env:GEMINI_API_KEY = "你的金鑰"` 後再啟動 server；或使用 `.env`（勿提交）、或 `bin/rails credentials:edit` 寫入。
- **雲端（GCP Cloud Run）**：在服務的「變數與密碼」中新增 `GEMINI_API_KEY`。  
  詳見：`docs/05-API-KEYS-INJECTION.md`、`docs/10-DEPLOY-FOR-VOLUNTEERS.md`。

### 3. 雲端網址與部署

| 項目 | 說明 |
|------|------|
| **部署方式** | GCP Cloud Run（推送 main 後由 Cloud Build 建置與部署，見 `cloudbuild.yaml`） |
| **GCP 專案** | 文件內多寫 **green-miracle-dream**（依實際專案為準） |
| **服務名稱** | **dream-career-service** |
| **雲端網址** | 部署完成後於 Cloud Run 服務詳情頁取得（例如 `https://xxx.run.app`） |
| **環境變數** | 同上，在 Cloud Run「變數與密碼」設定 `GEMINI_API_KEY`、`RAILS_ENV=production` 等 |

同一部署即同時提供：現有夢想職人照頁面、Rotary 評分、以及**新加的聊天服務**（見下方路由設計）。

### 4. 現有路由與不衝突做法

**目前路由**（`config/routes.rb`）摘要：

- `GET /`、`/career_photo_fast`、`/career_photo`：夢想職人照頁面  
- `GET/POST /rotary/photo_score`：People of Action 評分  
- `POST /api/career_photo`、`POST /api/career_photo_fast`：職業照 API  
- `POST /api/rotary/photo_scores`：評分 API  
- `GET /up`：健康檢查  

**建議：聊天服務不衝突做法**

- **網頁聊天**：新增 `GET /chat`（頁面）、`POST /api/chat` 或 `POST /chat/message`（送訊息、呼叫 Gemini、回傳結果）。  
- **僅 API**：新增 `POST /api/chat`（或 `POST /api/chat/messages`）接收使用者訊息、呼叫 Gemini、回傳 JSON。  
- 不修改既有 `root`、`/career_photo*`、`/rotary/*`、`/api/career_photo*` 等，僅**新增**路徑與對應 controller／view。

### 5. Gemini API 呼叫方式（本專案既有寫法）

- **端點**：`https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent`  
- **認證**：Request header `x-goog-api-key: <GEMINI_API_KEY>`  
- **本專案使用模型**：`gemini-2.0-flash`（見 `app/services/gemini_service.rb` 的 `MODEL`）  
- **請求體**：JSON，結構例如  
  `{ "contents": [ { "parts": [ { "text": "使用者訊息或系統+使用者組合" } ] } ], "generationConfig": { "temperature": 0.7, "maxOutputTokens": 1024, "responseMimeType": "text/plain" } }`  
- **回應**：從 `response.body` 的 `candidates[0].content.parts[0].text` 取得回覆文字。  

現有實作可參考：`app/services/gemini_service.rb`（使用 `Net::HTTP`、`ApiKeys.gemini_api_key`）。聊天服務可**新增**一個 `ChatService` 或類似類別，同樣使用 `ApiKeys.gemini_api_key`，只改 `contents` 為對話內容即可。

### 6. Windows 本機指令

本專案在 Windows 上執行 Rails 時需用 **`ruby` 前綴**執行 bin 腳本（見 `.cursor/rules/windows-env.mdc`），例如：

- 啟動 server：`ruby bin/rails server`  
- 測試：`ruby bin/rails test`  
- 主控台：`ruby bin/rails console`  

---

## 三、建議實作清單（供 AI 建置用）

1. **路由**：新增 `get "chat"`、`post "api/chat"`（或自訂路徑），不覆蓋既有路由。  
2. **金鑰**：沿用 `ApiKeys.gemini_api_key`，無須新增環境變數名稱。  
3. **服務類別**：新增 `app/services/chat_service.rb`（或類似名稱），呼叫 Gemini `generateContent`，可參考 `GeminiService` 的 HTTP 與 key 用法。  
4. **Controller**：新增 `ChatController` 或 `Api::ChatController`，接收使用者輸入、呼叫上述服務、回傳結果（HTML 或 JSON）。  
5. **View（若要做網頁）**：新增 `app/views/chat/` 或對應 view，表單送訊息、顯示回覆。  
6. **雲端網址**：不需另建服務，沿用現有 Cloud Run 部署；部署後聊天服務即為同一網址下的 `/chat` 與 `/api/chat`（或你設定的路徑）。  

---

## 四、可複製給其他 AI 的環境摘要（一頁）

以下區塊可整段複製到其他工作區或提供給 AI，以便在**相同環境**下建置簡單聊天服務。

```markdown
## 專案：dream_career_gen（Rails 8.1，Ruby 3.4.7）

- **目標**：在現有專案中新增「簡單聊天服務」，使用雲端網址 + Gemini API；與現有夢想職人照不衝突，共用環境。
- **金鑰**：使用既有 `GEMINI_API_KEY`（環境變數或 Rails credentials）；程式讀取 `ApiKeys.gemini_api_key`（見 config/initializers/api_keys.rb）。
- **雲端**：GCP Cloud Run，服務名 dream-career-service；部署後同一網址下新增 /chat 與 API 即可。
- **路由**：僅新增路徑（如 get "chat", post "api/chat"），不修改既有 root、/career_photo*、/rotary/*、/api/career_photo*。
- **Gemini**：POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent，header x-goog-api-key，body 為 contents + generationConfig；可參考 app/services/gemini_service.rb。
- **本機**：Windows 上請用 ruby bin/rails server、ruby bin/rails test。
- **完整文件**：見專案 docs/05-API-KEYS-INJECTION.md、docs/10-DEPLOY-FOR-VOLUNTEERS.md、docs/18-SIMPLE-CHAT-SERVICE.md。
```

---

## 五、相關文件索引

| 文件 | 說明 |
|------|------|
| [05-API-KEYS-INJECTION.md](05-API-KEYS-INJECTION.md) | 金鑰注入方式（環境變數、.env、credentials）、GCP Cloud Run 變數設定 |
| [06-GIT-GOVERNANCE.md](06-GIT-GOVERNANCE.md) | 勿提交 .env、master.key；commit 前自檢 |
| [10-DEPLOY-FOR-VOLUNTEERS.md](10-DEPLOY-FOR-VOLUNTEERS.md) | 發布流程、Cloud Run 環境變數、取得雲端網址 |
| `config/initializers/api_keys.rb` | ApiKeys.gemini_api_key 讀取邏輯 |
| `app/services/gemini_service.rb` | 既有 Gemini 呼叫範例（generateContent、x-goog-api-key） |
| `config/routes.rb` | 現有路由，新增聊天路徑時請勿覆蓋 |

---

**維護約定**：若金鑰讀取方式、Cloud Run 服務名稱或 Gemini 端點變更，請同步更新本文件。引用時請用相對路徑，例如：`見 docs/18-SIMPLE-CHAT-SERVICE.md`。
