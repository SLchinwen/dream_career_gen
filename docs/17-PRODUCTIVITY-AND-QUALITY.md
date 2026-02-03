# 17. 生產力與品質：注意事項與建議設定

> 維護時可引用：**提交前檢查、本地品質把關、與需求對齊、可選設定**。

---

## 一、已就緒的設定（可直接沿用）

| 項目 | 說明 | 引用 |
|------|------|------|
| **專案標準與引導** | 專案開始時由 AI 引導補足 00～10 文件 | [16-PROJECT-STANDARD.md](16-PROJECT-STANDARD.md) |
| **AI 開發對齊** | 實作時對齊 03、05、06、08、10，需求追溯與驗收對照 | [15-AI-DEV-STANDARDS.md](15-AI-DEV-STANDARDS.md) |
| **CI 流水線** | 每次 push/PR 跑：Brakeman、bundler-audit、importmap audit、Rubocop、單元測試、系統測試 | `.github/workflows/ci.yml` |
| **Git 治理** | 禁止提交 .env、master.key；commit 前自檢 | [06-GIT-GOVERNANCE.md](06-GIT-GOVERNANCE.md) |
| **Lint 風格** | Rubocop（Rails Omakase） | `.rubocop.yml` |
| **Windows 指令** | 本專案需以 `ruby bin/...` 執行腳本 | `.cursor/rules/windows-env.mdc` |

---

## 二、需要注意的事項

### 1. 提交前自檢（避免品質與安全問題）

| 檢查項 | 說明 |
|--------|------|
| **不要提交金鑰** | 待提交清單中不得出現 `.env`、`config/master.key`；見 [06-GIT-GOVERNANCE.md](06-GIT-GOVERNANCE.md)。 |
| **建議本地先跑測試** | 改動程式後，提交前可先跑測試與 lint，減少 CI 失敗與來回修改。 |
| **建議本地跑 Lint** | 執行 `ruby bin/rubocop`（Windows）或 `bin/rubocop`，修正風格後再提交。 |

### 2. 測試與需求對齊（提升品質）

| 建議 | 說明 |
|------|------|
| **對應驗收條件** | 撰寫或補測試時，對齊 03 功能需求或 06 使用者故事的**驗收條件**，便於回歸與交付確認。 |
| **需求編號可寫進測試** | 測試檔或 describe/context 可註明對應需求（如 `# F01`），方便追溯。 |
| **CI 失敗要修** | CI 的 test / rubocop 失敗時，優先修完再合併，避免主線長期紅燈。 |

### 3. 文件與程式同步（迭代時）

| 建議 | 說明 |
|------|------|
| **需求或範圍變更** | 修改 01、03、06 等時，依依賴關係同步更新 05、08、09、10；見 [15-AI-DEV-STANDARDS.md](15-AI-DEV-STANDARDS.md)「變更時」。 |
| **技術或介面變更** | 技術棧、API、部署方式變更時，更新 08 技術備忘或對應 doc，方便交接與 AI 對齊。 |
| **待補標註** | 未定稿處一律標「待補」，避免被誤解為已定案。 |

### 4. 與 AI 協作時的習慣（提升生產力）

| 建議 | 說明 |
|------|------|
| **下達開發指令時帶需求** | 例如：「實作 03 的 F01，對齊 08 技術備忘」；AI 會依 Rule 對齊並可追溯。 |
| **完成後可要求對照** | 例如：「幫我對照 06 驗收條件檢查」或「更新 10 檢查清單」。 |
| **專案開始用標準流程** | 說「專案開始」或「依專案標準補足文件」，由 AI 引導補足 00～10。 |

---

## 三、建議設定（可選，進一步提升）

### 1. Pre-commit Hook（阻擋 .env 誤提交）

見 [06-GIT-GOVERNANCE.md](06-GIT-GOVERNANCE.md)「可選：Pre-commit 提醒」：在 `.git/hooks/pre-commit` 加入檢查，若 staged 含 `.env` 則 commit 失敗並提示。每位開發者本機設定一次即可。

### 2. 本地常用指令（Windows）

提交前可手動執行（依專案規則使用 `ruby bin/...`）：

| 目的 | 指令 |
|------|------|
| 跑測試 | `ruby bin/rails test` |
| 跑系統測試 | `ruby bin/rails test:system` |
| Lint | `ruby bin/rubocop`（可加 `-a` 自動修正部分違規） |
| 安全掃描 | `ruby bin/brakeman --no-pager`、`ruby bin/bundler-audit` |

可將「跑測試 + lint」養成提交前習慣，或寫進個人 checklist。

### 3. Definition of Done（完成標準，可自訂）

可依團隊習慣在 10 交付檢查清單或本文件註明「一項任務視為完成」的條件，例如：

- 對應 03/06 的驗收條件已滿足（或已註明限制）。
- 相關測試已通過（或已補測試／標註待補）。
- Rubocop 通過（或已同意例外並記錄）。
- 若影響介面或流程，07／08 已更新或標註待補。
- 未提交 .env、master.key。

### 4. Commit 訊息慣例（可選）

便於追溯與搜尋，可採用簡短前綴或需求編號，例如：

- `feat: 實作 OOO（對應 03-F01）`
- `fix: 修正 OOO`
- `docs: 更新 08 技術備忘`

AI 建議 commit 訊息時可一併標註對應需求編號（若適用）。

### 5. Cursor／編輯器可選設定

| 項目 | 說明 |
|------|------|
| **儲存時格式化** | 若希望儲存時自動跑 formatter（需專案有設定），可於 Cursor 設定啟用 Format On Save。 |
| **開啟專案即見總覽** | 可將 `docs/README.md` 或 `docs/16-PROJECT-STANDARD.md` 加入常用檔案，方便查閱。 |
| **.cursor/rules** | 已設定 project-standard、ai-dev-alignment、requirements-and-docs 等，無須額外設定檔。 |

---

## 四、小結：檢查清單（提交前可快速掃過）

- [ ] 待提交清單中**沒有** .env、config/master.key
- [ ] 有改程式時，本地已跑過 **測試**（`ruby bin/rails test`）與 **Lint**（`ruby bin/rubocop`）且通過（或已知例外）
- [ ] 需求或範圍有變更時，已**同步更新**對應文件（01、03、05、06、08、09、10 等）
- [ ] 與 AI 協作時，有需要會**標註對應需求**（如 03-F01）或請 AI 對照驗收條件

---

**維護約定**：若新增檢查項、CI 步驟或團隊約定，請更新本文件。引用時請用相對路徑，例如：`見 docs/17-PRODUCTIVITY-AND-QUALITY.md`。
