# 11. 每張夢想職人照成本估算

> 依 Google Gemini API 與 Cloud Run 官方定價估算（付費方案）。實際依用量與地區可能略有差異。

---

## 服務流程與 API 呼叫

每生成一張圖會呼叫 **3 次 Gemini API**：

| 步驟 | 模型 | 用途 | 輸入 | 輸出 |
|------|------|------|------|------|
| 1 | `gemini-2.0-flash` | 臉部特徵描述 (Vision) | 1 張照片 + 文字 prompt | ~300 tokens 英文描述 |
| 2 | `gemini-2.0-flash` | 職業服裝／場景描述 | 職業名稱等文字 | ~80 tokens |
| 3 | `gemini-2.5-flash-image` | 產圖 (Imagen) | 合併後的文字 prompt | **1 張圖**（固定 $0.039/張） |

---

## Gemini API 成本（付費方案）

- **Gemini 2.0 Flash**：Input $0.10 / 1M tokens，Output $0.40 / 1M tokens  
- **Gemini 2.5 Flash Image**：Input $0.30 / 1M tokens，**Output $0.039 / 張圖**（約 1290 tokens/張）

| 項目 | 估算 token | 單次成本 (USD) |
|------|------------|----------------|
| Vision 輸入（圖+文） | ~900 | ~0.00009 |
| Vision 輸出 | ~350 | ~0.00014 |
| 職業描述 輸入 | ~50 | 可忽略 |
| 職業描述 輸出 | ~80 | ~0.00003 |
| 產圖 輸入（prompt） | ~250 | ~0.00008 |
| **產圖 輸出（1 張圖）** | 1 張 | **0.039** |
| **小計 Gemini** | — | **約 0.04** |

→ **每張圖 Gemini 約 0.04 USD（約 4 美分）**。

---

## Cloud Run 成本

- 每張圖 = 1 次 HTTP 請求，處理時間約 **15–45 秒**（取 30 秒估算）。
- 目前設定：**1 vCPU、1 GiB**，依請求計費（vCPU-second、GiB-second）。
- 參考：約 $0.000024 / vCPU-second、$0.0000025 / GiB-second（依地區略有不同）。

| 項目 | 估算 | 單次成本 (USD) |
|------|------|----------------|
| vCPU（30 秒） | 30 × 0.000024 | ~0.00072 |
| 記憶體（30 秒） | 30 × 0.0000025 | ~0.00008 |
| **小計 Cloud Run** | — | **約 0.0008** |

→ **每張圖 Cloud Run 約 0.001 USD（約 0.1 美分）**。

---

## 總計（每張圖）

| 項目 | 約略成本 (USD) |
|------|----------------|
| Gemini API | ~0.04 |
| Cloud Run | ~0.001 |
| **合計** | **約 0.04–0.05 USD / 張** |

- 以 **1 USD ≈ 32 TWD** 粗估：**約 1.3–1.6 元新台幣 / 張**。
- 實際請以 [Gemini 定價](https://ai.google.dev/gemini-api/docs/pricing)、[Cloud Run 定價](https://cloud.google.com/run/pricing) 與帳單為準。

---

## 免費額度

- **Gemini**：免費方案有每日/每月 token 上限，超出後需付費或等重置。
- **Cloud Run**：每月有免費 vCPU-minute、GiB-minute 等額度，小用量可能仍在免費範圍內。

若在免費額度內，每張圖的 **Gemini 成本可能為 0**，僅需留意配額與 429 錯誤。

---

## 參考連結

- [Gemini API 定價](https://ai.google.dev/gemini-api/docs/pricing)
- [Cloud Run 定價](https://cloud.google.com/run/pricing)
- [GCP 計費](https://console.cloud.google.com/billing)
