# 8. 一步一步操作指南（Make + LINE ＋ 本專案 API）

> 目標：讓使用者在 LINE 傳自拍＋職業 → Make 呼叫本專案 API → 回傳 25 歲擬真職業照。

---

## 前置：本專案 API 要能從外網連到

- **本機測試**：用 ngrok 等把 `http://localhost:3000` 曝露成 HTTPS URL，Make 才能 POST。
- **正式環境**：本專案已部署到 GCP Cloud Run，用 `https://dream-career-service-xxx.asia-east1.run.app` 當 API 基底網址。

以下假設你的 API 基底網址為 **`https://你的網域`**（本機用 ngrok 的 URL，正式用 Cloud Run URL）。

---

## 第一步：確認後端 API 在本機可跑

1. 在專案目錄執行：`ruby bin/rails server`
2. 另開終端機測試 API（請把圖片網址換成任一張人臉照片的 HTTPS URL，例如 [Unsplash 人像](https://unsplash.com/s/photos/portrait) 右鍵複製圖片網址）：

   **Windows 建議用 PowerShell（避免 curl 引號／port 解析錯誤）：**

   ```powershell
   $img = "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d"
   $body = @{ image_url = $img; career = "醫生" } | ConvertTo-Json
   # 職業照生成約 60–90 秒，請延長逾時並把結果存到變數以顯示
   $r = Invoke-RestMethod -Uri "http://localhost:3000/api/career_photo" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 180
   $r | ConvertTo-Json
   $r.image_url
   ```

   （若要用 curl，請用 **curl.exe** 並把 JSON 存成檔案再 `-d @body.json`，避免 PowerShell 引號問題。）

3. **請至少等 60–90 秒**再判斷有無回應；成功時 `$r.image_url` 會是圖片網址。若仍無輸出，看跑 server 的那個終端機是否有錯誤或 request log。

4. **圖片 URL 說明**：回傳的 `image_url` 為 Replicate 的 **暫時性連結**（`replicate.delivery`），數小時後可能失效。請在取得後**立即開啟或下載**。若在終端機看到網址被截斷（有 `…`），請用完整 URL：  
   `$r.image_url | Set-Clipboard` 可將完整網址複製到剪貼簿，再貼到瀏覽器開啟。

---

## 第二步：讓 Make 能連到你的 API（本機用 ngrok）

1. 下載並安裝 [ngrok](https://ngrok.com/download)。
2. 在終端機執行：`ngrok http 3000`
3. 記下畫面上的 **HTTPS 網址**（例如 `https://abc123.ngrok.io`），這就是「你的 API 基底網址」。
4. Make 的 HTTP 模組要 POST 的 URL 即：`https://abc123.ngrok.io/api/career_photo`

（若已部署到 Cloud Run，可略過 ngrok，直接用 Cloud Run 的 URL。）

---

## 第三步：LINE 官方帳號與 Messaging API

1. 到 [LINE Developers](https://developers.line.biz/console/) 登入。
2. 建立 **Provider**（若還沒有）→ 建立 **Channel**，類型選 **Messaging API**。
3. 在 Channel 的 **Messaging API** 分頁：
   - 記下 **Channel ID**、**Channel Secret**。
   - 發行 **Channel Access Token**（長期），記下 Token。
4. 在 **Messaging API** 分頁的 **Webhook**：
   - 先不填 Webhook URL（等 Make 建好情境後，在 Make 取得 Webhook URL 再回來填）。
   - 或若你要用 **Make 的 Webhook** 當觸發，就在 Make 建立「Webhooks」模組，取得 Make 的 Webhook URL；LINE 不直接填我們 Rails，而是填 Make 的 Webhook（見第四步）。

**注意**：LINE 的「回應訊息」有兩種做法：  
- **A**：LINE Webhook URL 填 **Make 的 Webhook**，由 Make 收 LINE 事件、呼叫我們 API、再呼叫 LINE Reply/Push。  
- **B**：LINE Webhook URL 填 **Rails**（需自建 `POST /line/webhook`）。  

這裡以 **A（Make 當 Webhook 接收端）** 為準。

---

## 第四步：在 Make 建立情境

1. 登入 [Make](https://www.make.com/)（原 Integromat）。
2. 建立新 **Scenario**。
3. **觸發**：
   - 新增模組 → 選 **LINE** → **Watch events**（或 **Webhooks** 若 LINE 要打 Make）。
   - 連線 LINE：輸入 Channel ID、Channel Secret、Channel Access Token。
   - 若用 **Watch events**：需在 LINE Developers 的 Webhook 填 Make 提供的 **Webhook URL**（Make 會顯示），並啟用「Use webhook」。
4. **過濾／路由**（依你設計）：
   - 只處理「使用者傳送訊息」：事件類型 = message。
   - 可拆兩條：一張是「收到圖片」、一張是「收到文字」，再依對話順序湊齊「最近一張圖＋最近一則職業文字」；或約定「先傳圖、再傳文字」同一輪。
5. **取得自拍圖的 HTTPS URL**：
   - 新增模組 **LINE** → **Get content**（或 **Download file**）：用觸發事件裡的 `message.id` 下載圖片。
   - 新增模組 **HTTP** → **Upload file** 到某處（例如 **Google Drive**、**Dropbox**、**Imgur**、或 Make 的 **File storage**），取得該檔的 **公開 HTTPS URL**。  
     （若 Make 有「Get content」後直接得到 URL，可略過上傳步驟。）
6. **呼叫本專案 API**：
   - 新增模組 **HTTP** → **Make a request**：
     - URL：`https://你的網域/api/career_photo`
     - Method：**POST**
     - Headers：`Content-Type: application/json`
     - Body：  
       `{ "image_url": "上一步的圖片 HTTPS URL", "career": "上一步取得的職業文字" }`
   - 逾時設長一點（例如 90 秒），因為 InstantID 可能需 15～60 秒。
7. **回傳圖片給使用者**：
   - 新增模組 **LINE** → **Send a reply message**（或 **Push message**）：
     - Reply token：從觸發事件的 `replyToken` 取得。
     - Message type：**Image**
     - Original content URL：HTTP 模組回傳的 `image_url`
     - Preview image URL：同上或留空。
8. **錯誤與等候**：
   - 若 API 逾時：可先送一則「正在為你生成 25 歲職業照，請稍候」文字，再非同步呼叫 API，完成後用 **Push message** 送圖（需 userId）。
   - 若 API 回傳 `error`：用 Make 的 **Error handler** 或 **Router** 判斷，回覆使用者「生成失敗，請再試一次」。

---

## 第五步：LINE Webhook 設定（若用 Make 收 LINE 事件）

1. 在 Make 情境中，**LINE - Watch events** 會顯示一個 **Webhook URL**（例如 `https://hook.eu1.make.com/xxx`）。
2. 到 LINE Developers → 你的 Channel → **Messaging API** 分頁：
   - **Webhook URL** 填上 Make 的 Webhook URL。
   - **Webhook** 設為 **Enabled**。
   - **Auto-reply messages**、**Greeting messages** 可關閉，改由 Make 統一回覆。
3. 儲存後，在 LINE 對官方帳號傳一張圖＋一句「醫生」測試。

---

## 第六步：端對端測試

1. 用手機 LINE 對你的官方帳號傳：**一張自拍照**。
2. 再傳一句文字：**醫生**（或你約定的職業關鍵字）。
3. 檢查 Make 情境是否執行、HTTP 是否成功、LINE 是否回傳一張擬真職業照。
4. 若失敗：看 Make 的執行紀錄（哪一 step 錯）、Rails log、API 回傳的 `error`。

---

## 檢查清單

- [ ] 本機 `bin/rails server` 可跑，curl POST `/api/career_photo` 有回傳 `image_url`
- [ ] 本機用 ngrok 曝露 HTTPS，或已部署 Cloud Run 並有 URL
- [ ] LINE Channel（Messaging API）已建立，Channel ID / Secret / Access Token 已記下
- [ ] Make 情境：LINE 觸發 → 取得圖片 URL → 取得職業 → POST 到 `/api/career_photo` → LINE 回傳圖片
- [ ] LINE Webhook URL 填 Make 的 Webhook，並啟用
- [ ] 實際在 LINE 傳圖＋職業，收到回傳的擬真職業照

---

## 相關文件

- API 與參數詳情： [07-LINE-AND-FACE-SCENARIO.md](07-LINE-AND-FACE-SCENARIO.md)  
- 金鑰設定： [05-API-KEYS-INJECTION.md](05-API-KEYS-INJECTION.md)
