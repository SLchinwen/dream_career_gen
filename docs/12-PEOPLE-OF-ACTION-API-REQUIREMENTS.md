# People of Action 投稿評分 API — 需求確認與建置建議

## 1. 文件目的

- 對齊 SOP、KB 與實際 API 設計
- 確認「相片＋說明」自評 API 與「社群連結→影響力」API 的介面與授權方式
- 供開發與主辦單位共同確認後再實作

---

## 2. 需求摘要（依你提供之 SOP／KB）

| 項目 | 說明 |
|------|------|
| **評分制度** | 自評 0–40 ＋ 影響力 0–30 ＋ 評審 0–30 ＝ 總分 100 |
| **投稿資料** | 投稿圖片、說明文字（約 100 字）、社群外連網址 |
| **API 目標** | (1) 依 KB 對「相片＋說明」做 People of Action 自評；(2) 依社群連結取得按讚／留言／分享作為影響力（第一版若無法讀取則由前端／使用者輸入） |

### 2.1 自評觸發方式（已確認）

- **People of Action 自評** 由 **系統排程觸發**，不即時由使用者手動呼叫。
- 排程依投稿清單 **逐筆** 呼叫自評 API，每筆完成後寫回該筆評分結果；全部完成即視為自評階段完成。
- API 設計需支援此「逐筆、可重試」的呼叫方式（例如單筆無狀態、可選傳 `submission_id` 以便對應寫回）。

---

## 3. API 一：相片 ＋ 100 字介紹 → People of Action 自評

### 3.1 功能描述

- **輸入**：一張投稿相片 ＋ 約 100 字服務說明
- **觸發**：由 **系統排程** 逐筆呼叫本 API，完成後該筆即完成評分（非使用者即時操作）。
- **處理**：以 **People of Action 知識庫（KB）** 為唯一依據，由 AI 判斷：
  - 是否符合「人＋行動＋影響」三元素
  - 依 KB-05 加分／扣分指標給出量化分數
  - 圖片與文字是否一致（KB-04：圖片優先於文字）
- **輸出**：自評分數 ＋ 可選簡短評語（方便評審觀看順序與後續討論）

### 3.2 分數對應（需你確認）

- **KB-05** 為 0–30 分（加分總和 − 扣分總和，最低 0、最高 30）
- **SOP** 自評為 **0–40 分**

**建議方案（擇一或你指定）：**

| 選項 | 說明 |
|------|------|
| **A** | API 直接回傳 **0–30**，後端或前端再線性換算為 0–40（例如 × 40/30） |
| **B** | API 回傳 **0–40**，在 prompt 中約定：30 分滿分對應 40，按比例換算 |
| **C** | 維持 0–30，SOP 修正為自評滿分 30（與 KB 一致） |

請告知採用 A / B / C 或自訂規則。

### 3.3 建議 API 介面（供實作）

- 由 **排程系統** 依投稿清單逐筆呼叫，每筆獨立、可重試；可選傳 `submission_id` 供呼叫端對應寫回。

```http
POST /api/rotary/photo_scores
Content-Type: multipart/form-data
Authorization: Bearer <API_KEY>   # 或 X-API-Key: <API_KEY>

# 參數
photo: 檔案（必填）
description: 字串，約 100 字說明（必填）
submission_id: 字串（選填，供排程系統對應寫回該筆投稿）
```

**回應範例（JSON）：**

```json
{
  "score": 22,
  "score_max": 30,
  "summary": "符合 People、Action、Impact 三元素；社友實際行動與服務對象互動清楚。",
  "consistency": "一致",
  "breakdown": {
    "P1_社友實際行動": true,
    "P2_與服務對象互動": true,
    "P3_小型聚焦畫面": true,
    "P4_成果或改變": false,
    "P5_故事脈絡": true,
    "P6_情感或啟發": false,
    "N1_N6_扣分": []
  }
}
```

- `score` / `score_max`：依你確認的 A/B/C 可改為 0–40。
- `breakdown` 為可選，若不需要可簡化為只回 `score` + `summary`。

---

## 4. 影響力數據：社群連結與第一版策略（已確認）

### 4.1 社群範圍

- **支援平台**：**Facebook、Instagram、YouTube**。
- **第一版策略**：若無法由後端自動讀取按讚／留言／分享（例如無官方 API、不實作爬蟲），則 **不在此版實作自動取得**；改由 **前端讓使用者輸入** 影響力相關數據（例如按讚數、留言數、分享數，或直接輸入 0–30 影響力分數），以符合 SOP 影響力 0–30 的流程。

### 4.2 技術說明（供日後擴充）

- 真實的按讚／留言／分享需透過 **平台官方 API**（如 Meta Graph API、YouTube Data API）或爬蟲／第三方服務取得；AI 無法直接「讀取」網頁數字。
- 若日後要實作「社群連結 → 自動取得數據」API，再依平台（FB / IG / YouTube）個別整合；第一版以 **使用者於前端輸入** 為準。

### 4.3 第一版實作範圍

