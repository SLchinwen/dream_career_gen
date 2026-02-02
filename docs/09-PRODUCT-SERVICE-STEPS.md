# 9. 產品服務步驟定義

> 維護時可引用：**功能驗收、API 規格、本機測試、流程對齊**。

---

## 9.1 服務流程總覽

**夢想職人生成器** 提供「自拍＋職業 → 25 歲擬真職業照」服務，流程分為**三個階段**：

| 階段 | 服務 | 說明 | 預估時間 |
|------|------|------|----------|
| **1** | 年齡變化 (Age Progression) | 以 SAM 模型將人臉長大至約 30 歲 | 約 15–60 秒 |
| **2** | Prompt 生成 (Gemini) | 依職業產生 25 歲擬真英文繪圖指令 | 約 2–5 秒 |
| **3** | 職業照生成 (InstantID) | 保留臉部特徵的擬真職業照 | 約 15–60 秒 |

**總預估時間：約 90–150 秒**（視 Replicate 排隊狀況而定）。

---

## 9.2 詳細步驟

### 步驟 1：年齡變化 (AgeProgressionService)

- **模型**：Replicate `yuval-alaluf/sam`（Style-based Age Manipulation）
- **輸入**：`image_url`（人臉照片的 HTTPS URL 或 data URL）
- **輸出**：長大至約 30 歲的人臉圖片 URL
- **失敗時**：使用原圖繼續（不中斷流程）

### 步驟 2：Prompt 生成 (GeminiService)

- **API**：Google Gemini
- **輸入**：`career`（希望職業，例如「醫生」）
- **輸出**：25 歲擬真風格的英文繪圖 Prompt

### 步驟 3：職業照生成 (InstantIdService)

- **模型**：Replicate `grandlineai/instant-id-photorealistic`
- **輸入**：步驟 1 的人臉 URL、步驟 2 的 Prompt
- **輸出**：擬真職業照的 HTTPS URL（`replicate.delivery` 暫時性連結）

---

## 9.3 入口與 API

### Web 版表單

| 項目 | 說明 |
|------|------|
| **路徑** | `/` 或 `/career_photo` |
| **輸入** | 圖片網址 或 上傳檔案、職業（必選）、學生代號（選填，用於檔名） |
| **呼叫** | 前端 `POST /api/career_photo`，body：`{ image_url, career }` |
| **輸出** | 顯示生成圖、下載按鈕、總耗時 |

### API 端點

| 項目 | 說明 |
|------|------|
| **端點** | `POST /api/career_photo` |
| **Content-Type** | `application/json` |
| **參數** | `image_url`（必填）、`career`（必填） |
| **成功回傳** | `{ "image_url": "https://...", "url_expires": true }` |
| **失敗回傳** | `{ "error": "訊息" }`，HTTP 4xx/5xx |

**注意**：`image_url` 可為 HTTPS URL 或 `data:` base64 字串（Web 上傳時轉成 data URL）。

---

## 9.4 本機測試檢查清單

- [ ] `bundle install` 完成
- [ ] API 金鑰已設定（`REPLICATE_API_TOKEN`、`GEMINI_API_KEY`）
- [ ] 執行 `bin/dev` 或 `bin/rails server`，伺服器啟動於 `http://localhost:3000`
- [ ] 瀏覽器開啟 `http://localhost:3000`，可看到「夢想職業照」表單
- [ ] 輸入圖片網址或上傳照片、選擇職業，點「生成職業照」
- [ ] 等待約 90–150 秒，畫面顯示生成圖與下載按鈕
- [ ] （選用）PowerShell 測試 API：`Invoke-RestMethod -Uri "http://localhost:3000/api/career_photo" -Method Post -Body '{"image_url":"https://example.com/face.jpg","career":"醫生"}' -ContentType "application/json" -TimeoutSec 180`

---

## 9.5 相關文件

- **本機測試詳情**：[08-STEP-BY-STEP-GUIDE.md](08-STEP-BY-STEP-GUIDE.md)
- **LINE / Make 串接**：[07-LINE-AND-FACE-SCENARIO.md](07-LINE-AND-FACE-SCENARIO.md)
- **API 金鑰**：[05-API-KEYS-INJECTION.md](05-API-KEYS-INJECTION.md)
