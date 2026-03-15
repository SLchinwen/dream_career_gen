# GCP 服務檢視與發布管理建議

> 本 repo 在 **Google Cloud Platform（GCP）** 上建立的服務、發布流程與維護建議。供日常發布、交接與維運參考。

---

## 一、目前建立了哪些 GCP 服務

本專案在 **單一 GCP 專案**（`green-miracle-dream`）內使用以下資源，**對外只有一個 Cloud Run 服務**，其餘為支援用。

| 類型 | 名稱／識別 | 用途 |
|------|------------|------|
| **Cloud Run 服務** | `dream-career-service` | 唯一對外服務，地區 `asia-east1`。承載：夢想職人照、RID3510 聊天、People of Action 評分、導覽首頁、健康檢查等。 |
| **Cloud Build** | 綁定 `dream_career_gen` 的 main 分支 | push 到 main 時依 `cloudbuild.yaml` 建置 Docker 映像並部署到上述 Cloud Run。 |
| **Artifact Registry** | `asia-east1-docker.pkg.dev/green-miracle-dream/dream-repo/dream-app` | 存放建置出的容器映像（tag 為 `$COMMIT_SHA`）。 |
| **Secret Manager** | `GH_TOKEN`（選用） | 當 rid3510 子模組為私人 repo 時，供 Cloud Build 拉取子模組。 |
| **Cloud Memorystore（Redis）** | 例：`rid3510-chat`（選用） | RID3510 聊天 10 輪對話儲存；需 VPC、Cloud Run 設 Direct VPC egress 與 `REDIS_URL`。 |

**重要**：對外「服務」只有 **一個**：`dream-career-service`。同一服務內有多個「功能／路徑」（見 `config/service_nav.yml` 與 `config/routes.rb`），不是多個 Cloud Run 服務。

---

## 二、發布流程總覽

### 2.1 主線：改 dream_career_gen 程式或想重新部署

```
dream_career_gen 本機
  → git add / commit / push origin main
  → GCP Cloud Build 觸發（若已綁定 repo）
  → 建置：git submodule update → docker build → push 映像到 Artifact Registry
  → 部署：gcloud run deploy dream-career-service（asia-east1）
  → 線上即為新版本
```

- **觸發條件**：push 到 **main**（需在 GCP Console 的 Cloud Build 已設定「推送到 main 即建置」）。
- **建置設定**：專案根目錄 `cloudbuild.yaml`。
- **若只想觸發重新部署、程式沒改**：`git commit --allow-empty -m "chore: 觸發重新部署"` 再 push。

### 2.2 只改 Rid3510 知識庫、要讓聊天機器人用新內容

有三種常見做法（擇一或並用）：

| 方式 | 誰做什麼 | 何時生效 |
|------|----------|----------|
| **手動** | 在 dream_career_gen 執行 `git submodule update --remote rid3510` → `git add rid3510` → commit → push | push 後建置完成即生效 |
| **排程／手動 Sync** | dream_career_gen 的 GitHub Actions：`.github/workflows/sync-rid3510.yml`（每日 00:00 UTC 或手動 Run / repository_dispatch） | 排程跑完或手動觸發後，有變更會 push 並觸發建置 |
| **Rid3510 觸發（3A）** | 在 GCP 另建「Rid3510 push 時觸發」的 Cloud Build，執行 rid3510 的 `cloudbuild-3a.yaml`（拉 dream_career_gen、塞入最新 Rid3510、建置、部署） | Rid3510 push 後數分鐘內 |

詳見：`docs/19-驗證與重新部署步驟.md`、`docs/24-RID3510-知識庫自動更新部署.md`、rid3510 的 `docs/更新3510文件後-觸發聊天機器人知識庫更新.md`。

---

## 三、建議：如何管理要發布的程式與維護

### 3.1 單一發布入口（建議維持）

- **一個 repo 對應一個 Cloud Run 服務**：所有功能（職人照、聊天、評分）都在 **dream-career-service**，由 **dream_career_gen** 的 main 分支決定要發布的程式。
- **好處**：環境變數、網址、權限只管理一處；建置與部署流程單一，較不易出錯。
- **建議**：除非有明確需求（例如拆成多區域、多環境），否則維持「push main → 一個 Cloud Build → 一個 Cloud Run 服務」。

### 3.2 發布前自檢（本機）

在 `git push` 前建議：

1. **確認沒把金鑰或 .env 提交**：見 `docs/06-GIT-GOVERNANCE.md`。
2. **有改路由或對外服務時**：更新 `config/service_nav.yml`，見 `docs/21-服務導覽與發布治理.md`。
3. **有改 Rid3510 相關**：若只改子模組內容，先確認 rid3510 已在自己 repo push，再在主專案做 submodule 更新並一併 commit。

### 3.3 分支與環境策略（可選）

目前設計是 **main = 生產**，push 即部署。若日後要區分「測試／正式」：

