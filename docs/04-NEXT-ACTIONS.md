# 4. 下一步行動與前置條件

> 維護時可引用：**開工前檢查、金鑰與環境、交接與維運**。

---

## 4.0 目前進度與「接下來做什麼」

| 階段 | 狀態 | 下一步 |
|------|------|--------|
| 第 0 階段（雲端地基） | ✅ 已完成 | — |
| **第 1 階段（賦予靈魂）** | 🚀 **目前要做** | ① 準備 API 金鑰 → ② 串接 Gemini → ③ 串接 Replicate → ④ 後端 Service / Controller |
| 第 2 階段（打造店面） | 🎨 待開始 | 第 1 階段完成後：表單、載入動畫、成果展示頁 |
| 第 3 階段（記憶與分享） | 💾 待開始 | 第 2 階段完成後：GCS、作品牆、QR Code |

**可執行的下一步（依序）：**

1. ~~**準備金鑰**~~ ✅  
   取得 [Replicate API Token](https://replicate.com) 與 [Google Gemini API Key](https://aistudio.google.com/)，並用 Rails credentials 或環境變數注入（勿提交明文）。
2. ~~**串接 Gemini**~~ ✅  
   `app/services/gemini_service.rb` 已完成：輸入「夢想描述」與可選性別／年齡，回傳英文繪圖用 Prompt。
3. **串接 Replicate**  
   新增 `app/services/replicate_service.rb`：輸入 Prompt，呼叫 Flux 或 SDXL 模型，回傳圖片 URL。
4. **後端流程**  
   新增 Controller（或 Job）：接收參數 → 呼叫 Gemini → 呼叫 Replicate → 回傳結果（或儲存後導向成果頁）。
5. **第 2 階段**  
   再做輸入表單、載入動畫、成果展示頁（見 [02-ROADMAP.md](02-ROADMAP.md)）。

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
