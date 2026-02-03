# frozen_string_literal: true

module Api
  module Rotary
    # People of Action API 共用：驗證 ROTARY_API_KEY，未通過則 401
    class BaseController < ActionController::Base
      skip_before_action :verify_authenticity_token
      before_action :set_default_format_json
      before_action :authenticate_rotary_api_key

      private

      def authenticate_rotary_api_key
        key = request.authorization.presence&.sub(/\ABearer\s+/i, "") || request.headers["X-API-Key"].to_s.strip
        expected = ApiKeys.rotary_api_key

        if expected.blank?
          render json: { error: "API 未設定 ROTARY_API_KEY" }, status: :service_unavailable
          return
        end
        unless ActiveSupport::SecurityUtils.secure_compare(key, expected)
          render json: { error: "Unauthorized" }, status: :unauthorized
        end
      end

      def set_default_format_json
        request.format = :json unless params[:format]
      end
    end
  end
end
