module Ai
  class Assistant
    MAX_STEPS = 6
    SYSTEM_PROMPT = <<~PROMPT.freeze
      ... (avvalgi matn)
    PROMPT

    def initialize(client: nil)
      @tools  = Tools.new
      @client = client || GeminiClient.new
    end

    def ask(message, history: [])
      contents = history.map { |m| { role: m[:role] == "assistant" ? "model" : "user", parts: [{ text: m[:content] }] } }
      contents << { role: "user", parts: [{ text: message }] }
      trace = []

      MAX_STEPS.times do
        body  = @client.generate(system: SYSTEM_PROMPT, contents: contents, tools: Tools::DEFINITIONS)
        parts = body.dig("candidates", 0, "content", "parts") || []
        contents << { role: "model", parts: parts }

        calls = parts.select { |p| p["functionCall"] }
        if calls.empty?
          text = parts.map { |p| p["text"] }.compact.join("\n")
          return finish(text, trace)
        end

        responses = calls.map do |p|
          name = p["functionCall"]["name"]
          args = (p["functionCall"]["args"] || {}).to_h
          result = safe_call(name, args)
          trace << { name: name, args: args, result: result }
          { functionResponse: { name: name, response: { result: result } } }
        end
        contents << { role: "user", parts: responses }
      end

      finish("I could not finish answering within the allowed number of steps.", trace)
    end

    private

    def finish(answer, trace)
      { answer: answer.presence || "Done.", tool_calls: trace }
    end

    def safe_call(name, args)
      @tools.call(name, args)
    rescue StandardError => e
      Rails.logger.error("[ai tool #{name}] #{e.class}: #{e.message}")
      { error: "#{e.class}: #{e.message}" }
    end
  end
end
