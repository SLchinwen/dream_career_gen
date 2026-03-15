# frozen_string_literal: true

require "net/http"
require "json"

# 呼叫 GAS 網頁應用程式，取得共用雲端硬碟的相簿列表與相片 URL。
# 環境變數 GAS_ALBUM_WEB_APP_URL 為 GAS 部署後的 exec URL。
class GasAlbumService
  class Error < StandardError; end
  class NotConfigured < Error; end

  TIMEOUT_SEC = 15
  MAX_REDIRECTS = 5

  # @param folder_id [String, nil] 若提供，則列出該資料夾下的子資料夾；否則列出 ROOT 下的子資料夾
  # @return [Hash] { folders: [ { id, name, photo_count } ] } 或 { error: String }
  def self.fetch_folders(folder_id: nil)
    new.fetch_folders(folder_id)
  end

  # @param folder_id [String] 資料夾 ID
  # @return [Hash] { folder_name:, photos: [ { id, name, thumbnail_link, web_content_link } ] } 或 { error: String }
  def self.fetch_photos(folder_id)
    new.fetch_photos(folder_id)
  end

  def initialize(base_url: nil)
    @base_url = (base_url || ENV["GAS_ALBUM_WEB_APP_URL"]).to_s.strip
  end

  def fetch_folders(folder_id = nil)
    return { "error" => "尚未設定 GAS_ALBUM_WEB_APP_URL" } if @base_url.blank?

    url = "#{@base_url}?action=folders"
    url += "&folder_id=#{ERB::Util.url_encode(folder_id)}" if folder_id.present?
    get_json(url)
  end

  def fetch_photos(folder_id)
    return { "error" => "尚未設定 GAS_ALBUM_WEB_APP_URL" } if @base_url.blank?
    return { "error" => "請提供相簿 ID" } if folder_id.blank?

    get_json("#{@base_url}?action=photos&folder_id=#{ERB::Util.url_encode(folder_id)}")
  end

  private

  def get_json(url_string, redirect_count = 0)
    return { "error" => "GAS 重新導向次數過多" } if redirect_count > MAX_REDIRECTS

    uri = URI.parse(url_string)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = TIMEOUT_SEC
    http.read_timeout = TIMEOUT_SEC
    req = Net::HTTP::Get.new(uri.request_uri)
    res = http.request(req)

    # GAS 部署網址常會先回傳 302，跟隨 Location 再請求
    if res.is_a?(Net::HTTPRedirection) && res["location"].present?
      location = res["location"]
      location = URI.join(uri, location).to_s if location.start_with?("/")
      return get_json(location, redirect_count + 1)
    end

    body = res.body.to_s
    return { "error" => "GAS 回傳非 200（#{res.code}）" } unless res.is_a?(Net::HTTPSuccess)
    return { "error" => "GAS 回傳空內容" } if body.blank?

    JSON.parse(body)
  rescue JSON::ParserError => e
    { "error" => "GAS 回傳非 JSON：#{e.message}" }
  rescue StandardError => e
    Rails.logger.warn("GasAlbumService: #{e.class} #{e.message}")
    { "error" => "無法取得資料，請稍後再試（#{e.message})" }
  end
end
