# 從客戶到交付開發：軟體工程文件總覽

本目錄為**從客戶背景、需求、目的到交付開發**的標準文件集，供主管與客戶釐清需求、產出規格、估價與手交工程師時使用。可依**階段與依賴性**逐一填寫，並支援未來迭代修正。

---

## 文件一覽與階段

| 階段 | 文件 | 說明 | 依賴 |
|------|------|------|------|
| **1. 客戶與專案緣起** | [00-CLIENT-BACKGROUND.md](00-CLIENT-BACKGROUND.md) | 客戶背景、產業、專案緣起 | — |
| | [01-PROJECT-PURPOSE-AND-SCOPE.md](01-PROJECT-PURPOSE-AND-SCOPE.md) | 專案目的、目標、成功條件、範圍邊界 | 00 |
| **2. 利害關係人與決策** | [02-STAKEHOLDERS-AND-DECISION.md](02-STAKEHOLDERS-AND-DECISION.md) | 誰會用、誰付費、誰驗收、決策流程 | 01 |
| **3. 需求** | [03-FUNCTIONAL-REQUIREMENTS.md](03-FUNCTIONAL-REQUIREMENTS.md) | 功能需求（模組／使用者故事、優先級、驗收條件） | 02 |
| | [04-NON-FUNCTIONAL-REQUIREMENTS.md](04-NON-FUNCTIONAL-REQUIREMENTS.md) | 非功能需求（效能、安全、維運、介面） | 02 |
| | [05-GLOSSARY-AND-BOUNDARY.md](05-GLOSSARY-AND-BOUNDARY.md) | 名詞定義、排除範圍 | 03, 04 |
| **4. 情境與設計** | [06-USER-STORIES-AND-SCENARIOS.md](06-USER-STORIES-AND-SCENARIOS.md) | 使用者故事與情境（誰、何時、做什麼、結果） | 03, 04, 05 |
| | [07-WIREFRAME-AND-UI.md](07-WIREFRAME-AND-UI.md) | 介面與流程（可待補） | 06 |
| **5. 技術與估價** | [08-TECHNICAL-MEMO.md](08-TECHNICAL-MEMO.md) | 技術備忘（技術棧、介面、權限、部署） | 03, 04, 06 |
| | [09-ESTIMATE-AND-QUOTE.md](09-ESTIMATE-AND-QUOTE.md) | 估價與報價（項目、假設、排除、期限） | 03～08 |
| **6. 交付開發** | [10-HANDOVER-CHECKLIST.md](10-HANDOVER-CHECKLIST.md) | 交付開發檢查清單、任務對應 | 03～09 |

---

## 依賴關係（建議填寫順序）

```
00 客戶背景
 ↓
01 專案目的與範圍
 ↓
02 利害關係人與決策
 ↓
03 功能需求 ──┬──→ 05 名詞定義與邊界
04 非功能需求 ─┘         ↓
                        06 使用者故事與情境
                         ↓
                        07 介面與流程（可選）
                         ↓
03,04,06 ───────────→ 08 技術備忘
                         ↓
03～08 ─────────────→ 09 估價與報價
                         ↓
03～09 ─────────────→ 10 交付開發檢查清單
```

**建議**：依 00 → 01 → 02 → 03 & 04（可並行）→ 05 → 06 → 07（可選）→ 08 → 09 → 10 順序填寫；未定處標註「待補」，日後迭代補齊。

---

## 如何使用（含 AI 引導）

1. **從頭建立**：說「幫我從客戶背景開始建立軟體工程文件」或「引導我分階段建立從客戶到交付的文件」，AI 會依本總覽引導你提供資料並依序產出各文件。
2. **補足單一文件**：開啟對應 .md，說「幫我補足 03 功能需求」等，AI 會依範本與既有 Rule 協助填寫。
3. **迭代修正**：修改任一文件後，若影響其他文件（例如範圍變更影響 03、09），可說「我改了 01 範圍，請幫我檢查 03、09 要不要同步更新」。

**專案標準**：本文件集為專案標準之一環；**專案開始時由 AI 引導**使用者提供資料並補足本目錄 00～10，見 **docs/16-PROJECT-STANDARD.md**。  
**AI 開發時對齊需求**：補足後，AI 實作時應參照 03、05、06、08、10 及 **docs/15-AI-DEV-STANDARDS.md**；Rule「ai-dev-alignment」於編輯程式碼時自動套用。

---

## 維護約定

* 新增或更名文件時，請在本 README 表格與依賴圖中同步更新。
* 引用時請用相對路徑，例如：`見 docs/from-client-to-dev/03-FUNCTIONAL-REQUIREMENTS.md`。
