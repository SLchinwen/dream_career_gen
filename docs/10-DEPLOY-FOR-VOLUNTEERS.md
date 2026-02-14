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
   | `SECRET_KEY_BASE` | （選填）執行 `rails secret` 產生 | 若未設，容器啟動時會自動產生，建議正式環境自行設定 |

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
- 已設定 startup probe：首次檢查延遲 120 秒，讓 Rails 有時間啟動
- 確認透過 **git push → Cloud Build** 部署（勿只從 Cloud Console 點「部署」重複使用舊映像）
- 若仍失敗：至 Cloud Logging 查看該修訂版本日誌

### 志工開啟網址出現 Blocked hosts

- 確認 `config/environments/production.rb` 中的 `config.hosts` 包含 Cloud Run 網址
- 重新 push 並觸發建置

### 生成時出現「API 金鑰未設定」

- 至 Cloud Run → 變數與密碼，確認 `GEMINI_API_KEY` 已正確設定
- 重新部署新修訂

### 429 配額／Resource exhausted

- 程式會自動重試最多 3 次（延遲 5、10、20 秒）
- 若仍失敗：前往 [GCP API 配額](https://console.cloud.google.com/apis/api/generativelanguage.googleapis.com/quotas)、[Google AI Studio](https://aistudio.google.com/) 檢查用量
- 考慮啟用計費或等待免費額度重置

### API 金鑰曾出現在日誌或截圖中

- **請立即至 [Google AI Studio](https://aistudio.google.com/apikey) 撤銷該金鑰並產生新的**
- 在 Cloud Run 變數與密碼中更新為新金鑰後重新部署

### 部署後仍是舊版頁面

- 清除瀏覽器快取後重新整理
- 確認 Cloud Build 建置完成、Cloud Run 已換成新 revision

### 建置失敗：Failed to clone 'rid3510'（could not read Username for 'https://github.com'）

子模組 **rid3510** 為**私人 GitHub repo** 時，Cloud Build 需要 GitHub 憑證才能 clone。請依下列步驟設定：

1. **建立 GitHub Personal Access Token**
   - 開啟 [GitHub → Settings → Developer settings → Personal access tokens](https://github.com/settings/tokens)
   - 產生新 token（Classic），勾選權限 **repo**（可讀私人 repo）
   - 複製產生的 token（只顯示一次，請妥善保存）

2. **在 GCP Secret Manager 建立 secret**
   - 開啟 [Secret Manager](https://console.cloud.google.com/security/secret-manager)（專案 green-miracle-dream）
   - 點「建立密碼」→ 名稱填 **GH_TOKEN** → 密碼值貼上剛才的 GitHub token → 建立

3. **授權 Cloud Build 讀取該 secret**
   - 到 [IAM 與管理員 → IAM](https://console.cloud.google.com/iam-admin/iam)
   - 找到 **Cloud Build 服務帳戶**（通常為 `專案編號@cloudbuild.gserviceaccount.com`）
   - 編輯該帳戶 → 新增角色 **Secret Manager 密碼存取者**（Secret Manager Secret Accessor）
   - 若需限定只給某個 secret，可在 Secret Manager 中對該 secret 的「權限」新增上述服務帳戶為「密碼存取者」

4. **確認 cloudbuild.yaml**
   - 專案中 `cloudbuild.yaml` 已設定使用 `projects/green-miracle-dream/secrets/GH_TOKEN/versions/latest`
   - 若您的 GCP 專案 ID 不同，請修改 `cloudbuild.yaml` 裡的 `projects/您的專案ID/secrets/GH_TOKEN/versions/latest`

完成後重新 push 或手動觸發建置即可。

---

## 相關文件

- **同步與環境**：[SYNC_AND_ENV.md](../SYNC_AND_ENV.md)
- **API 金鑰**：[05-API-KEYS-INJECTION.md](05-API-KEYS-INJECTION.md)
- **本機開發**：[README.md](../README.md)
