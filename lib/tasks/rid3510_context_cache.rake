# frozen_string_literal: true

# Context Caching 清除：部署或知識庫更新後，可執行此 task 使下次請求重建 cache。
# 見 rid3510/docs/_治理/Context-Caching-治理與部署更新.md
namespace :rid3510 do
  desc "Clear Context Cache so next request rebuilds with current knowledge base"
  task clear_context_cache: :environment do
    Rid3510::ContextCacheService.clear_cached_name
    puts "Context cache cleared. Next request will create new cache."
  end
end
