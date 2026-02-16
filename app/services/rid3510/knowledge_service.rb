# frozen_string_literal: true

require "set"
require "yaml"

# 從子模組 rid3510 讀取 rag-intent-paths.yaml 與對應 .md，組合成知識庫 context。
# 路徑：Rails.root.join("rid3510", ...)，YAML 內路徑為相對 rid3510 根目錄。
module Rid3510
  class KnowledgeService
    DEFAULT_MAX_CHARS = 6000
    DEFAULT_FALLBACK_MESSAGE = "（暫無相關資料，請聯繫地區 e 化主委或地區辦事處。）"

    def initialize(base_dir: nil)
      @base_dir = base_dir || Rails.root.join("rid3510")
    end

    # @return [Hash, Array] intent_paths hash, fallback_paths array
    def load_intent_paths
      yaml_path = @base_dir.join("rag-intent-paths.yaml")
      return [{}, []] unless yaml_path.exist?

      data = YAML.load_file(yaml_path)
      intent_paths = data.is_a?(Hash) ? (data["intent_paths"] || {}) : {}
      fallback_paths = data.is_a?(Hash) ? (data["fallback_paths"] || []) : []
      [intent_paths, fallback_paths]
    end

    # @param intent [String] 意圖名稱（與 rag-intent-paths.yaml 的 key 一致）
    # @param max_chars [Integer] context 總字數上限
    # @return [String] 合併後的知識庫文字
    def context_for_intent(intent, max_chars: DEFAULT_MAX_CHARS)
      intent_paths, fallback_paths = load_intent_paths
      paths = intent_paths[intent] || fallback_paths
      paths = fallback_paths if paths.blank?

      parts = []
      total = 0

      Array(paths).each do |rel_path|
        # YAML 路徑為相對 rid3510 根目錄，可能含 docs/xx/yy.md，需拆成多段以相容 Windows
        full = @base_dir.join(*rel_path.to_s.split("/"))
        next unless full.exist? && full.extname == ".md"

        begin
          text = File.read(full, encoding: "UTF-8")
          text = text[0, max_chars - total] if total + text.length > max_chars
          parts << "--- #{rel_path} ---\n#{text}"
          total += text.length
          break if total >= max_chars
        rescue StandardError
          next
        end
      end

      parts.any? ? parts.join("\n\n") : DEFAULT_FALLBACK_MESSAGE
    end

    # 合併所有意圖與 fallback 路徑的知識庫內容，供 Context Caching 使用。
    # @param max_chars [Integer] 總字數上限
    # @return [String]
    def merged_context_for_cache(max_chars: 12_000)
      intent_paths, fallback_paths = load_intent_paths
      all_paths = (intent_paths.values.flatten + Array(fallback_paths)).compact.uniq
      return DEFAULT_FALLBACK_MESSAGE if all_paths.empty?

      parts = []
      total = 0
      seen = Set.new

      all_paths.each do |rel_path|
        next if seen.include?(rel_path)
        seen << rel_path

        full = @base_dir.join(*rel_path.to_s.split("/"))
        next unless full.exist? && full.extname == ".md"

        begin
          text = File.read(full, encoding: "UTF-8")
          text = text[0, max_chars - total] if total + text.length > max_chars
          parts << "--- #{rel_path} ---\n#{text}"
          total += text.length
          break if total >= max_chars
        rescue StandardError
          next
        end
      end

      parts.any? ? parts.join("\n\n") : DEFAULT_FALLBACK_MESSAGE
    end
  end
end
