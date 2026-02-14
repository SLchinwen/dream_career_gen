# frozen_string_literal: true

# 簡易關鍵字意圖辨識，對照 rid3510/bot/main.py 的 get_intent 邏輯。
# 意圖對應 rag-intent-paths.yaml 的 key：工作目標、現有活動、E化操作、扶輪知識、基金與獎助金、3510歷史、fallback。
module Rid3510
  class IntentDetector
    INTENT_FALLBACK = "fallback"

    class << self
      # @param text [String] 使用者輸入
      # @return [String] 意圖名稱（與 rag-intent-paths.yaml 的 key 一致）
      def detect(text)
        return INTENT_FALLBACK if text.blank?

        t = text.to_s.strip
        return "3510歷史" if t.include?("總監") || t.include?("屆") || t.include?("歷年")
        return "E化操作" if t.include?("登入") || t.include?("LINE") || t.include?("綁定") || (t.include?("報名") && t.include?("活動"))
        return "現有活動" if t.include?("年會") || t.include?("RYLA") || t.include?("活動") || t.include?("日期") || t.include?("訓練")
        return "工作目標" if t.include?("目標") || (t.include?("社員") && t.include?("成長")) || t.include?("卓越獎")
        return "基金與獎助金" if t.include?("獎助金") || t.include?("DDF") || t.include?("基金")
        return "扶輪知識" if t.include?("四大考驗") || t.include?("DG") || (t.include?("扶輪") && (t.include?("是什麼") || t.include?("意思")))

        INTENT_FALLBACK
      end
    end
  end
end
