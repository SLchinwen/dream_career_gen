---
name: scaffold-new-project
description: 當使用者要開新專案並複製本專案的文件治理模式（.cursor/rules、.cursor/skills、docs 結構）時使用。觸發語包含：開新專案、複製治理、scaffold 新專案、建立新專案並套用治理、不需要手動開目錄與複製。
---

# 新專案治理 Scaffold

當使用者表示要**開新專案**並希望**文件治理模式與本專案相同**、且**不需手動開目錄與複製**時，依下列方式協助。

## 1. 取得目標路徑與專案名稱

- 若使用者已提供目標根目錄（例如 `C:\github\my_new_project`），直接使用。
- 若未提供，請詢問：「請提供新專案的根目錄路徑（例如 C:\github\新專案名稱）。」
- 專案顯示名稱為可選；未提供時腳本會使用「新專案」。

## 2. 執行 scaffold 腳本（優先）

在本專案根目錄執行（專案內需有 `script/scaffold-governance.rb`，可由 scaffold 一併複製）：

```powershell
ruby script/scaffold-governance.rb <目標根目錄> [專案顯示名稱]
```

範例：

```powershell
ruby script/scaffold-governance.rb C:\github\my_new_project "我的新專案"
```

若執行成功，提醒使用者：在 Cursor 中開啟目標目錄即可使用相同治理模式；若新專案非 Windows/Rails，可刪除或修改 `.cursor/rules/windows-env.mdc`。

## 3. 若無法執行腳本（例如目標在遠端或權限限制）

改為依 `script/scaffold-governance.rb` 的邏輯，在目標路徑下手動建立：

- 目錄：`.cursor/rules`、`.cursor/skills/requirements-elicitation`、`docs`
- 複製本專案：`.cursor/rules/*.mdc`、`.cursor/skills/requirements-elicitation/SKILL.md`、`.cursor/RULES-AND-SKILLS-建議.md`
- 寫入 docs 範本：`docs/README.md`、`01-VISION-AND-GOALS.md`～`04-NEXT-ACTIONS.md`（內容可參考腳本內嵌範本，專案名稱以使用者提供或「新專案」代入）

## 4. 引用文件

詳細說明見本專案 `docs/14-SCAFFOLD-NEW-PROJECT.md`。
