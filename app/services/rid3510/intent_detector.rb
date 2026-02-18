# frozen_string_literal: true

# 意圖辨識：關鍵字規則來自 Rid3510 子模組 rag-intent-paths.yaml 的 intent_keywords（單一來源）。
# 意圖名稱與 rag-intent-paths.yaml 的 intent_paths key 一致。
module Rid3510
  class IntentDetector
    INTENT_FALLBACK = "fallback"
    RID3510_BASE = "rid3510"

    class << self
      # @param text [String] 使用者輸入
      # @return [String] 意圖名稱（與 rag-intent-paths.yaml 的 key 一致）
      def detect(text)
        return INTENT_FALLBACK if text.blank?

        t = text.to_s.strip
        keywords = load_intent_keywords
        return detect_with_keywords(t, keywords) if keywords.present?

        detect_fallback(t)
      end

      private

      def load_intent_keywords
        base = Rails.root.join(RID3510_BASE)
        yaml_path = base.join("rag-intent-paths.yaml")
        return {} unless yaml_path.exist?

        data = YAML.load_file(yaml_path)
        return {} unless data.is_a?(Hash)

        data["intent_keywords"] || {}
      end

      # 每個意圖有多條「子句」；每條子句為一組關鍵字，須全部出現在訊息中（AND）。
      # 意圖成立為任一條子句成立（OR）。依 YAML key 順序，先匹配先回傳。
      def detect_with_keywords(message, intent_keywords)
        intent_keywords.each do |intent_name, clauses|
          next if intent_name.to_s == INTENT_FALLBACK

          clauses = Array(clauses)
          clauses.each do |clause|
            keywords = Array(clause).map(&:to_s)
            next if keywords.empty?

            if keywords.all? { |k| message.include?(k) }
              return intent_name.to_s
            end
          end
        end
        INTENT_FALLBACK
      end

      # 子模組無 intent_keywords 時沿用舊邏輯，避免部署未更新子模組時失效
      def detect_fallback(text)
        return "3510歷史" if text.include?("總監") || text.include?("屆") || text.include?("歷年")
        return "E化操作" if text.include?("登入") || text.include?("LINE") || text.include?("綁定") || (text.include?("報名") && text.include?("活動"))
        return "現有活動" if text.include?("年會") || text.include?("RYLA") || text.include?("活動") || text.include?("日期") || text.include?("訓練")
        return "工作目標" if text.include?("目標") || (text.include?("社員") && text.include?("成長")) || text.include?("卓越獎")
        return "基金與獎助金" if text.include?("獎助金") || text.include?("DDF") || text.include?("基金")
        return "扶輪知識" if text.include?("四大考驗") || text.include?("DG") || (text.include?("扶輪") && (text.include?("是什麼") || text.include?("意思")))
        return "分區社團與社友查社" if text.include?("啟禾") || text.include?("分區") || text.include?("例會") || text.include?("歷屆社長") || text.include?("社團一覽") || (text.include?("社") && (text.include?("資料") || text.include?("電話") || text.include?("聯絡")))
        return "社區服務與綠色奇蹟" if text.include?("綠色奇蹟") || text.include?("再生電腦") || text.include?("數位平權") || (text.include?("偏鄉") && (text.include?("電腦") || text.include?("數位"))) || text.include?("捐電腦") || text.include?("受贈電腦") || text.include?("環保再生") || text.include?("reuse")

        INTENT_FALLBACK
      end
    end
  end
end
