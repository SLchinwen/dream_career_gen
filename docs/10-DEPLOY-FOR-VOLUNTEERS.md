# 10. 發布給志工使用

> 本機測試完成後，將夢想職人照部署到雲端，供志工透過網址使用。

---

## 發布流程總覽

| 步驟 | 說明 | 預估時間 |
|------|------|----------|
| 1 | 推送程式碼到 GitHub | 1 分鐘 |
| 2 | 設定 GCP Cloud Run 環境變數（GEMINI_API_KEY） | 5 分鐘 |
| 3 | 觸發 Cloud Build 建置與部署 | 5–15 分鐘 |
| 4 | 取得網址，提供給志工 | — |

---

## 步驟一：推送程式碼

在本機專案目錄執行：

```powershell
cd c:\github\dream_career_gen

git add .
git status
git commit -m "產品化完成：夢想職人照"
git push origin main
```

確認沒有錯誤、程式碼已同步到 GitHub。

---

## 步驟二：設定 GCP 環境變數

1. 開啟 [Google Cloud Console](https://console.cloud.google.com/)
2. 選擇專案 **green-miracle-dream**（或你的 GCP 專案）
3. 左側選單 → **Cloud Run** → 點選服務 **dream-career-service**
4. 點擊 **「編輯與部署新修訂」**
5. 切到 **「變數與密碼」**（Variables & Secrets）
6. 新增環境變數：

   | 變數名稱 | 值 | 說明 |
   |----------|-----|------|
   | `GEMINI_API_KEY` | 你的 Google Gemini API Key | **必填**，主產品需此金鑰 |
   | `RAILS_ENV` | `production` | 建議設定 |

7. 若有使用進階版（Replicate），可加 `REPLICATE_API_TOKEN`
8. 點擊 **「部署」**

---

## 步驟三：觸發建置與部署

### 方式 A：Git 已連動 Cloud Build（建議）

若專案已設定「推送到 main 即自動建置」：

- 完成步驟一 `git push` 後，Cloud Build 會自動執行
- 至 [Cloud Build 歷史紀錄](https://console.cloud.google.com/cloud-build/builds) 查看建置進度

### 方式 B：手動觸發建置

1. 開啟 [Cloud Build 歷史紀錄](https://console.cloud.google.com/cloud-build/builds)
2. 點擊 **「提交」** 或 **「執行觸發程序」**
3. 選擇 repo `dream_career_gen`、分支 `main`
4. 執行建置

### 等候部署完成

- 建置約 5–15 分鐘
- 完成後 Cloud Run 會自動切換到新版本

---

## 步驟四：取得網址並提供志工

部署完成後，取得服務網址，例如：

```
https://dream-career-service-225291605101.asia-east1.run.app
```

- 實際網址請至 Cloud Run → 服務 `dream-career-service` → **「詳細資訊」** 中查看
- 將此網址提供給志工，可直接在手機或電腦瀏覽器開啟使用

---

## 檢查清單

- [ ] 程式碼已 push 到 GitHub main
- [ ] Cloud Run 已設定 `GEMINI_API_KEY`
- [ ] Cloud Build 建置成功
- [ ] 開啟網址可看到「夢想職人照」頁面
- [ ] 實際上傳照片、選擇職業，可成功生成圖片

---

## 常見問題

### 部署失敗：container failed to start and listen on PORT

- 專案已改為使用 Cloud Run 預設 port **8080**
- 請勿在 Cloud Run 環境變數中設定 `PORT=3000`（若有請刪除）
- 重新 push 程式碼並觸發建置，讓新 Dockerfile 生效

### 志工開啟網址出現 Blocked hosts

- 確認 `config/environments/production.rb` 中的 `config.hosts` 包含 Cloud Run 網址
- 重新 push 並觸發建置

### 生成時出現「API 金鑰未設定」

- 至 Cloud Run → 變數與密碼，確認 `GEMINI_API_KEY` 已正確設定
- 重新部署新修訂

### 部署後仍是舊版頁面

- 清除瀏覽器快取後重新整理
- 確認 Cloud Build 建置完成、Cloud Run 已換成新 revision

---

## 相關文件

- **同步與環境**：[SYNC_AND_ENV.md](../SYNC_AND_ENV.md)
- **API 金鑰**：[05-API-KEYS-INJECTION.md](05-API-KEYS-INJECTION.md)
- **本機開發**：[README.md](../README.md)
