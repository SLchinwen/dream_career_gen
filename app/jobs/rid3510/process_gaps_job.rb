# frozen_string_literal: true

# 供 config/recurring.yml 排程每日執行「無法回答」紀錄處理與待補 QA 建議產出。
# 實際邏輯在 lib/tasks/rid3510_gaps.rake，本 Job 僅負責觸發 rake task。
module Rid3510
  class ProcessGapsJob < ApplicationJob
    queue_as :default

    # @param options [Hash, Integer] 從 recurring 傳入時為 Hash（如 { "days" => 7 }），或直接傳天數
    def perform(options = {})
      days = options.is_a?(Hash) ? (options["days"] || options[:days] || 7).to_i : options.to_i
      days = 7 if days < 1 || days > 90
      Rails.application.load_tasks
      task = Rake::Task["rid3510:process_gaps"]
      task.reenable
      task.invoke(days)
    end
  end
end
