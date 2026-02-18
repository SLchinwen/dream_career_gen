# frozen_string_literal: true

# 讀取「無法回答」紀錄（chat_gaps.jsonl），去重、彙總，產出待補 QA 建議報告。
# 若設定 GEMINI_API_KEY，會對高頻問題呼叫 API 產生建議意圖與建議答案並寫入同一份報告。
# 設計見 rid3510/docs/_治理/無法回答紀錄與定期補強設計.md
# 建議排程：每日執行，例如 config/recurring.yml 或 crontab: 0 2 * * * cd /path && ruby bin/rake rid3510:process_gaps
namespace :rid3510 do
  desc "Process chat_gaps.jsonl (last N days), dedupe, optional Gemini suggest QA, output 待補QA-建議-YYYY-MM-DD.md"
  task :process_gaps, [:days] => :environment do |_t, args|
    days = (args[:days] || 7).to_i
    days = 30 if days < 1 || days > 90

    path = Rails.root.join("storage", "rid3510", "chat_gaps.jsonl")
    unless path.exist?
      puts "No chat_gaps.jsonl at #{path}. Nothing to process."
      next
    end

    cutoff = (Time.current - days.days).iso8601
    records = []
    File.foreach(path) do |line|
      next if line.blank?
      row = JSON.parse(line)
      records << row if row["at"].to_s >= cutoff
    rescue JSON::ParserError
      next
    end

    # 正規化問題：strip，取前 80 字為 key 做簡單去重並計次
    key_to_rows = {}
    records.each do |r|
      msg = r["user_message"].to_s.strip
      key = msg.length > 80 ? msg[0, 80] : msg
      key = key.gsub(/\s+/, " ")
      key_to_rows[key] ||= []
      key_to_rows[key] << r
    end

    # 依次數排序，取前 N 筆呼叫 API 產生建議（有 GEMINI_API_KEY 時）
    suggest_limit = (ENV["RID3510_GAP_SUGGEST_LIMIT"] || 15).to_i
    suggest_limit = 0 if suggest_limit < 0 || suggest_limit > 50
    sorted_entries = key_to_rows.sort_by { |_k, rows| -rows.size }
    to_suggest = suggest_limit.positive? && ApiKeys.gemini_api_key.present? ? sorted_entries.first(suggest_limit) : []

    suggestions = {}
    to_suggest.each_with_index do |(key, rows), idx|
      user_msg = rows.first["user_message"].to_s.strip
      next if user_msg.blank?
      sug = Rid3510::GapSuggestService.suggest_qa(user_msg)
      suggestions[key] = sug if sug.present?
      sleep(0.5) if idx < to_suggest.size - 1
    end

    out_dir = Rails.root.join("storage", "rid3510")
    out_dir.mkpath unless out_dir.exist?
    out_file = out_dir.join("待補QA-建議-#{Time.current.strftime('%Y-%m-%d')}.md")
    File.open(out_file, "w") do |f|
      f.puts "# 待補 QA 建議（#{Time.current.strftime('%Y-%m-%d')}）"
      f.puts ""
      f.puts "來源：chat_gaps.jsonl 最近 **#{days}** 天，共 **#{records.size}** 筆紀錄，去重後 **#{key_to_rows.size}** 個問題。"
      f.puts "API 建議：已對前 **#{suggest_limit}** 個高頻問題呼叫 Gemini 產生建議意圖與答案（成功 **#{suggestions.size}** 筆）。"
      f.puts ""
      f.puts "## 一、彙總表"
      f.puts ""
      f.puts "| 次數 | 使用者問題（摘要） | 意圖 | 知識庫空？ | 回覆摘要 | 建議意圖（API） | 建議答案摘要（API） |"
      f.puts "|------|--------------------|------|------------|----------|------------------|----------------------|"
      key_to_rows.each do |key, rows|
        r = rows.first
        count = rows.size
        msg = r["user_message"].to_s.strip[0, 60].gsub(/\|/, "｜")
        msg = msg + "…" if r["user_message"].to_s.length > 60
        intent = r["intent"].to_s
        empty = r["context_was_empty"] ? "是" : "否"
        preview = r["reply_preview"].to_s.strip[0, 80].gsub(/\n/, " ").gsub(/\|/, "｜")
        preview = preview + "…" if r["reply_preview"].to_s.length > 80
        sug = suggestions[key]
        sug_intent = sug ? sug[:suggested_intent].to_s.gsub(/\|/, "｜")[0, 20] : ""
        sug_ans = sug ? sug[:suggested_answer].to_s.gsub(/\n/, " ").gsub(/\|/, "｜")[0, 50] : ""
        sug_ans = sug_ans + "…" if sug && sug[:suggested_answer].to_s.length > 50
        f.puts "| #{count} | #{msg} | #{intent} | #{empty} | #{preview} | #{sug_intent} | #{sug_ans} |"
      end
      if suggestions.any?
        f.puts ""
        f.puts "## 二、API 建議 QA 草稿（可複製到知識庫，依次數排序）"
        f.puts ""
        sorted_entries.each do |key, _rows|
          sug = suggestions[key]
          next unless sug
          user_msg = key_to_rows[key]&.first&.dig("user_message").to_s.strip
          next if user_msg.blank?
          f.puts "### Q"
          f.puts user_msg.gsub(/\n/, " ")
          f.puts ""
          f.puts "**建議意圖**：#{sug[:suggested_intent]}"
          f.puts ""
          f.puts "**建議答案**："
          f.puts sug[:suggested_answer].to_s
          f.puts ""
          f.puts "---"
          f.puts ""
        end
      end
    end
    puts "Wrote #{key_to_rows.size} unique questions to #{out_file} (API suggestions: #{suggestions.size})"
  end
end
