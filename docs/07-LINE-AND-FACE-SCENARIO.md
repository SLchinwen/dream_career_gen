# 7. 自拍＋職業擬真情境與 LINE 串接

> 情境：小朋友上傳自拍照與希望職業 → 系統用臉部特徵生成「25 歲擬真職業照」；前端可透過 LINE 官方帳號串接。

---

## 7.1 新情境摘要

| 項目 | 內容 |
|------|------|
| **輸入** | 小朋友的**自拍照**（一張）＋**希望職業**（文字，例如「醫生」） |
| **輸出** | **擬真**的「25 歲職業模擬照」，保留臉部特徵、穿著／情境符合職業 |
| **風格** | **擬真相片**（非卡通）；模擬年齡固定 **25 歲** |
| **前端** | 可透過 **LINE 官方帳號（LINE @）** 串接：用戶在 LINE 傳照片＋文字，收到回傳的生成圖 |

與目前「純文字 → 卡通圖」的差異：改為**以自拍為臉部參考**＋**擬真風格**＋**固定 25 歲**，並支援 **LINE** 作為入口。

---

## 7.2 技術方案概覽

### 臉部特徵＋擬真圖（Replicate）

本專案實作流程為**三階段**，詳見 [09-PRODUCT-SERVICE-STEPS.md](09-PRODUCT-SERVICE-STEPS.md)：

1. **年齡變化（SAM）**：`AgeProgressionService` 將人臉長大至約 30 歲（失敗則用原圖）。
2. **Prompt 生成（Gemini）**：依「希望職業」產生 25 歲擬真英文 Prompt。
3. **職業照生成（InstantID）**：`InstantIdService` 以步驟 1 的人臉 URL ＋ 步驟 2 的 Prompt → 擬真職業照 URL。

- **模型**：Replicate `grandlineai/instant-id-photorealistic`（InstantID Photorealistic）。
- **注意**：InstantID 的輸入需為**圖片 URL**（Replicate 可接受 HTTPS 圖檔）。若 LINE 先傳圖給你，需先將圖片存到可對外存取的 URL（例如 GCS、S3 或自家 HTTPS 端點），再傳給本專案 API。

### 模擬年齡固定 25 歲

- 在給 Gemini 的**系統／使用者提示**中明確寫入：  
  「生成描述時，人物年齡一律為 25 歲（25-year-old），風格為擬真攝影（photorealistic），不要卡通或動畫風格。」  
- 如此 Replicate 收到的 Prompt 就會是「25 歲擬真職業照」的描述。

---

## 7.3 LINE 官方帳號串接：你可以怎麼做

三種常見做法：**Make + LINE**、**純 LINE 對話（Messaging API）**、**LINE ＋ 網頁表單**。

### 做法 C：使用 Make（Integromat）串接 LINE（建議）

**流程**：LINE 使用者傳自拍＋職業 → **LINE** 觸發 **Make** 情境 → Make 取得圖片並得到 **HTTPS 圖檔 URL** → Make 呼叫**本專案 API**（`POST /api/career_photo`）→ 取得結果圖 URL → Make 用 **LINE 模組**回傳圖片給使用者。

**本專案已提供 API**（無需在 Rails 內建 LINE Webhook）：

| 項目 | 說明 |
|------|------|
| **端點** | `POST /api/career_photo` |
| **Content-Type** | `application/json` 或 `application/x-www-form-urlencoded` |
| **參數** | `image_url`（必填，自拍圖的 **HTTPS URL**）、`career`（必填，希望職業，例如「醫生」） |
| **回傳** | 成功：`{ "image_url": "https://replicate.delivery/..." }`；失敗：`{ "error": "訊息" }`，HTTP 4xx/5xx |

**Make 情境建議步驟**：

1. **觸發**：LINE → 「Watch events」或「Webhook」接收使用者傳送的訊息（image / text）。
2. **取得圖片 URL**：  
   - 若使用者傳的是圖片：用 LINE 模組「Get content」取得圖檔，再透過「HTTP」或「Google Drive / Dropbox / 暫存空間」上傳並取得**可對外存取的 HTTPS URL**（Replicate 需能抓到此 URL）。  
   - 若 Make 有「Upload file to URL」或可存到 GCS／S3 並取得公開 URL，即可當作 `image_url`。
