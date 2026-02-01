# 同步與環境檢查清單

## 一、與 GitHub 同步狀態

**目前狀態：尚未同步完成**

- 本地分支 `main` **領先** `origin/main` **1 個 commit**。
- 尚未推送的 commit：`6c30c90` — "Allow Cloud Run host, exclude /up for health check"（修正 GCP Blocked hosts 的設定）。

**請在本機執行：**

```powershell
cd c:\github\dream_career_gen
git push origin main
```

推送成功後，GitHub 上就會有最新的 `production.rb` 設定，GCP 再重新部署後就不會再出現 Blocked hosts 錯誤。

---

## 二、需要處理的環境項目

### 1. 先完成推送與 GCP 重新部署（解決 Blocked hosts）

| 步驟 | 說明 |
|------|------|
| 推送 | 執行 `git push origin main`，讓 GitHub 取得最新程式碼。 |
| 重新部署 GCP | 在 GCP Console 的 Cloud Build 觸發一次建置，或使用 `gcloud builds submit`，讓 Cloud Run 使用含 Host 白名單的新 image。 |

### 2. GCP / Cloud Run 環境變數（可選）

- **RAILS_ENV**：應為 `production`（Cloud Run 預設不一定會設，若未設可手動加）。
- **RAILS_MASTER_KEY**：若 production 有使用 `credentials`，需在 Cloud Run 服務的「變數與密碼」中設定，值從本機 `config/master.key` 取得（勿提交到 Git）。
- **PORT**：Cloud Run 會自動注入 `8080`，若 Dockerfile/Rails 使用 3000，需在 Cloud Run 設定 `PORT=3000`，或改為接受 `ENV["PORT"]`（你的 `puma.rb` 已用 `ENV.fetch("PORT", 3000)`，理論上沒問題）。

### 3. 本機 / CI 環境

- **GitHub Actions**（`.github/workflows/ci.yml`）：測試使用 `RAILS_ENV=test`，目前未使用 `RAILS_MASTER_KEY`（註解狀態），若之後 test 需要 credentials 再在 repo secrets 設定。
- **專案內無 `.env` 檔**：敏感設定依賴 `config/credentials.yml.enc` + `config/master.key`，production 部署時記得在 GCP 設定 `RAILS_MASTER_KEY`。

### 4. 之後若要再確認同步

在本機執行：

```powershell
git fetch origin
git status
```

- 若顯示 "Your branch is up to date with 'origin/main'" 且 "nothing to commit"，表示已與 GitHub 同步完成。
