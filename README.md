# dream-career-gen（夢想職人生成器）

結合 AI 算圖與公益願景的 Web 應用：協助扶輪社／綠色奇蹟等活動，讓孩童看見「未來夢想成真」的模樣。

---

## 專案治理與規劃文件

**願景、目標、階段規劃與下一步** 請見 **[docs/](docs/)** 目錄：

| 文件 | 說明 |
|------|------|
| [docs/README.md](docs/README.md) | 治理文件索引 |
| [docs/01-VISION-AND-GOALS.md](docs/01-VISION-AND-GOALS.md) | 願景、定位、技術棧 |
| [docs/02-ROADMAP.md](docs/02-ROADMAP.md) | 階段規劃（第 0～3 階段） |
| [docs/03-USER-STORY.md](docs/03-USER-STORY.md) | 使用情境與流程 |
| [docs/04-NEXT-ACTIONS.md](docs/04-NEXT-ACTIONS.md) | 下一步行動與 API 金鑰說明 |
| [docs/08-STEP-BY-STEP-GUIDE.md](docs/08-STEP-BY-STEP-GUIDE.md) | 一步一步操作（Web ＋ Make + LINE） |
| [docs/09-PRODUCT-SERVICE-STEPS.md](docs/09-PRODUCT-SERVICE-STEPS.md) | 產品服務步驟定義 |

維護或開發時可直接引用上述路徑（例如：`見 docs/02-ROADMAP.md`）。

---

## 技術棧

* **框架：** Ruby on Rails 8  
* **部署：** Google Cloud Platform（Cloud Run + Cloud Build）  
* **AI：** Google Gemini API（Prompt）、Replicate（SAM 年齡變化、InstantID 擬真職業照）

---

## 本機開發與測試

* **Ruby 版本：** 見 [.ruby-version](.ruby-version)  
* **安裝：** `bundle install`  
* **API 金鑰：** 主產品僅需 `GEMINI_API_KEY`；進階版需 `REPLICATE_API_TOKEN`（見 [docs/05-API-KEYS-INJECTION.md](docs/05-API-KEYS-INJECTION.md)）  
* **啟動：** `ruby bin/dev` 或 `ruby bin/rails server`（Windows 需加 `ruby` 前綴，避免「選取應用程式」對話框）  
* **Web 版測試：** 開啟 `http://localhost:3000`，上傳照片、選擇夢想職業，約 10–30 秒生成夢想職人照  
* **測試：** `bin/rails test`  
* **部署：** 見 [cloudbuild.yaml](cloudbuild.yaml)、[SYNC_AND_ENV.md](SYNC_AND_ENV.md)  
* **發布給志工：** 見 [docs/10-DEPLOY-FOR-VOLUNTEERS.md](docs/10-DEPLOY-FOR-VOLUNTEERS.md)  
* **產品服務步驟：** 見 [docs/09-PRODUCT-SERVICE-STEPS.md](docs/09-PRODUCT-SERVICE-STEPS.md)
