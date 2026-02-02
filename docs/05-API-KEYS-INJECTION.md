# 5. API 金鑰注入方式

> 取得 Replicate 與 Gemini 金鑰後，依下列其中一種方式注入，**勿將金鑰明文提交至 Git**。

---

## 若終端機顯示「ruby 找不到」

目前這個 PowerShell（例如 Cursor 內建終端機）**沒有把 Ruby 放在 PATH**，所以 `ruby`、`bundle`、`bin/rails` 都會失敗。

**你可以這樣做：**

1. **確認是否已安裝 Ruby**  
   從 **開始功能表** 找 **「Ruby 3.x.x-x64」** 或 **「Start Command Prompt with Ruby」**，用**那個**視窗執行專案指令（`cd c:\github\dream_career_gen` 後再設金鑰、跑 `bundle install` 或 `bin/rails server`）。那類捷徑會自動帶好 Ruby 的 PATH。
2. **若還沒安裝 Ruby**  
   到 [RubyInstaller for Windows](https://rubyinstaller.org/downloads/) 下載並安裝（建議選 **Ruby+Devkit 3.2.x**）。安裝時勾選「Add Ruby to PATH」，完成後**關掉並重開 Cursor / 終端機**，再試 `ruby -v`。
3. **若已安裝但 Cursor 終端機仍找不到**  
   關閉 Cursor 後重開，或改用「開始功能表 → Start Command Prompt with Ruby」開終端機，在該視窗裡操作專案。

金鑰注入方式見下方「最簡單」或「.env」作法；**需在「有 Ruby 的終端機」裡執行**。

---

## 最簡單：不用 bundle、不用 .env（先讓金鑰生效）

若終端機裡 **`bundle` 找不到**，或 **`credentials:edit` 沒反應**，可以直接在**同一個**（且**有 Ruby 的**）**PowerShell 視窗**先設環境變數，再啟動 server。金鑰只在這一次視窗有效，關掉視窗就要重設。

在專案目錄執行（**請把下面兩行換成你的實際金鑰**）：

```powershell
cd c:\github\dream_career_gen

$env:REPLICATE_API_TOKEN = "你的_Replicate_API_Token"
$env:GEMINI_API_KEY = "你的_Google_Gemini_API_Key"

bin/rails server
```

或同一行（金鑰請替換）：

```powershell
$env:REPLICATE_API_TOKEN = "你的金鑰"; $env:GEMINI_API_KEY = "你的金鑰"; bin/rails server
```

程式會從 `ENV` 讀取這兩個變數（`config/initializers/api_keys.rb`），不需安裝 dotenv、不需執行 `bundle install`。

---

## 若 `credentials:edit` 都沒反應，且想用 .env 檔（需先能跑 bundle）

在 Windows 上 `bin/rails credentials:edit` 有時不會開啟編輯器；若你**已經能在終端機執行 `bundle install`**，可改用 **.env 檔**。

### 步驟 1：安裝 dotenv

在專案目錄執行（**若 `bundle` 找不到，請改用上面的「最簡單」作法**）：

```powershell
cd c:\github\dream_career_gen
bundle install
```

若系統有 Ruby 但 `bundle` 不在 PATH，可試：從 **開始功能表** 找 **「Start Command Prompt with Ruby」** 或 **「Ruby 3.x.x-x64」** 開啟終端機，再執行 `cd c:\github\dream_career_gen` 與 `bundle install`。

### 步驟 2：建立 .env 並填入金鑰

1. 複製範例檔：把專案根目錄的 **`.env.example`** 複製並重新命名為 **`.env`**。
2. 用記事本或 Cursor 開啟 **`.env`**，把 `你的_Replicate_API_Token`、`你的_Google_Gemini_API_Key` 換成你的實際金鑰，存檔。
3. **勿將 `.env` 提交至 Git**（若專案有 `.gitignore`，請確認裡頭有 `.env`）。

### 步驟 3：啟動專案

之後執行 `bin/rails server` 或 `bin/dev`，程式會自動從 `.env` 讀取金鑰。

---

## 方式一：Rails credentials（本機開發可選）

### 步驟 1：開啟 credentials 編輯

在專案目錄執行（會用預設編輯器開啟加密檔）：

```powershell
cd c:\github\dream_career_gen
bin/rails credentials:edit
```

若 Windows 沒有預設 `EDITOR`，可指定用記事本（**注意：是 `$env:` 不是 `env:`**）：

```powershell
$env:EDITOR = "notepad"
bin/rails credentials:edit
```

或同一行執行：

```powershell
$env:EDITOR = "notepad"; bin/rails credentials:edit
```

### 步驟 2：在 YAML 裡加入金鑰

在開啟的檔案中加上（請替換成你的實際金鑰）：

```yaml
replicate:
  token: 你的_Replicate_API_Token

gemini:
  api_key: 你的_Google_Gemini_API_Key
```

存檔並關閉。Rails 會自動加密寫入 `config/credentials.yml.enc`。

### 步驟 3：確認讀取方式

程式裡已用 `ApiKeys.replicate_token` 與 `ApiKeys.gemini_api_key` 讀取，會自動先看環境變數、沒有再從 credentials 讀。

---

## 方式二：環境變數（建議 GCP Cloud Run 使用）

Production 通常**不要**把 `config/master.key` 放進容器，改在 Cloud Run 設定環境變數即可。

### 本機（PowerShell，僅當前視窗有效）

```powershell
$env:REPLICATE_API_TOKEN = "你的_Replicate_API_Token"
$env:GEMINI_API_KEY = "你的_Google_Gemini_API_Key"
bin/rails server
```

### GCP Cloud Run

1. 開啟 [Google Cloud Console](https://console.cloud.google.com/) → **Cloud Run** → 選服務 `dream-career-service`。
2. 點 **「編輯與部署新修訂」**。
3. 切到 **「變數與密碼」**（或「Variables & Secrets」）。
4. 新增變數：
   - 名稱：`REPLICATE_API_TOKEN`，值：你的 Replicate API Token。
   - 名稱：`GEMINI_API_KEY`，值：你的 Google Gemini API Key。
5. 部署新修訂。

之後程式會透過 `ENV["REPLICATE_API_TOKEN"]` 與 `ENV["GEMINI_API_KEY"]` 讀取（initializer 已用 `ENV.fetch` 優先讀環境變數）。

---

## 變數名稱對照

| 用途       | 環境變數名稱          | credentials 路徑           |
|------------|-----------------------|----------------------------|
| Replicate  | `REPLICATE_API_TOKEN` | `replicate.token`          |
| Gemini     | `GEMINI_API_KEY`      | `gemini.api_key`           |

程式讀取方式：`ApiKeys.replicate_token`、`ApiKeys.gemini_api_key`（見 `config/initializers/api_keys.rb`）。

---

## 注意事項

* **勿**將 `config/master.key` 或含金鑰的 `.env` 提交至 Git。
* **勿**在程式碼或 issue 中貼上金鑰明文。
* 若使用 credentials，請備份 `config/master.key` 到安全處；遺失將無法解密 `credentials.yml.enc`。
