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

維護或開發時可直接引用上述路徑（例如：`見 docs/02-ROADMAP.md`）。

---

## 技術棧

* **框架：** Ruby on Rails 8  
* **部署：** Google Cloud Platform（Cloud Run + Cloud Build）  
* **AI：** Google Gemini API（文案／Prompt）、Replicate API（繪圖）

---

## 本機開發

* **Ruby 版本：** 見 [.ruby-version](.ruby-version)  
* **安裝：** `bundle install`  
* **啟動：** `bin/dev` 或 `bin/rails server`  
* **測試：** `bin/rails test`  
* **部署：** 見 [cloudbuild.yaml](cloudbuild.yaml)、[SYNC_AND_ENV.md](SYNC_AND_ENV.md)
