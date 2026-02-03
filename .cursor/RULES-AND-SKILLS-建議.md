# Rules 與 Skills 設定建議（主管／需求與文件產出）

您的主要工作：**與使用者互動釐清需求 → 製作文件歸檔 → 提供給工程師開發**。以下建議如何用 **Rules** 與 **Skills** 讓 AI 互動更完善。

---

## 一、Rules 與 Skills 的差異與分工

| 項目 | Rules（.cursor/rules/*.mdc） | Skills（.cursor/skills/ 或 ~/.cursor/skills/） |
|------|------------------------------|------------------------------------------------|
| **用途** | 固定「行為準則」與「產出格式」 | 特定情境下的「流程」與「專業知識」 |
| **觸發** | 依 `alwaysApply` 或開啟的檔案（globs）自動套用 | AI 依描述判斷「何時該用這個技能」 |
| **適合放什麼** | 語言（繁體中文）、文件結構、名詞定義、報價/需求章節 | 訪談提問清單、釐清需求流程、手把手步驟、範本引用 |
| **您目前已有** | `requirements-and-docs.mdc`（需求與軟工文件）、`windows-env.mdc`（環境） | （可新增） |

**簡單記法**：  
- **Rule** = 「在這個專案／這類檔案裡，一律這樣做」。  
- **Skill** = 「當使用者在做 X 時，請用這套流程與知識協助」。

---

## 二、建議新增的 Rules

### 1. 維持並善用現有 Rule

- **requirements-and-docs.mdc**（`alwaysApply: true`）  
  已涵蓋：角色（主管）、產出語言（繁體中文）、需求/報價/軟工文件應包含的章節。  
  **建議**：保持啟用，若日後有固定範本或術語表，可在此 Rule 或另一條 Rule 中補上「名詞定義」一節。

### 2. 新增：文件資料夾專用 Rule（建議）

- **檔名**：`docs-structure.mdc`  
- **globs**：`docs/**/*.md`  
- **用途**：當 AI 在編輯 `docs/` 底下的檔案時，遵守專案既有習慣（例如編號 01-、02-、README 總覽、待補標註）。  
- **效果**：產出或改寫文件時會自動對齊您現有的 `01-VISION-AND-GOALS.md`、`02-ROADMAP.md` 等結構，減少格式不一致。

### 3. 可選：報價／估價專用 Rule

- 若您經常在**同一份文件或固定路徑**產出報價單，可新增一條 `globs: **/報價*.md` 或 `**/estimate*.md` 的 Rule，內容寫明：  
  - 章節順序（專案名稱、版本、日期、項目與金額、假設與排除、有效期限等）  
  - 是否要編號、是否要簽核欄位等。  

這樣 AI 在編輯該類檔案時會一致套用。

---

## 三、建議新增的 Skills

### 1. 需求釐清／使用者訪談 Skill（強烈建議）

- **名稱**：例如 `requirements-elicitation`（需求釐清）  
- **存放**：  
  - **專案**：`.cursor/skills/requirements-elicitation/` → 與團隊、專案一起版控，大家共用。  
  - **個人**：`~/.cursor/skills/requirements-elicitation/` → 僅您本機，跨專案通用。  
- **描述要寫清**：  
  - **WHAT**：協助與使用者/客戶訪談、釐清需求、把對話整理成結構化要點。  
  - **WHEN**：當使用者說「要跟客戶開會釐清需求」「幫我列訪談問題」「把這段對話整理成需求」時觸發。  
- **內容建議包含**：  
  - 訪談前：目標、對象、時間、想釐清的主題。  
  - 提問清單：目標與範圍、利害關係人、成功條件、限制與假設、非功能需求（效能、安全、維運）、名詞定義。  
  - 訪談後：如何把筆記轉成「需求文件應包含」的章節（對齊您現有 Rule）。  

專案裡已為您建立一個範例 Skill 結構，見 `.cursor/skills/requirements-elicitation/SKILL.md`。

### 2. 可選：手交工程師檢查清單 Skill

- **名稱**：例如 `handoff-to-engineering`  
- **描述**：交付工程師前檢查清單（README、需求規格、技術備忘、任務/工項、聯絡窗口、待補項目標註）。  
- **觸發**：當使用者說「要交給工程師了」「幫我檢查還缺什麼」「做 handoff 清單」時使用。  

可從您現有「交付工程師的軟工文件建議結構」抽成步驟與檢查項，寫進此 Skill。

### 3. 可選：報價／估價產出 Skill

- 若報價結構固定但**情境多**（不同專案類型、不同分項），可用一個 Skill 描述：  
  - 依專案類型選擇範本、  
  - 分項（需求分析、設計、開發、測試、上線、維護）填寫要點、  
  - 假設與排除、有效期限的撰寫慣例。  

Rule 負責「格式與章節」，Skill 負責「何時用、怎麼選範本、怎麼填」。

---

## 四、實際使用方式（與 AI 互動更完善）

1. **開新需求討論時**  
   - 直接說：「要跟客戶釐清 OOO 需求，幫我列訪談問題」或「幫我依需求釐清流程準備」。  
   - AI 會依 Skill 描述觸發「需求釐清」Skill，給出提問與結構。

2. **撰寫或修改需求/報價文件時**  
   - 在 `docs/` 底下編輯，或開啟相關 .md。  
   - Rules（requirements-and-docs + docs-structure）會自動套用，產出會對齊章節與編號。

3. **交付工程師前**  
   - 說：「幫我檢查交給工程師還缺什麼」或「做 handoff 檢查清單」。  
   - 若有 handoff Skill，會依檢查清單逐項提醒。

4. **術語與語言**  
   - 已由 `requirements-and-docs.mdc` 約定繁體中文與主管角色，無須重複設定；若某專案有固定術語表，可寫進 Rule 或單一「名詞定義」文件並在 Rule 中引用。

---

## 五、小結

- **Rules**：固定「格式、結構、語言、名詞」，讓所有在專案／在 docs 的產出一致。  
- **Skills**：在「釐清需求、訪談、手交、報價」等情境下，提供流程、提問與檢查清單，讓 AI 在對的時機用對的方法協助您。  

建議優先完成：  
1. 新增 **docs 專用 Rule**（`docs-structure.mdc`）；  
2. 新增 **需求釐清 Skill**（`requirements-elicitation`）；  
3. 依實際使用再補「手交檢查」或「報價產出」Skill。  

若您願意，我可以依您現有 `docs/` 結構與用語，把上述 Rule 與 Skill 的具體內容寫成可直接貼上的版本（或已為您建立範例檔，見同目錄下之 Rule 與 `.cursor/skills/requirements-elicitation/`）。

---

## 六、設定檔與 Cursor 設定

### 1. 專案內「不需要」額外的設定檔

- **Project Rules**：只要把 `.mdc` 或 `.md` 放在 **`.cursor/rules/`**，Cursor 會自動掃描，**無需**在專案裡寫 config 註冊。
- **Project Skills**：只要在 **`.cursor/skills/<技能名稱>/SKILL.md`** 放好 SKILL.md，Cursor 會依描述自動判斷何時使用，**無需**在設定檔裡註冊。

也就是說：**放對資料夾就會生效**，專案內不必再建「設定檔」來啟用 Rules 或 Skills。

### 2. Cursor 應用程式設定（Rules／Skills 開關與 User Rules）

在 Cursor 裡用 **設定介面** 調整時：

| 要做的事 | 去哪裡 |
|----------|--------|
| 檢視／啟用／停用 **Project Rules** | **Cursor → Settings → Rules**（或 **Rules, Commands**） |
| 編輯 **User Rules**（跨專案通用） | **Cursor → Settings → Rules** → User Rules 區塊 |
| 開關 **Agent Skills**（是否載入 Skills） | **Cursor → Settings → Rules** → **Import Settings** → **Agent Skills** 切換 |

路徑摘要：
- 選單：**File → Preferences → Cursor Settings**（或 `Ctrl + ,` 開設定後選 Cursor 相關）
- 左側找 **Rules** 或 **Rules, Commands**，即可看到 Project Rules、User Rules、Import Settings（含 Agent Skills）。

### 3. 編輯器設定檔（settings.json）— 與 Rules/Skills 無關

若您問的是「**設定檔**」指 **VS Code／Cursor 的 settings.json**：

- **Windows 使用者設定檔路徑**：  
  `%APPDATA%\Cursor\User\settings.json`  
  （例如：`C:\Users\<您的使用者名>\AppData\Roaming\Cursor\User\settings.json`）
- **專案工作區設定**（可選）：專案根目錄下 **`.vscode/settings.json`**，只影響該專案開啟時的編輯器行為（字型、儲存時格式化等）。

**注意**：Rules 與 Skills 的「啟用／路徑」是由 Cursor 依 `.cursor/rules/` 與 `.cursor/skills/` 自動處理，**不會**在 settings.json 裡設定；settings.json 用來改編輯器本身（主題、字型、快捷鍵等）。

### 4. 總結對照

| 項目 | 如何設定 |
|------|----------|
| Project Rules | 把 .mdc／.md 放到 `.cursor/rules/`，無需設定檔 |
| Project Skills | 把 SKILL.md 放到 `.cursor/skills/<名稱>/`，無需設定檔 |
| User Rules、Agent Skills 開關 | Cursor → Settings → Rules（介面操作） |
| 編輯器字型、主題、儲存行為等 | `settings.json`（使用者或 `.vscode/settings.json`） |
