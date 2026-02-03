# 14. 新專案治理 Scaffold（複製文件治理模式）

> 維護時可引用：**開新專案時如何一鍵建立相同治理結構，無需手動開目錄與複製**。

---

## 目的

開新專案時，希望 **文件治理模式**（`.cursor/rules`、`.cursor/skills`、`docs/` 結構與約定）與本專案一致，且 **不需手動建立目錄或複製檔案**。

---

## 方式一：執行腳本（推薦）

在本專案根目錄執行：

```powershell
ruby script/scaffold-governance.rb <目標根目錄> [專案顯示名稱]
```

**範例：**

```powershell
# 在 C:\github\my_new_project 建立治理結構，專案名稱為「我的新專案」
ruby script/scaffold-governance.rb C:\github\my_new_project "我的新專案"

# 只給目標目錄，專案名稱會預設為「新專案」
ruby script/scaffold-governance.rb C:\github\another_project
```

**腳本會自動：**

| 動作 | 說明 |
|------|------|
| 建立目錄 | `.cursor/rules`、`.cursor/skills/requirements-elicitation`、`docs/` |
| 複製 Rules | `docs-structure.mdc`、`requirements-and-docs.mdc`、`windows-env.mdc` |
| 複製 Skill | `requirements-elicitation/SKILL.md` |
| 複製說明 | `.cursor/RULES-AND-SKILLS-建議.md` |
| 寫入 docs 範本 | `docs/README.md`、`01-VISION-AND-GOALS.md`～`04-NEXT-ACTIONS.md`（通用版，含專案名稱佔位） |

完成後在 Cursor 開啟 **目標根目錄** 即可使用相同治理模式。

---

## 方式二：請 AI 代為建立

若希望由 AI 代勞（不自己執行腳本），可說：

- 「在 `C:\github\新專案目錄` 開新專案，套用跟現在一樣的治理模式」
- 「幫我用 scaffold 在 `D:\projects\xxx` 建立新專案治理」

AI 會依本文件與 `script/scaffold-governance.rb` 的邏輯，在指定路徑建立目錄並寫入/複製治理檔案；或代為執行上述腳本（若環境允許）。

---

## 複製後的調整建議

| 項目 | 建議 |
|------|------|
| **windows-env.mdc** | 若新專案非 Windows 或非 Rails，可刪除或改寫內容。 |
| **docs 編號** | 新增文件時沿用 `05-`、`06-`… 並在 `docs/README.md` 補上一列。 |
| **專案名稱** | 在 `docs/01-VISION-AND-GOALS.md` 等處替換佔位為實際專案名稱。 |

---

## 維護約定

* 若本專案新增 Rule、Skill 或 docs 範本，請同步更新 `script/scaffold-governance.rb`，使新專案 scaffold 一併包含。
* 引用時請用相對路徑，例如：`見 docs/14-SCAFFOLD-NEW-PROJECT.md`。
