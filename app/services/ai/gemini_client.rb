require "net/http"

module Ai
  class GeminiClient
    class Error < StandardError; end
    BASE = "https://generativelanguage.googleapis.com/v1beta/models"

    def initialize(api_key: ENV.fetch("GEMINI_API_KEY"), model: ENV.fetch("GEMINI_MODEL", "gemini-2.5-flash"))
      @api_key, @model = api_key, model
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

      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 60) { |http| http.request(req) }
      body = JSON.parse(res.body)
      raise Error, body.dig("error", "message") || "HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)
      body
    end
  end
end