- **做法 A**：保留 main 為生產，另開 `staging` 分支，在 GCP 建第二個 Cloud Build 觸發條件（例如 push 到 staging 時部署到同專案另一個 Cloud Run 服務，如 `dream-career-staging`）。
- **做法 B**：維持單一服務，用 Cloud Run 的「修訂版本」與流量百分比做金絲雀（較進階）。

現階段若只有一個環境，維持 **main 即生產** 即可。

### 3.4 環境變數與密鑰

- **Cloud Run**：所有金鑰與設定在 **Cloud Run → dream-career-service → 編輯與部署新修訂 → 變數與密碼** 設定（如 `GEMINI_API_KEY`、`RAILS_ENV`、`REDIS_URL` 等）。勿寫進程式碼或 repo。
- **建置階段**：子模組若為私人 repo，用 **Secret Manager** 的 `GH_TOKEN`，由 `cloudbuild.yaml` 引用；見 `docs/10-DEPLOY-FOR-VOLUNTEERS.md`。
- **建議**：在團隊內維護一份「環境變數清單」（可放私有維運文件），列出變數名稱、用途、是否必填，方便交接與除錯。

### 3.5 知識庫（Rid3510）更新流程

- **日常**：在 **Rid3510** repo 改 `docs/`、`rag-intent-paths.yaml` 等，push 到 main。
- **要讓線上聊天機器人更新**：
  - **手動**：到 dream_career_gen 執行 submodule 更新 → commit rid3510 → push（見 `docs/19-驗證與重新部署步驟.md` 第五節）。
  - **自動**：依 `docs/24-RID3510-知識庫自動更新部署.md` 設定 sync-rid3510 排程或 Rid3510 的 repository_dispatch；或啟用 GCP 方式 3A（Rid3510 push 觸發建置）。

### 3.6 維運檢查清單（定期）

| 項目 | 頻率建議 | 說明 |
|------|----------|------|
| Cloud Build 建置是否成功 | 每次 push 後 | 到 GCP Console → Cloud Build 看最新建置。 |
| Cloud Run 修訂版本與流量 | 部署後 | 確認新 revision 已接收 100% 流量。 |
| 環境變數與 Secret | 季度或變更時 | 確認金鑰有效、未過期；Redis 等連線仍可用。 |
| 服務導覽與文件 | 發布新 API／頁面時 | 更新 `config/service_nav.yml`；必要時更新 `docs/`。 |
| 成本與配額 | 每月 | 到 GCP 計費與配額頁檢視 Cloud Run、Gemini API 等用量。 |

### 3.7 其他部署方式（本 repo 內、非 GCP）

- **config/deploy.yml**：為 **Kamal** 部署用，目標為自架主機（例：`192.168.0.1`），**不是** GCP。若目前只使用 GCP Cloud Run，可忽略或保留作未來自架備援。
- **rid3510/cloudbuild-3a.yaml**：供「由 Rid3510 push 觸發 GCP 建置」使用，需在 GCP 手動建立對應觸發條件，見 rid3510 的 `docs/方式3A-GCP-Cloud-Build-觸發Rid3510-一步一步.md`。

---

## 四、快速對照表

| 我想… | 做法 |
|-------|------|
| 改 Rails 程式並上線 | 在 dream_career_gen 本機 commit → push main → 等 Cloud Build 完成。 |
| 只觸發重新部署（程式沒改） | `git commit --allow-empty -m "chore: 觸發重新部署"` → push main。 |
| 只改 Rid3510 知識庫並讓聊天用新內容 | Rid3510 push 後，到 dream_career_gen 做 submodule update → add rid3510 → commit → push；或依 24 與 19 用 Sync workflow／3A。 |
| 查目前對外有哪些網頁／API | 看 `config/service_nav.yml` 或部署後首頁導覽。 |
| 查 GCP 專案／服務名稱 | 專案：`green-miracle-dream`；Cloud Run 服務：`dream-career-service`；地區：`asia-east1`。 |
| 設環境變數或密鑰 | GCP Console → Cloud Run → dream-career-service → 編輯與部署新修訂 → 變數與密碼。 |

---

## 五、相關文件

| 主題 | 文件 |
|------|------|
| 志工發布與環境變數 | [10-DEPLOY-FOR-VOLUNTEERS.md](10-DEPLOY-FOR-VOLUNTEERS.md) |
| 重新部署與驗證 | [19-驗證與重新部署步驟.md](19-驗證與重新部署步驟.md) |
| 服務導覽與發布治理 | [21-服務導覽與發布治理.md](21-服務導覽與發布治理.md) |
| RID3510 知識庫自動更新 | [24-RID3510-知識庫自動更新部署.md](24-RID3510-知識庫自動更新部署.md) |
| Redis（Memorystore）設定 | [23-GCP-CLOUD-MEMORYSTORE-REDIS.md](23-GCP-CLOUD-MEMORYSTORE-REDIS.md) |
| 建置設定 | 專案根目錄 [cloudbuild.yaml](../cloudbuild.yaml) |

---

*本文件為 GCP 服務與發布管理之檢視與建議，實際 GCP 專案 ID、服務名稱以 Console 與 cloudbuild.yaml 為準。*
