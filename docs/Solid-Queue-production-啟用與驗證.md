# Solid Queue 在 Production 啟用與驗證

> 讓定期任務（例如 RID3510 無法回答補強 `rid3510:process_gaps`）在 production **自動執行**，需先讓 Solid Queue 有在跑；以下說明如何啟用與驗證。

---

## 一、本專案 Production 怎麼跑

- **部署**：GitHub push → Cloud Build → 建置 Docker → 部署到 **Cloud Run**（單一容器）。
- **啟動指令**：`bin/docker-start` → `rails server -b 0.0.0.0`（即 **Puma**）。
- **Solid Queue**：Puma 只有在環境變數 **`SOLID_QUEUE_IN_PUMA=1`** 時才會載入 `plugin :solid_queue`（見 `config/puma.rb`），在同一 process 裡跑 dispatcher + worker，**recurring 排程才會生效**。

因此：**若沒有設定 `SOLID_QUEUE_IN_PUMA=1`，Cloud Run 上的 Puma 不會跑 Solid Queue，定期任務不會自動執行。**

---

## 二、如何啟用（讓 Solid Queue 在 Production 跑）

### 方式 A：Cloud Run 設定環境變數（推薦）

在 **Google Cloud Console** 為該服務加上變數：

1. 開啟 **Cloud Run** → 選服務 **dream-career-service** → **編輯與部署新修訂**。
2. 在 **變數與密碼**（或「環境變數」）新增：
   - **名稱**：`SOLID_QUEUE_IN_PUMA`
   - **數值**：`1`
3. 部署新修訂。

或使用 **gcloud**：

```bash
gcloud run services update dream-career-service \
  --region asia-east1 \
  --set-env-vars SOLID_QUEUE_IN_PUMA=1
```

### 方式 B：Dockerfile / 啟動腳本預設開啟（不建議）

若在 Dockerfile 或 `bin/docker-start` 裡寫死 `ENV SOLID_QUEUE_IN_PUMA=1`，則每次建置都會開啟；較建議用 Cloud Run 環境變數，方便開關與除錯。

---

## 三、如何驗證 Solid Queue 有在跑

### 1. 看啟動日誌（最直觀）

部署後在 **Cloud Run → 紀錄**（Logs）看該修訂的啟動 log：

- **有啟用**：通常會看到 Puma 載入 Solid Queue 相關訊息（例如 supervisor、dispatcher、worker 等，依 Rails/Solid Queue 版本而定）。
- **沒啟用**：只有一般 Puma 啟動，沒有 Solid Queue 相關輸出。

### 2. 查詢資料庫：recurring 任務是否已註冊

Production 使用 SQLite（`storage/production_queue.sqlite3` 為 queue DB）。若可對容器下指令或從本機連到 DB：

```bash
# 若可進入 Cloud Run 容器（例如透過 Cloud Run Jobs 或暫時開一個修訂）
cd /rails
bundle exec rails runner "
  q = ActiveRecord::Base.connection_db_config.configuration_hash[:database]
  puts 'Queue DB: ' + q.to_s
  n = ActiveRecord::Base.connection.execute(\"SELECT COUNT(*) FROM solid_queue_recurring_tasks\").first[0]
  puts 'Recurring tasks count: ' + n.to_s
  ActiveRecord::Base.connection.execute('SELECT key, schedule FROM solid_queue_recurring_tasks').each { |r| puts r.inspect }
"
```

或只檢查 recurring 表是否存在、筆數是否大於 0（本專案應有 `clear_solid_queue_finished_jobs` 與 `rid3510_process_gaps`）。

### 3. 手動排入一次 Job，看是否有被執行

在 **Rails console**（若 production 有開）或本機用 production 設定跑：

```ruby
# 手動排入 RID3510 補強 Job（不等排程）
Rid3510::ProcessGapsJob.perform_later({ "days" => 7 })
```

再到 **Cloud Run 紀錄**看是否有對應的執行 log（例如 rake 的 puts、或 Job 的 log）。若有，代表 worker 有在吃 job。

### 4. 看是否產出報告檔（實務驗證）

若 **storage** 有掛進持久磁碟（例如 Cloud Run 掛 Cloud Storage 或 volume），可檢查是否出現：

- `storage/rid3510/待補QA-建議-YYYY-MM-DD.md`

若排程為每日凌晨 2 點，可部署後等隔天 2 點過後再檢查；或先手動執行一次 rake 確認路徑與權限沒問題：

```bash
# 本機用 production 環境跑一次（需能寫入 storage）
RAILS_ENV=production ruby bin/rake rid3510:process_gaps
```

---

## 四、注意事項（Cloud Run）

1. **Scale to zero**：Cloud Run 若 scale to zero，該 instance 關掉時就不會跑排程；若要**嚴格每天 2 點執行**，可考慮：
   - 設定 **最小實例數 = 1**（會一直有一個 instance 在跑），或
   - 改用 **Cloud Scheduler** 固定時間打一個 **HTTP endpoint**，由該 endpoint 觸發 `Rid3510::ProcessGapsJob.perform_later`，讓 Solid Queue 在請求當下執行 job。
2. **Storage 持久化**：`chat_gaps.jsonl` 與 `待補QA-建議-*.md` 寫在 `storage/rid3510/`；若 Cloud Run 未掛持久 volume，重啟後會消失。若要長期保留，需掛載 Cloud Storage 或其它持久儲存。
3. **Queue DB**：Solid Queue 使用 `config/database.yml` 的 `queue` 資料庫（SQLite 為 `storage/production_queue.sqlite3`）。若容器重啟且未掛 volume，排程與 job 狀態會重置；若掛了 volume，則會保留。

---

## 五、總結

| 項目 | 說明 |
|------|------|
| **啟用** | 在 Cloud Run 設定環境變數 **`SOLID_QUEUE_IN_PUMA=1`**，重新部署。 |
| **驗證** | 看啟動 log 是否有 Solid Queue、查 `solid_queue_recurring_tasks`、或手動 `ProcessGapsJob.perform_later` 看是否有執行。 |
| **排程** | `config/recurring.yml` 已註冊每日 2:00 執行 `Rid3510::ProcessGapsJob`（處理最近 7 天）。 |

若未啟用 Solid Queue，定期補強**不會自動跑**，需改用手動執行 `ruby bin/rake rid3510:process_gaps` 或外部排程（如 Cloud Scheduler + HTTP 觸發）。
