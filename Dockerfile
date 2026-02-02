# 使用官方 Ruby 輕量版映像檔 (與您的本機版本對應)
FROM ruby:3.2.2-slim

# 安裝必要的 Linux 套件
# build-essential: 編譯工具
# libpq-dev: 資料庫連線 (擴充性)
# libsqlite3-dev: SQLite 原生擴充
# git, curl: 網路工具
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev libsqlite3-dev git curl

# 設定工作目錄 (在容器內的位置)
WORKDIR /rails

# 1. 先複製 Gem 設定檔 (利用 Docker 快取加速部署)
COPY Gemfile Gemfile.lock ./

# 2. 安裝 Ruby Gems
RUN bundle install

# 3. 複製剩下的所有程式碼
COPY . .

# 4. Production 模式資產預編譯
ENV RAILS_ENV=production
RUN bundle exec rails assets:precompile 2>/dev/null || true

# 5. 啟動腳本：先 db:prepare 再啟動 Rails
COPY bin/docker-start /rails/bin/docker-start
RUN chmod +x /rails/bin/docker-start

EXPOSE 8080
CMD ["/rails/bin/docker-start"]