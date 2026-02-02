# 6. Git 治理規範

> 維護時可引用：**不得提交的檔案、commit 前檢查、安全約定**。

---

## 不得提交至 Git 的檔案（宣告）

以下檔案**禁止**加入版本控制與同步至 GitHub；專案已用 **`.gitignore`** 排除，Git 不會追蹤它們。

| 檔案／類型 | 說明 |
|------------|------|
| **`.env`** | 本機 API 金鑰（Replicate、Gemini 等），提交會外洩金鑰。 |
| **`.env.local`**、**`.env.*.local`** | 本機專用環境變數，同上。 |
| **`config/master.key`** | Rails credentials 解密金鑰，提交會讓加密失效。 |
| **`/log/*`**、**`/tmp/*`**、**`/storage/*`** | 本機執行產生的暫存與日誌，不需版本控制。 |

**治理規範：** 任何人不得以 `git add .env` 或強制加入方式將上述檔案提交；若 `.gitignore` 已正確設定，這些檔案不會出現在「待 commit」清單中。

---

## Commit 前提醒（建議自檢）

即使有 `.gitignore`，commit 前仍建議快速確認：

1. **Source Control 待提交清單**中**不要出現** `.env`、`config/master.key`。
2. 若出現，**不要勾選**、不要 commit；並確認 `.gitignore` 含有 `.env`（見專案根目錄 `.gitignore` 開頭註解與條目）。

---

## 可選：Pre-commit 提醒（阻擋 .env 被 commit）

若希望 **commit 時自動檢查**，誤加 `.env` 時直接失敗並出現提醒，可設定 Git pre-commit hook：

1. 在專案目錄建立或編輯 **`.git/hooks/pre-commit`**（無副檔名）。
2. 內容如下（可複製貼上），存檔後在該檔上按右鍵 → 內容 → 確認「唯讀」未勾選；若需執行權限，在 Git Bash 執行 `chmod +x .git/hooks/pre-commit`：

```bash
#!/bin/sh
if git diff --cached --name-only | grep -q '^\.env$'; then
  echo "錯誤：禁止提交 .env（含金鑰）。請從 staged 移除：git reset HEAD .env"
  exit 1
fi
exit 0
```

3. 之後若有人執行 `git add .env` 再 commit，會看到上述錯誤訊息且 commit 不會完成。

**注意：** `.git/hooks` 不會被 push 到 GitHub，每位開發者需在本機自行設定一次；治理規範仍以 `.gitignore` 與本文件為主。

---

## 若曾誤 commit 過 .env

若過去曾把 `.env` 或金鑰提交到 Git：

1. 從程式庫中移除追蹤：`git rm --cached .env`，再 commit「移除 .env 追蹤」。
2. 到 GitHub 將該金鑰**撤銷／重新產生**，並在本機 `.env` 換成新金鑰。
3. 確認 `.gitignore` 含 `.env`，之後不會再被追蹤。

---

## 維護約定

* 新增「不得提交」的檔案類型時，請更新本文件與根目錄 **`.gitignore`**。
* 新成員 onboarding 時請引用本文件與 `docs/05-API-KEYS-INJECTION.md`。
