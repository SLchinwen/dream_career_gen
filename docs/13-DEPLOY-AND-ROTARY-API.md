# 雲端部署與 People of Action 評分 API 串接

本文件說明：一、如何將本專案部署到 GCP Cloud Run；二、工程師如何串接評分 API 並以排程逐筆評分。

---

## 一、部署到雲端（GCP Cloud Run）

### 1.1 前置條件

- 本專案已與 GitHub 同步（`git push origin main`）。
- GCP 專案已啟用 **Cloud Build**、**Artifact Registry**、**Cloud Run**。
- 已有 `cloudbuild.yaml`（根目錄），建置時會 build Docker 並 deploy 到 Cloud Run。

### 1.2 部署步驟

| 步驟 | 說明 |
|------|------|
| 1. 推送程式碼 | 本機執行 `git push origin main`，確保 GitHub 上有最新程式碼。 |
| 2. 觸發建置 | 在 GCP Console → **Cloud Build → 歷史紀錄**，對連動的 repo 觸發「提交建置」，或由 push 自動觸發（若已設 Cloud Build 觸發條件）。 |
| 3. 等待完成 | 建置會：build 映像 → push 到 Artifact Registry → deploy 到 Cloud Run 服務 `dream-career-service`（region: asia-east1）。 |
| 4. 設定環境變數 | 見下方「環境變數」。 |

### 1.3 環境變數（Cloud Run）

在 **Cloud Run → 選取服務 dream-career-service → 編輯與部署新修訂版本 → 變數與密碼** 中設定：

| 變數 | 必填 | 說明 |
|------|------|------|
| `RAILS_ENV` | 建議 | `production` |
| `RAILS_MASTER_KEY` | 若用 credentials | 從本機 `config/master.key` 複製（勿提交 Git） |
| `GEMINI_API_KEY` | 必填（評分需 AI） | Google AI Studio / Gemini API 金鑰，評分與夢想職人功能皆會用到 |
| `ROTARY_API_KEY` | 必填（排程呼叫評分 API） | 自訂長隨機字串，供排程系統在呼叫評分 API 時帶入；未設定時評分 API 回 503 |

**ROTARY_API_KEY 建議**：可用 `openssl rand -hex 32` 或密碼產生器產生一組，僅提供給負責排程的工程師，勿寫入程式碼或公開。

### 1.4 部署後網址

- 服務 URL 格式：`https://dream-career-service-<PROJECT_NUMBER>.asia-east1.run.app`
- 實際網址請至 GCP Console → Cloud Run → dream-career-service → 上方「服務網址」複製。
- 健康檢查：`GET https://<服務網址>/up` 應回 200。

### 1.5 若出現 Blocked hosts

若 production 有設定 `config.hosts` 白名單，請在 `config/environments/production.rb` 中允許 Cloud Run 的網域（或 `*`），推送後重新建置並部署。詳見 `SYNC_AND_ENV.md`。

---

## 二、評分 API 串接辦法（供排程使用）

### 2.1 基本資訊

| 項目 | 說明 |
|------|------|
| **Base URL** | 部署後的 Cloud Run 服務網址，例如 `https://dream-career-service-xxxxx.asia-east1.run.app` |
| **Endpoint** | `POST /api/rotary/photo_scores` |
| **Content-Type** | `multipart/form-data`（上傳檔案）或 `application/x-www-form-urlencoded`（若只送 image_url + description） |
| **認證** | Header 帶入 API Key（見下） |

### 2.2 認證方式

以下二擇一，與主辦／維運約定的 **ROTARY_API_KEY** 相同。

- **Authorization Bearer**  
  `Authorization: Bearer <ROTARY_API_KEY>`
- **X-API-Key**  
  `X-API-Key: <ROTARY_API_KEY>`

未帶或錯誤時回傳 **401 Unauthorized**。

### 2.3 請求參數

| 參數 | 類型 | 必填 | 說明 |
|------|------|------|------|
| `photo` | 檔案 | 與 image_url 二擇一 | 投稿相片檔（image/jpeg, image/png, image/gif, image/webp） |
| `image_url` | 字串 | 與 photo 二擇一 | 相片直連網址（http 或 https），須可公開讀取 |
| `description` | 字串 | 必填 | 服務說明，約 100 字 |
| `submission_id` | 字串 | 選填 | 投稿編號／主鍵，供排程對應寫回該筆評分結果 |

