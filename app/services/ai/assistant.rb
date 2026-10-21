module Ai
  class Assistant
    MAX_STEPS = 6

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are an assistant inside a web application that manages registered users.
      Each user has: name, e-mail address, registration date.

      Rules:
      - Never guess numbers or users. Always call a tool to count, list, group or look up. The tools run real database queries.
      - For questions ("how many", "which", "list", "who") use count_users, list_users, aggregate_users, find_user and answer in text.
      - "starts with s or p" means email_starts_with: ["s", "p"].
      - Today's date is #{Date.current.iso8601}. Convert relative dates ("last 30 days", "this year") into ISO dates yourself.
      - Answer concisely. If a list is long, give the count and the first few.
      - If something cannot be answered with the available tools, say so. Do not invent data.
    PROMPT

    def initialize(client: nil, model: nil)
      @tools  = Tools.new
      @client = client || OpenAI::Client.new
      @model  = model || ENV.fetch("OPENAI_MODEL", "gpt-4o-mini")
    end

    # { answer: String, tool_calls: Array }
    def ask(message, history: [])
      messages = [{ role: "system", content: SYSTEM_PROMPT }] + history + [{ role: "user", content: message }]
      trace = []

      MAX_STEPS.times do
        response = @client.chat(parameters: {
          model: @model,
          messages: messages,
          tools: Tools::DEFINITIONS,
          tool_choice: "auto",
          temperature: 0
        })
        msg = response.dig("choices", 0, "message") or raise OpenAI::Error, "empty response"
        messages << msg.slice("role", "content", "tool_calls")

        calls = msg["tool_calls"]
        return finish(msg["content"].to_s, trace) if calls.blank?

        calls.each do |call|
          name = call.dig("function", "name")
          args = parse_args(call.dig("function", "arguments"))
          result = safe_call(name, args)
          trace << { name: name, args: args, result: result }
          messages << { role: "tool", tool_call_id: call["id"], content: result.to_json }
        end
      end

      finish("I could not finish answering within the allowed number of steps.", trace)
    end

    private

    def finish(answer, trace)
      { answer: answer.presence || "Done.", tool_calls: trace }
    end

    def parse_args(raw)
      raw.blank? ? {} : JSON.parse(raw)
    rescue JSON::ParserError
      {}
    end

    def safe_call(name, args)
      @tools.call(name, args)
    rescue StandardError => e
      Rails.logger.error("[ai tool #{name}] #{e.class}: #{e.message}")
      { error: "#{e.class}: #{e.message}" }
    end
  end
end
