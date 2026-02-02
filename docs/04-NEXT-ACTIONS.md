# 4. 下一步行動與前置條件

> 維護時可引用：**開工前檢查、金鑰與環境、交接與維運**。

---

## 4.0 目前進度與「接下來做什麼」

| 階段 | 狀態 | 下一步 |
|------|------|--------|
| 第 0 階段（雲端地基） | ✅ 已完成 | — |
| 第 1 階段（賦予靈魂） | ✅ 已完成 | — |
| 第 2 階段（打造店面） | ✅ 已完成 | — |
| **第 3 階段（記憶與分享）** | 💾 **待開始** | GCS、作品牆、QR Code 分享 |

**已完成項目：**

1. **準備金鑰**：Replicate、Gemini API 金鑰（見 [05-API-KEYS-INJECTION.md](05-API-KEYS-INJECTION.md)）
2. **Gemini**：`GeminiService` 依職業產生 25 歲擬真 Prompt
3. **Replicate**：`AgeProgressionService`（SAM）、`InstantIdService`（InstantID）
4. **後端 API**：`POST /api/career_photo`，參數 `image_url`、`career`
5. **Web 表單**：`/career_photo` 頁面，上傳／網址、職業、載入、下載

---

## 4.1 第 1 階段開工前：API 金鑰

要開始 **「第 1 階段：賦予靈魂」**，需先將下列 API 金鑰安全地放入專案（例如 Rails credentials 或環境變數，勿提交明文至 Git）：

| 金鑰 | 用途 | 取得／說明 |
|------|------|------------|
| **Replicate API Token** | 呼叫 Replicate 繪圖（Flux / SDXL） | 至 [Replicate](https://replicate.com) 註冊並取得 |
| **Google Gemini API Key** | 產生繪圖用 Prompt | 至 [Google AI Studio](https://aistudio.google.com/) 或 GCP 取得 |

**請確認：**  
兩組金鑰皆已準備並可安全注入至本專案（開發／staging／production 依環境分別設定）。**注入步驟**見 [05-API-KEYS-INJECTION.md](05-API-KEYS-INJECTION.md)。

---

## 4.2 下一步行動建議

1. **若金鑰已就緒**  
   開始撰寫第一行 AI 串接程式碼：Gemini Service、Replicate Service，以及對應的 Controller / 背景任務。
2. **若尚未就緒**  
   先完成金鑰申請與本機／CI／GCP 的注入方式（見 [SYNC_AND_ENV.md](../SYNC_AND_ENV.md) 與 `config/credentials`），再進行串接。

---

## 4.3 維護與交接

* 金鑰存放方式變更時，請更新本文件與 `SYNC_AND_ENV.md`。
* 新環境（例如第二個 GCP 專案）部署時，請檢查環境變數與 Host 白名單（`config/environments/production.rb`）。
