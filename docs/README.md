# 專案治理與維護文件索引

本目錄存放 **dream-career-gen（夢想職人生成器）** 的願景、目標、規劃與行動清單，供開發與維護時引用。

| 文件 | 說明 | 引用時機 |
|------|------|----------|
| [01-VISION-AND-GOALS.md](01-VISION-AND-GOALS.md) | 結論、專案定位、技術棧 | 新成員 onboarding、決策依據、對外說明 |
| [02-ROADMAP.md](02-ROADMAP.md) | 階段規劃（第 0～3 階段） | 排程、sprint、功能開發順序 |
| [03-USER-STORY.md](03-USER-STORY.md) | 使用情境與流程 | 驗收條件、測試情境、產品說明 |
| [04-NEXT-ACTIONS.md](04-NEXT-ACTIONS.md) | 下一步行動與前置條件（如 API 金鑰） | 開工前檢查、交接、維運手冊 |
| [05-API-KEYS-INJECTION.md](05-API-KEYS-INJECTION.md) | API 金鑰注入方式（credentials / 環境變數） | 本機與 GCP 設定金鑰時引用 |
| [06-GIT-GOVERNANCE.md](06-GIT-GOVERNANCE.md) | Git 治理規範（不得提交 .env／金鑰、commit 前提醒） | 提交前自檢、新成員約定 |
| [07-LINE-AND-FACE-SCENARIO.md](07-LINE-AND-FACE-SCENARIO.md) | 自拍＋職業擬真情境、25 歲擬真圖、LINE 官方帳號串接 | LINE @ 串接、InstantID、Webhook |
| [08-STEP-BY-STEP-GUIDE.md](08-STEP-BY-STEP-GUIDE.md) | 一步一步操作（Web ＋ Make + LINE ＋ API） | 從本機測試到端對端 |
| [09-PRODUCT-SERVICE-STEPS.md](09-PRODUCT-SERVICE-STEPS.md) | 產品服務步驟定義（年齡變化→Prompt→職業照） | 功能驗收、API 規格、本機測試、流程對齊 |
| [10-DEPLOY-FOR-VOLUNTEERS.md](10-DEPLOY-FOR-VOLUNTEERS.md) | 發布給志工使用（GCP Cloud Run） | 部署、環境變數、志工網址 |
| [11-COST-ESTIMATE.md](11-COST-ESTIMATE.md) | 每張夢想職人照成本估算（Gemini + Cloud Run） | 預算、用量評估 |

---

**維護約定**

* 重大目標或階段完成時，請更新對應文件與「目前進度」。
* 引用時請使用相對路徑，例如：`見 docs/02-ROADMAP.md 第 1 階段`。
* 新增治理文件時，請在此索引補上一列。
