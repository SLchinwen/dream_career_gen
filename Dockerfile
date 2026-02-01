# 使用官方 Ruby 輕量版映像檔 (與您的本機版本對應)
FROM ruby:3.2.2-slim

# 安裝必要的 Linux 套件 (Rails 需要這些才能運作)
# build-essential: 編譯工具
# libpq-dev: 資料庫連線工具 (雖用 SQLite 但保留擴充性)
# git: 下載 Gem 用
# curl: 網路工具
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev git curl

# 設定工作目錄 (在容器內的位置)
WORKDIR /rails

# 1. 先複製 Gem 設定檔 (利用 Docker 快取加速部署)
COPY Gemfile Gemfile.lock ./

# 2. 安裝 Ruby Gems
RUN bundle install

# 3. 複製剩下的所有程式碼
COPY . .

# 暴露 Port 3000
EXPOSE 3000

# 啟動 Rails 伺服器 (綁定 0.0.0.0 讓外部可連線)
CMD ["rails", "server", "-b", "0.0.0.0"]