# frozen_string_literal: true

# 簡易關鍵字意圖辨識，對照 rid3510/bot/main.py 的 get_intent 邏輯。
# 意圖對應 rag-intent-paths.yaml 的 key：工作目標、現有活動、E化操作、扶輪知識、基金與獎助金、3510歷史、分區社團與社友查社、fallback。
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
        # 分區社團、例會時間、某社資料、啟禾社背景／歷屆社長（對應 YAML 分區社團與社友查社 → 參考-啟禾社等）
        return "分區社團與社友查社" if t.include?("啟禾") || t.include?("分區") || t.include?("例會") || t.include?("歷屆社長") || t.include?("社團一覽") || (t.include?("社") && (t.include?("資料") || t.include?("電話") || t.include?("聯絡")))
        # 綠色奇蹟、再生電腦、數位平權、偏鄉（對應 YAML 綠色奇蹟與數位平權 → 參考-綠色奇蹟與扶輪服務）
        return "綠色奇蹟與數位平權" if t.include?("綠色奇蹟") || t.include?("再生電腦") || t.include?("數位平權") || (t.include?("偏鄉") && (t.include?("電腦") || t.include?("數位"))) || t.include?("捐電腦") || t.include?("受贈電腦") || t.include?("環保再生") || t.include?("reuse")

        INTENT_FALLBACK
      end
    end
  end
end