3. **取得職業**：從使用者傳的**文字訊息**取得，或約定「先傳圖、再傳文字」。
4. **呼叫本專案 API**：  
   - Make 模組「HTTP」→ **POST** `https://你的網域/api/career_photo`  
   - Body：`{ "image_url": "上一步的 HTTPS 圖檔 URL", "career": "醫生" }`  
   - 取得回應中的 `image_url`（生成圖的 URL）。
5. **回傳給使用者**：LINE 模組「Send reply message」或「Push message」→ **Image message**，`originalContentUrl` 與 `previewImageUrl` 填上一步的 `image_url`。

**注意**：生成約需 15～60 秒，Make 的 HTTP 請求可能逾時。可改為：  
- 先回覆使用者「正在生成，請稍候」；  
- Make 用「Async」或「Repeater」輪詢本 API（若未來本專案提供「建立任務 + 輪詢結果」的 API），或直接等 HTTP 回應（若 Replicate 在 60 秒內完成）。  
- 或本專案之後可加「非同步 API」（回傳 job_id，再提供 GET 查結果），Make 再輪詢或收 Webhook 完成通知。

**小結**：前端用 **Make + LINE** 建置即可，本專案只負責 **InstantID + API**；Make 負責接收 LINE、湊齊 image_url 與 career、呼叫 API、回傳圖片給使用者。

---

### 做法 A：純 LINE 對話（Messaging API，Rails 自建 Webhook）

**流程**：使用者在 LINE 傳**一張照片**＋**一段文字（職業）**，你的伺服器收到後在背景算圖，再**回傳一張圖片**給使用者。