**注意**：排程若以「檔案」送評，請用 `photo`；若以「已存的圖片 URL」送評，請用 `image_url`。FB／IG 等連結常無法直連，建議排程端盡量以 `photo` 上傳已下載的圖檔。

### 2.4 回應格式（JSON）

**成功（200）**

```json
{
  "score": 22,
  "score_max": 30,
  "summary": "符合 People、Action、Impact 三元素；社友實際行動與服務對象互動清楚。",
  "consistency": "一致",
  "composition_tip": "取景與構圖的具體改善建議（若有）",
  "description_tip": "說明文字如何撰寫的具體建議（若有）",
  "submission_id": "您傳入的 submission_id（若有）"
}
```

**錯誤**

| HTTP 狀態 | 說明 |
|-----------|------|
| 401 | 未帶 API Key 或 Key 錯誤 |
| 422 | 參數錯誤（缺 photo/image_url/description、image_url 格式錯誤等），body 為 `{"error":"訊息"}` |
| 503 | 伺服器未設定 ROTARY_API_KEY 或 GEMINI_API_KEY |

### 2.5 排程建議

- **逐筆呼叫**：依投稿清單一筆一筆 POST，每筆獨立、可重試。
- **帶 submission_id**：方便將回傳的 `score`、`summary`、`consistency`、`composition_tip`、`description_tip` 寫回該筆投稿。
- **逾時**：單次評分約 30–120 秒，排程請求請設定 read timeout ≥ 120 秒。
- **重試**：遇 5xx 或網路錯誤可重試 1–2 次；422 為參數問題，不需重試同一筆。

---

## 三、範例：curl

```bash
# 使用上傳檔案（photo）
curl -X POST "https://<服務網址>/api/rotary/photo_scores" \
  -H "Authorization: Bearer YOUR_ROTARY_API_KEY" \
  -F "photo=@/path/to/image.jpg" \
  -F "description=我們透過扶輪完成了災後毀損房屋修繕，改善了居民的居住品質與保障。" \
  -F "submission_id=sub_001"

# 使用圖片網址（image_url）
curl -X POST "https://<服務網址>/api/rotary/photo_scores" \
  -H "X-API-Key: YOUR_ROTARY_API_KEY" \
  -F "image_url=https://example.com/photo.jpg" \
  -F "description=我們透過扶輪完成了災後毀損房屋修繕，改善了居民的居住品質與保障。" \
  -F "submission_id=sub_002"
```

---

## 四、範例：Python（排程腳本）

```python
import requests

BASE_URL = "https://dream-career-service-xxxxx.asia-east1.run.app"  # 換成實際服務網址
ROTARY_API_KEY = "your_rotary_api_key"

def score_submission(submission_id: str, image_path: str, description: str) -> dict:
    url = f"{BASE_URL}/api/rotary/photo_scores"
    headers = {"Authorization": f"Bearer {ROTARY_API_KEY}"}
    files = {"photo": open(image_path, "rb")}
    data = {"description": description, "submission_id": submission_id}
    r = requests.post(url, headers=headers, files=files, data=data, timeout=120)
    r.raise_for_status()
    return r.json()

# 逐筆評分
for row in submissions:
    result = score_submission(
        submission_id=row["id"],
        image_path=row["image_path"],
        description=row["description"],
    )
    # 將 result["score"], result["summary"], result["consistency"] 等寫回資料庫
    print(f"{row['id']}: score={result['score']}/{result['score_max']}")
```

若使用 **image_url** 而非上傳檔案：

```python
data = {
    "image_url": row["image_url"],
    "description": row["description"],
    "submission_id": row["id"],
}
r = requests.post(url, headers=headers, data=data, timeout=120)
```

---

## 五、快速檢查清單

| 項目 | 確認 |
|------|------|
| 程式碼已 push 至 GitHub | |
| Cloud Build 建置成功並部署至 Cloud Run | |
| Cloud Run 已設定 GEMINI_API_KEY、ROTARY_API_KEY（及必要時 RAILS_MASTER_KEY） | |
| 工程師已取得服務網址與 ROTARY_API_KEY | |
| 排程可逐筆 POST /api/rotary/photo_scores，並依 submission_id 寫回評分結果 | |

若需調整自評滿分（0–30 與 SOP 0–40 對應）或多組 API Key，可再參考 `docs/12-PEOPLE-OF-ACTION-API-REQUIREMENTS.md` 與主辦單位討論。