- **第一版不實作**「輸入社群連結 → 自動回傳按讚／留言／分享」之 API。
- 影響力數據改由 **前端表單** 提供：使用者輸入投稿的社群連結後，於同一或另一欄位 **手動輸入** 按讚數、留言數、分享數（或由主辦／行政依 SOP 換算後輸入影響力分數 0–30）。
- 若未來要新增「社群連結 → 自動取得」API，可再依 FB / IG / YouTube 各平台可行性單獨規劃。

---

## 5. 鎖定 API：只讓被授權者使用

建議採用 **API Key** 方式，與現有 dream_career_gen 金鑰管理一致。

### 5.1 做法概述

- 主辦單位／系統管理員為「授權使用者」產生一組 **API Key**（長隨機字串）。
- 呼叫上述兩個 API 時，在 request header 帶入該 Key：
  - `Authorization: Bearer <API_KEY>` 或
  - `X-API-Key: <API_KEY>`
- 後端在 `Api::Rotary::BaseController`（或各 controller）的 `before_action` 中驗證 Key：
  - 若 Key 存在且有效（例如與設定檔或 DB 比對）→ 通過
  - 若未帶 Key 或 Key 錯誤 → 回傳 `401 Unauthorized`

### 5.2 Key 存放方式（擇一）

| 方式 | 說明 |
|------|------|
| **環境變數** | 單一 Key：`ROTARY_API_KEY=xxx`，部署時注入（如 GCP Secret Manager） |
| **Rails credentials** | 放進 `credentials.yml.enc`，例如 `rotary_api_keys: [ "key1", "key2" ]`，支援多組 Key |
| **資料庫** | 若未來要「多社團、多 Key、可停用」再建 `api_keys` 表與後台管理 |

建議 **第一版用環境變數 `ROTARY_API_KEY`**，實作快、也易與現有 `GEMINI_API_KEY` 等一致。

### 5.3 回應規範

- 未帶 Key 或 Key 錯誤：`401` + `{"error": "Unauthorized"}`（或 `"Invalid or missing API key"`）
- 不洩漏 Key 是否「存在但錯誤」，僅統一回「未授權」

---

## 6. 建置順序建議

1. **知識庫內嵌**  
   將 People of Action KB（你提供的 md）整理成一份「系統 prompt」或獨立文字檔，由 Gemini 呼叫時一併傳入，確保 AI 不脫離 KB 評分。

2. **API 一：相片＋說明 → 自評**  
   - 實作 `POST /api/rotary/photo_scores`（multipart：photo + description）
   - 呼叫 Gemini（多模態：圖片 ＋ 文字 ＋ KB prompt），回傳結構化 JSON（score、summary、consistency 等）
   - 分數採用你確認的 0–30 或 0–40

3. **授權**  
   - 在 `Api::Rotary` 下共用的 `before_action :authenticate_rotary_api_key`
   - 讀取 `ENV["ROTARY_API_KEY"]` 或 credentials 比對

4. **影響力**  
   - 第一版不實作「社群連結 → 自動讀取按讚／留言／分享」；由前端讓使用者輸入影響力相關數據或分數。

5. **文件與部署**  
   - 在 `docs/` 補充「志工／主辦使用手冊」：如何取得 API Key、如何呼叫、範例（curl／Postman）
   - 部署時設定 `ROTARY_API_KEY`，不寫進程式碼

---

## 7. 待確認事項

| # | 項目 | 選項或說明 |
|---|------|------------|
| 1 | 自評分數滿分 | 採用 **0–30** 還是 **0–40**？若 40，是否按比例從 30 換算？ |
| 2 | API Key 發放 | 第一版是否 **一組 Key 共用**（環境變數）即可？或需要 **多組 Key**（多社團／多角色）？ |

**已確認：**

- 社群範圍：Facebook、Instagram、YouTube；第一版若無法讀取則不實作自動取得，改由 **前端讓使用者輸入**。
- People of Action 自評：由 **系統排程** 觸發，**逐筆** 呼叫 API 完成評分。

---

## 8. 實作狀態（本專案）

- **Web 試用**：`GET /rotary/photo_score` — 表單上傳相片＋說明，送出後顯示自評分數與評語（不需 API Key）。
- **排程用 API**：`POST /api/rotary/photo_scores` — 需在 Header 帶 `Authorization: Bearer <ROTARY_API_KEY>` 或 `X-API-Key: <ROTARY_API_KEY>`；Body 為 multipart：`photo`（必填）、`description`（必填）、`submission_id`（選填）。回傳 JSON：`score`、`score_max`、`summary`、`consistency`。
- **金鑰**：設定環境變數 `ROTARY_API_KEY` 或於 `rails credentials:edit` 加入 `rotary.api_key`。未設定時呼叫 API 會回傳 503。

**部署與排程串接**：雲端部署步驟與工程師 API 串接辦法（含 curl／Python 範例、排程建議）見 **[docs/13-DEPLOY-AND-ROTARY-API.md](13-DEPLOY-AND-ROTARY-API.md)**。
