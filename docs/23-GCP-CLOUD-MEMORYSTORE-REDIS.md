# GCP Cloud Memorystore（Redis）申請與設定指引

本專案 RID3510 聊天服務使用 **Redis** 儲存 10 輪對話（`conversation_id` → 歷史訊息）。Redis 以 **GCP Cloud Memorystore for Redis** 部署在雲端，本機測試可省略。以下引導您申請與設定。

---

## 一、前置條件

- 已有 **Google Cloud 專案**（與現有 Cloud Run / dream_career_gen 同一專案即可）。
- 已安裝 [gcloud CLI](https://cloud.google.com/sdk/docs/install) 並完成 `gcloud init` 與登入。

---

## 二、啟用 API

在 GCP 專案中啟用 **Memorystore for Redis API**：

```bash
gcloud services enable redis.googleapis.com
```

若使用 **Private Service Access**（建議），一併啟用：

```bash
gcloud services enable servicenetworking.googleapis.com
```

---

## 三、建立 Redis 實例

### 方式 A：主控台（建議第一次使用）

1. 開啟 [Memorystore for Redis](https://console.cloud.google.com/memorystore/redis/instances)。
2. 點擊 **建立執行個體**（Create Instance）。
3. 設定：
   - **執行個體 ID**：例如 `rid3510-chat`（小寫、數字、連字號，且以字母開頭）。
   - **層級**：**基本**（Basic）即可，成本較低；若要高可用選 **標準**（Standard）。
   - **地區**：與您的 **Cloud Run 服務同一地區**（例如 `asia-east1`），以降低延遲。
   - **容量**：例如 **1 GB** 即足夠 10 輪對話與多個 conversation。
   - **授權的 VPC 網路**：選取 Cloud Run 可存取的 VPC（見下方「Cloud Run 連線」）。
4. 若畫面出現 **需要私用服務連線**：依畫面引導建立 **Private Service Access**（預留 IP 區段、建立連線）。
5. 進階選項（可選）：
   - **Redis AUTH**：若啟用，需記下 AUTH 字串，連線時使用 `redis://:AUTH字串@IP:6379`。
   - **傳輸中加密**：視需求啟用。
6. 點擊 **建立**，等待實例就緒。

建立完成後，在實例詳情頁記下 **主機 IP**（例如 `10.x.x.x`），連接埠為 **6379**。

### 方式 B：gcloud 指令

```bash
# 替換為您的專案、地區與 VPC 網路名稱
gcloud redis instances create rid3510-chat \
  --size=1 \
  --region=asia-east1 \
  --network=default
```

若需 **Private Service Access**，請先依 [建立私用服務連線](https://cloud.google.com/memorystore/docs/redis/establishing-connection) 完成連線，再於上述指令加上 `--connect-mode=PRIVATE_SERVICE_ACCESS` 等參數。

取得實例 IP：

```bash
gcloud redis instances describe rid3510-chat --region=asia-east1 --format="value(host)"
```

---

## 四、REDIS_URL 格式

應用程式使用環境變數 **`REDIS_URL`** 連線：

| 情境 | REDIS_URL 格式 |
|------|-----------------|
| 無 AUTH、預設埠 6379 | `redis://主機IP:6379/0` |
| 有 AUTH | `redis://:您的AUTH字串@主機IP:6379/0` |

範例（無 AUTH）：

```text
REDIS_URL=redis://10.123.45.67:6379/0
```

範例（有 AUTH，密碼打碼）：

```text
REDIS_URL=redis://:xxxxxxxx@10.123.45.67:6379/0
```

結尾 `/0` 為 Redis 資料庫編號（0–15），預設用 `0` 即可。

---

## 五、Cloud Run 連線到 Memorystore

Memorystore 使用 **私有 IP**，Cloud Run 必須能連到同一個 VPC。做法：**Direct VPC egress**。

### 5.1 確認 Redis 的授權網路

```bash
gcloud redis instances describe rid3510-chat --region=asia-east1 --format="value(authorizedNetwork)"
```

記下輸出的網路名稱（例如 `default` 或 `projects/專案ID/global/networks/default`）。

### 5.2 Cloud Run 部署時指定 VPC 與子網路

部署 Cloud Run 時需加上：

- `--network=授權網路名稱`
- `--subnet=子網路名稱`（該子網路需與 Redis 同區域，且為 `/26` 或更大）

若您目前使用 **Cloud Build + 現有 deploy 流程**，需在 deploy 設定中加上 VPC / subnet，例如：

```bash
gcloud run deploy SERVICE_NAME \
  --image=... \
  --region=asia-east1 \
  --network=default \
  --subnet=default \
  --set-env-vars="REDIS_URL=redis://10.x.x.x:6379/0,GEMINI_API_KEY=..."
```

實際 `REDIS_URL` 請改為您的 Redis 主機 IP；若啟用 AUTH，使用 `redis://:AUTH@IP:6379/0`。

### 5.3 若尚未設定 VPC 連線

若專案從未設定 **Private Service Access** 或 **VPC connector**：

1. 在 GCP 主控台 **VPC 網路** → **私用服務連線** 中，依指引建立連線（預留 IP 區段、建立連線）。
2. 建立 Redis 時選擇該網路為 **授權的 VPC 網路**。
3. Cloud Run 部署時使用該網路與對應子網路（同上節）。

詳細步驟見：[建立私用服務連線](https://cloud.google.com/memorystore/docs/redis/establishing-connection)、[Cloud Run 使用 Direct VPC](https://cloud.google.com/run/docs/configuring/vpc-direct-vpc)。

---

## 六、在專案中設定 REDIS_URL

- **Cloud Run**：在服務的 **「修訂版本」→「變數與密碼」** 新增 `REDIS_URL`，值為上述格式。若用 Secret Manager，可將 `REDIS_URL` 指向 secret。
- **本機**：原則上本專案「直接上雲、本機測試可忽略」；若日後本機要測 Redis，可透過 [埠轉發](https://cloud.google.com/memorystore/docs/redis/connect-redis-instance#connect-from-a-local-machine-by-using-port-forwarding) 連到 Memorystore，或本機起一個 Redis 並設 `REDIS_URL=redis://localhost:6379/0`。

---

## 七、檢查清單

- [ ] 已啟用 `redis.googleapis.com`（與必要時 `servicenetworking.googleapis.com`）。
- [ ] 已建立 Memorystore Redis 實例，並記下主機 IP（與 AUTH 若有）。
- [ ] 已設定 `REDIS_URL=redis://IP:6379/0` 或 `redis://:AUTH@IP:6379/0`。
- [ ] Cloud Run 部署時已設定 `--network`、`--subnet` 與 `REDIS_URL`，且 Redis 與 Cloud Run 在同一 VPC/區域。
- [ ] 應用程式已加入 `redis` gem 並在 `REDIS_URL` 存在時使用 Redis 儲存對話；未設定時可優雅降級（僅多輪邏輯、不持久化或使用記憶體）。

---

## 八、參考

- [Memorystore for Redis 建立與管理](https://cloud.google.com/memorystore/docs/redis/create-manage-instances)
- [連線到 Redis 實例](https://cloud.google.com/memorystore/docs/redis/connect-redis-instance)
- [從 Cloud Run 連線到 Redis](https://cloud.google.com/memorystore/docs/redis/connect-redis-instance-cloud-run)
- [Cloud Run Direct VPC egress](https://cloud.google.com/run/docs/configuring/vpc-direct-vpc)