1. **LINE 端準備**
   - 建立 [LINE 官方帳號](https://developers.line.biz/)（或使用既有 LINE @）。
   - 在 LINE Developers 建立 **Messaging API** 用的 Channel，取得 **Channel Secret**、**Channel Access Token**。
   - **Webhook URL**：填你的後端網址，例如 `https://你的網域/line/webhook`（須 **HTTPS**）。

2. **後端須實作**
   - **Webhook 端點**（例如 `POST /line/webhook`）：  
     - 驗證簽章（LINE 簽章驗證）。  
     - 解析事件：若為「使用者傳送訊息」→ 判斷是 **image** 或 **text**。  
     - **收到圖片**：用 LINE Messaging API 的 [Get content](https://developers.line.biz/en/reference/messaging-api/#get-content) 依 `messageId` 下載圖片二進位，再上傳到你自己的儲存（GCS／S3／暫存並產生 HTTPS URL）。  
     - **收到文字**：可當作「希望職業」；或約定「先傳圖、再傳文字」／「文字與圖同一則」依你設計。  
   - **流程串接**：  
     - 湊齊「一張自拍 URL」＋「職業文字」後，呼叫 **Gemini**（產生 25 歲擬真用 Prompt）→ **Replicate InstantID**（自拍 URL ＋ Prompt）→ 得到**結果圖 URL**。  
     - 使用 [Reply message](https://developers.line.biz/en/reference/messaging-api/#send-reply-message) 的 **Image message**，`originalContentUrl` 與 `previewImageUrl` 填生成圖的 **HTTPS 網址**（Replicate 的輸出 URL 若為 HTTPS 且 LINE 可存取，可直接使用；否則需先轉存到你的 CDN／GCS 再回傳）。

3. **非同步與體驗**
   - 生成約需十幾秒～數十秒，建議：  
     - Webhook 先回覆一則「正在為你生成 25 歲職業照，請稍候」的**文字訊息**。  
     - 用 **Background Job**（如 Solid Queue）在背景跑 Gemini ＋ Replicate，完成後再呼叫 LINE **Push message**（或 Reply），把**結果圖**傳給該使用者。  
   - 若不用 Push，也可在 Webhook 內輪詢 Replicate 完成後再 Reply（需注意 LINE Webhook 逾時，通常 30 秒內要回應，故多數會採「先回文字 + 背景 Job + Push 圖」）。

4. **小結（做法 A）**
   - 使用者體驗：在 LINE 傳一張自拍＋輸入職業 → 收到「正在生成」→ 稍後收到一張 25 歲擬真職業照。  
   - 你需要的：LINE Channel、Webhook 端點、取得並儲存自拍為 URL、Gemini、Replicate InstantID、回傳／Push 圖片。

### 做法 B：LINE ＋ 網頁表單（LIFF 或 LINE Login + Web）

**流程**：在 LINE 內開啟一個**網頁**（LIFF 或一般網頁＋LINE Login），網頁上傳自拍＋選擇／輸入職業，送出後顯示結果；可選擇「同時把結果圖透過 LINE 推給使用者」。

1. **LINE 端**
   - 建立 **LIFF App**（或使用 LINE Login），取得 LIFF ID／LINE Login。
   - 在官方帳號選單或圖文選單放「開始製作職業照」連結，點擊後開啟你的 **HTTPS 網頁**（表單頁）。

2. **網頁**
   - 表單欄位：**上傳一張照片**＋**職業**（下拉或文字）。
   - 送出後呼叫你的 **Rails API**（例如 `POST /api/dream_career`）：上傳圖片（multipart）＋職業。  
   - 後端：存圖 → 取得 URL → Gemini（25 歲擬真 Prompt）→ Replicate InstantID → 回傳結果圖 URL 給前端顯示；若需要，再依使用者 LINE userId 用 **Push message** 把同一張圖發到 LINE。

3. **小結（做法 B）**
   - 表單清楚、可做較複雜 UI（載入動畫、成果頁）；仍可與 LINE 整合（用 Push 把圖推到聊天室）。

---

## 7.4 後端 API 與服務（已實作）

本專案已提供（完整流程見 [09-PRODUCT-SERVICE-STEPS.md](09-PRODUCT-SERVICE-STEPS.md)）：

| 項目 | 說明 |
|------|------|
| **API** | `POST /api/career_photo`，參數 `image_url`、`career`，回傳 `{ "image_url": "...", "url_expires": true }` |
| **年齡變化** | `AgeProgressionService.age_to(image_url:)` → SAM 模型，人臉長大至約 30 歲 |
| **Gemini** | `GeminiService.prompt_for_photorealistic_career(career:)` → 25 歲擬真英文 Prompt |
| **InstantID** | `InstantIdService.generate(image_url:, prompt:)` → Replicate `grandlineai/instant-id-photorealistic`，回傳擬真圖 URL |

前端用 **Make + LINE** 時，只需在 Make 內：取得自拍 HTTPS URL、取得職業文字、POST 到上述 API、用回傳的 `image_url` 透過 LINE 回傳圖片即可。生成約需 **90–150 秒**，Make 請將 HTTP 逾時設長。

---

## 7.5 建議實作順序（若不用 Make、改在 Rails 自建 LINE Webhook）

1. **後端**：已具備 API 與 InstantID（見 7.4）。  
2. **LINE Webhook（Rails 自建）**  
   - 實作 `POST /line/webhook`：簽章驗證、解析 image/text、下載圖片並存成 URL、排程 Background Job（或直接呼叫 API 邏輯）、先 Reply 文字、完成後 Push 圖片。  
3. **（選用）LIFF／網頁表單**  
   - 表單上傳自拍＋職業，呼叫同一支 API，並可選擇是否用 LINE Push 把結果圖推到 LINE。

---

## 7.6 注意事項

- **個資與兒童照片**：自拍為敏感資料，須符合個資法與平台規範；儲存、傳遞、保留時間與 LINE 隱私設定需一併規劃。  
- **LINE 規範**：圖片內容須符合 [LINE 平台政策](https://developers.line.biz/en/docs/messaging-api/policy/)；擬真圖若涉及他人肖像，須注意授權與使用目的。  
- **Replicate 輸出 URL**：InstantID 輸出多為 `replicate.delivery` 等 HTTPS URL，通常可直接用於 LINE Image message；若 LINE 無法存取，再改為先下載後上傳到你自己的 HTTPS 空間再回傳。

---

## 7.7 相關文件

- **流程與階段**：[02-ROADMAP.md](02-ROADMAP.md)、[03-USER-STORY.md](03-USER-STORY.md)  
- **金鑰與環境**：[05-API-KEYS-INJECTION.md](05-API-KEYS-INJECTION.md)  
- **Replicate**：卡通圖用 `ReplicateService`（Flux）；擬真用 `InstantIdService`（InstantID Photorealistic）。  
- **LINE 官方文件**：[LINE Messaging API](https://developers.line.biz/en/docs/messaging-api/)、[Webhook](https://developers.line.biz/en/docs/messaging-api/receiving-messages/)、[Send message](https://developers.line.biz/en/reference/messaging-api/#send-reply-message)
