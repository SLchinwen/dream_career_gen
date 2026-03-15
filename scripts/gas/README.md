# 共用雲端相簿 — GAS 腳本

本目錄為 **Google Apps Script (GAS)** 範本，用於讀取共用雲端硬碟的資料夾與相片，回傳 JSON 給網站顯示相簿。

## 使用步驟

1. **複製腳本**  
   將 `SharedDriveAlbum.gs` 內容複製到 [Google 指令碼編輯器](https://script.google.com/) 新專案。

2. **啟用 Drive API**  
   編輯器 → **擴充功能** → **Google 服務** → 啟用 **Drive API**（進階服務）。

3. **設定根資料夾 ID**  
   - 在共用雲端硬碟中，右鍵點擊要當作「相簿根目錄」的資料夾 → **取得連結**。  
   - 連結格式如：`https://drive.google.com/drive/folders/XXXXXXXXXXXX`，其中 `XXXXXXXXXXXX` 即 **Folder ID**。  
   - **若為「共用雲端硬碟」本身（根目錄）**：可貼上該共用硬碟的 ID，腳本會自動用 Drive API 列出一層子資料夾。  
   - **建議**：若根目錄無效，請在硬碟內新增一個資料夾（例如「網站相簿」），把年度資料夾放在其下，再以該資料夾的 ID 設為 `ROOT_FOLDER_ID`。  
   - 在指令碼編輯器 → **專案設定**（齒輪）→ **指令碼屬性** → 新增屬性：  
     - 屬性：`ROOT_FOLDER_ID`  
     - 值：貼上上述 Folder ID（或共用硬碟 ID）  

4. **部署為網頁應用程式**  
   - **部署** → **新增部署** → 類型選 **網頁應用程式**。  
   - **執行身份**：我。  
   - **具有存取權的使用者**：**任何人**。  
   - 部署後複製 **網頁應用程式 URL**（例如 `https://script.google.com/macros/s/xxxxx/exec`）。

5. **在網站設定 URL**  
   將上述 URL 設為網站環境變數 **`GAS_ALBUM_WEB_APP_URL`**（本機 `.env` 或 Cloud Run 變數與密碼）。

## API 參數（給網站呼叫）

- **根目錄相簿列表**（例：年度）：`GET {URL}?action=folders`  
  回傳：`{ "folders": [ { "id", "name", "photo_count" } ] }`

- **指定資料夾下的子資料夾**（例：年度下的活動相簿）：`GET {URL}?action=folders&folder_id=資料夾ID`  
  回傳：`{ "folder_name", "folders": [ { "id", "name", "photo_count" } ] }`

- **單一相簿相片**：`GET {URL}?action=photos&folder_id=資料夾ID`  
  回傳：`{ "folder_name", "photos": [ { "id", "name", "thumbnail_link", "web_content_link" } ] }`

## 與「getFolderList / getPhotosInFolder」寫法的對應

腳本已採用相同邏輯：用 **DriveApp** 列資料夾與檔案，相片用 **URL** 給網頁顯示。

- **getFolderList()**：回傳根目錄下資料夾清單 `[{ id, name }]`（依名稱排序）。ID 來自指令碼屬性 `ROOT_FOLDER_ID`，不必改程式。
- **getPhotosInFolder(folderId)**：回傳該資料夾內相片 `[{ name, thumb, url }]`。縮圖／大圖使用 `https://drive.google.com/thumbnail?id=...`、`https://drive.google.com/uc?export=view&id=...`，因 `file.getThumbnail()` 在 GAS 回傳的是 Blob，無法直接當 `<img src>`。
- 相片類型支援 **JPEG / PNG / GIF / WebP 等**（不只 JPEG）。若資料夾在**共用硬碟**，會自動改用 Drive API 列檔，否則常列不到。

若要用**固定 FOLDER_ID**（不改指令碼屬性），可在程式開頭加一行：`const FOLDER_ID = '您的資料夾ID';` 並讓 getFolderList 讀 FOLDER_ID（需自行改一行）。

---

## 權限與分享

- 相片能否被網站訪客看到，取決於該資料夾在 Google 雲端硬碟的**分享設定**。  
- 若要對外展示，請將相簿根目錄（或個別相簿資料夾）設為 **「知道連結的使用者皆可查看」**。

詳細說明見專案文件：`docs/26-共用雲端相簿服務.md`。

---

## 如何驗證 GAS 取得的資料是否正確

### 方式一：在瀏覽器直接打 GAS 網址（看原始 JSON）

部署完成後，用瀏覽器開下列網址（把 `你的GAS網址` 換成實際的 exec URL）：

| 想驗證的項目 | 網址 | 預期看到 |
|-------------|------|----------|
| 根目錄第一層子資料夾（應為年度） | `https://你的GAS網址/exec?action=folders` | JSON 裡有 `folders` 陣列，每筆有 `id`、`name`、`photo_count`。名稱應為 2025-26、2026-27、2027-28 等。 |
| 某年度下的活動相簿 | `https://你的GAS網址/exec?action=folders&folder_id=這裡填2025-26的資料夾ID` | JSON 裡有 `folder_name`（例：2025-26）與 `folders` 陣列（活動相簿名稱）。 |
| 某相簿內的相片 | `https://你的GAS網址/exec?action=photos&folder_id=這裡填活動相簿的資料夾ID` | JSON 裡有 `folder_name` 與 `photos` 陣列（每筆有 `thumbnail_link`、`web_content_link`）。 |

**取得資料夾 ID**：在 Google 雲端硬碟對該資料夾按右鍵 → 取得連結 → 網址中 `folders/` 後面那串即 ID。

若 `?action=folders` 回傳的 `folders` 名稱或數量不對，代表 **ROOT_FOLDER_ID** 指到的不是「包含 2025-26、2026-27、2027-28 的那一層」，請到指令碼屬性改為正確的資料夾 ID。

### 方式二：在 GAS 編輯器執行測試函式

1. 開啟 [script.google.com](https://script.google.com) → 你的「共用雲端硬碟相簿」專案。
2. 在程式碼中找到函式 **`testRootAndFolders`**（或從上方函式選單選擇）。
3. 點選該函式後按 **執行**（▶）。
4. 第一次執行會要求授權，依畫面完成授權。
5. 執行完成後：上方選單 **檢視** → **執行紀錄**（或 **紀錄**），即可看到：
   - 目前設定的 `ROOT_FOLDER_ID` 值
   - `listFolders()` 回傳的完整 JSON
   - 第一層資料夾的名稱與 ID 列表

據此可確認 GAS 讀到的根目錄 ID 與第一層資料夾是否正確。
