# 同步與環境檢查清單

## 一、與 GitHub 同步狀態

**目前狀態：** 請在本機執行 `git status` 查看；若顯示 "Your branch is up to date with 'origin/main'" 且 "nothing to commit"，即表示已與 GitHub 同步完成。

**若有未推送的 commit**（顯示 "Your branch is ahead of 'origin/main' by N commit(s)"），請在本機執行：

```powershell
cd c:\github\dream_career_gen
git push origin main
```

---

## 一之一、同步錯誤時可以怎麼做

若在 Cursor 或用指令做 push / sync 時出現錯誤，可依序嘗試：

| 步驟 | 你做什麼 |
|------|----------|
| 1. 用終端機再試一次 | 在 Cursor 開終端機（Ctrl+`），執行 `cd c:\github\dream_career_gen` 後再執行 `git push origin main`，看終端機顯示的錯誤訊息。 |
| 2. 確認有先 commit | 若有改過檔案，先執行 `git add .`、`git commit -m "你的訊息"`，再執行 `git push origin main`。 |
| 3. 檢查網路與 GitHub | 確認能連上網、能開 github.com；若公司有 proxy，需設定 Git 的 proxy 或改用 SSH。 |
| 4. 檢查登入方式 | **HTTPS：** 密碼需用 GitHub 的 **Personal Access Token (PAT)**，不能用帳號密碼。**SSH：** 若已設 SSH key，可改遠端為 `git remote set-url origin git@github.com:SLChinwen/dream_career_gen.git` 再 push。 |
| 5. 確認沒有鎖檔 | 關掉其他會用 Git 的程式（其他 IDE、Git GUI），刪除專案內 `.git/index.lock`（若存在），再重試 push。 |

**記下錯誤訊息：** 終端機或 Cursor 顯示的英文錯誤（例如 `Permission denied`、`Failed to connect`）有助於進一步排查。

---

## 二、需要處理的環境項目

### 1. Blocked hosts 仍出現時：請依序做這三件事

| 步驟 | 你做什麼 | 說明 |
|------|----------|------|
| 1. 推送 | 在本機執行 `git push origin main` | 讓 GitHub 上有最新的 `config/environments/production.rb`（含 Host 白名單）。 |
| 2. 重新建置 | 在 GCP Console 開啟 **Cloud Build → 歷史紀錄**，對你的 repo 觸發一次 **「提交」建置**（或手動執行建置） | 會用 GitHub 上最新程式碼建新 image，不會用舊的。 |
| 3. 等部署完成 | 等 Cloud Run 換成新 revision | 換好後再開 `dream-career-service-225291605101.asia-east1.run.app` 就不應再出現 Blocked hosts。 |

**重要：** 只改程式碼或只 push 而不重新建置／部署，Cloud Run 仍會跑舊 image，所以畫面上還是會錯。一定要 **push → 觸發建置 → 等部署完成**。

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
