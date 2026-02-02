# 2. 專案執行規劃 (Roadmap)

> 維護時可引用：**階段劃分、目前進度、各階段工作內容**。

---

## 階段總覽

| 階段 | 名稱 | 狀態 | 目標摘要 |
|------|------|------|----------|
| 第 0 階段 | 雲端地基 | ✅ 已完成 | GCP、Docker、CI/CD |
| 第 1 階段 | 賦予靈魂 | ✅ 已完成 | 串接 Gemini、Replicate（SAM、InstantID），後端 API |
| 第 2 階段 | 打造店面 | ✅ 已完成 | Web 表單、載入動畫、成果展示、下載功能 |
| 第 3 階段 | 記憶與分享 | 💾 待開始 | 雲端相簿、作品牆、QR Code 分享 |

---

## ✅ 第 0 階段：雲端地基（已完成）

* 建立 Google Cloud 專案與權限設定。
* 建置 Docker 化環境（`Dockerfile`）。
* 設定 CI/CD 自動化部署流程（`cloudbuild.yaml`）。
* **成果：** 推送程式碼後，網站可透過 Cloud Build 自動部署並在全球更新。

---

## ✅ 第 1 階段：賦予靈魂（已完成）

**目標：** 讓網站「能看能寫」。

**工作內容：**

1. **串接 Gemini**  
   讓系統能依職業產生 25 歲擬真英文繪圖 Prompt（`GeminiService`）。
2. **串接 Replicate**  
   - 年齡變化：`AgeProgressionService`（SAM 模型）將人臉長大至約 30 歲  
   - 職業照生成：`InstantIdService`（InstantID Photorealistic）保留臉部特徵產生擬真圖
3. **後端 API**  
   `POST /api/career_photo`，參數 `image_url`、`career`，回傳 `image_url`。

**前置條件：** 需具備 Replicate API Token 與 Google Gemini API Key（見 [04-NEXT-ACTIONS.md](04-NEXT-ACTIONS.md)）。

---

## ✅ 第 2 階段：打造店面（已完成）

**目標：** 讓使用者（家長、志工）能輕鬆操作。

**工作內容：**

1. **輸入表單**  
   `/career_photo` 頁面：圖片網址或上傳、職業下拉選單、學生代號（選填）。
2. **載入與逾時**  
   AI 運算期間（約 90–150 秒）顯示載入文字與計時器。
3. **成果展示**  
   顯示生成照片、總耗時、下載按鈕。

---

## 💾 第 3 階段：記憶與分享（資料庫與儲存）

**目標：** 讓成果可被保存與分享。

**工作內容：**

1. **雲端相簿**  
   使用 Google Cloud Storage 永久儲存生成照片。
2. **作品牆 (Gallery)**  
   建立公開頁面展示孩童夢想照片（需考量隱私與授權設定）。
3. **QR Code 分享**  
   讓家長可掃碼下載照片至手機。

---

## 維護約定

* 階段狀態變更時，請更新本文件「階段總覽」與對應段落。
* Issue / PR 可引用階段編號，例如：`[第 1 階段] 串接 Gemini API`。
