require "net/http"

module Ai
  class GeminiClient
    class Error < StandardError; end

    BASE = "https://generativelanguage.googleapis.com/v1beta/models"
    MAX_ATTEMPTS = 4

    def initialize(api_key: ENV.fetch("GEMINI_API_KEY"), model: ENV.fetch("GEMINI_MODEL", "gemini-3.8-flash"))
      @api_key = api_key
      @model   = model
    end

    # system: String, contents: Array, tools: Array of function declarations
    def generate(system:, contents:, tools:)
      uri = URI("#{BASE}/#{@model}:generateContent")
      req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "x-goog-api-key" => @api_key)
      req.body = {
        system_instruction: { parts: [{ text: system }] },
        contents: contents,
        tools: [{ function_declarations: tools }],
        generation_config: { temperature: 0 }
      }.to_json

      MAX_ATTEMPTS.times do |attempt|
        res  = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 60) { |http| http.request(req) }
        body = JSON.parse(res.body)
        return body if res.is_a?(Net::HTTPSuccess)

        retryable = res.code == "429" || res.code.start_with?("5")
        raise Error, body.dig("error", "message") || "HTTP #{res.code}" unless retryable && attempt < MAX_ATTEMPTS - 1

        delay = retry_delay(body, attempt)
        Rails.logger.warn("[gemini] HTTP #{res.code}, retrying in #{delay}s (attempt #{attempt + 1})")
        sleep(delay)
      end
    end

    private

    # Google javobida "retryDelay": "3s" bo‘ladi; bo‘lmasa 2, 4, 8 s.
    def retry_delay(body, attempt)
      info = Array(body.dig("error", "details")).find { |d| d["retryDelay"] }
      secs = info && info["retryDelay"].to_s.delete("s").to_f
      ((secs && secs > 0) ? secs : 2.0**(attempt + 1)).ceil + 1
    end
  end
end
