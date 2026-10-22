module Ai
  # Function-calling loop over the Gemini API: the model picks a tool, Tools runs it against the DB,
  # the result goes back to the model, until it answers in plain text.
  class Assistant
    MAX_STEPS = 6

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are an assistant inside a web application that manages registered users.
      Each user has: name, e-mail address, job position, last seen date, registration date, and status ("active" or "blocked").

      Rules:
      - Never guess numbers or users. Always call a tool to count, list, group or look up. The tools run real database queries.
      - For questions ("how many", "which", "list", "who", "most common") use count_users, list_users, aggregate_users, find_user and answer in text.
      - For commands about the table ("show only", "filter", "select users with", "hide", "sort", "clear") use apply_table_filters, sort_table or clear_table_filters, then confirm briefly what the table now shows and how many rows match.
      - apply_table_filters replaces the whole filter set. If the person wants to add a condition to the current view, call get_table_state first and include the existing filters.
      - "starts with s or p" means email_starts_with: ["s", "p"]. "Filter out X" means show everything except X; if no filter can express that, say so honestly.
      - Tools only read data and change what the table shows. You cannot block, unblock or delete users; if asked, say the person must use the Block/Unblock/Delete buttons above the table.
      - Today's date is #{Date.current.iso8601}. Convert relative dates ("last 30 days", "this year", "in August") into ISO dates yourself.
      - Answer concisely. If a list is long, give the count and the first few.
      - If something cannot be answered with the available tools, say so. Do not invent data.
    PROMPT

    def initialize(current_filters: {}, client: nil)
      @tools  = Tools.new(current_filters: current_filters)
      @client = client || GeminiClient.new
    end

    # Returns { answer: String, command: Hash|nil, tool_calls: Array }
    def ask(message, history: [])
      contents = history.map { |m| { role: m[:role] == "assistant" ? "model" : "user", parts: [{ text: m[:content] }] } }
      contents << { role: "user", parts: [{ text: message }] }
      trace = []

      MAX_STEPS.times do
        body  = @client.generate(system: SYSTEM_PROMPT, contents: contents, tools: Tools::DEFINITIONS)
        parts = body.dig("candidates", 0, "content", "parts") || []
        contents << { role: "model", parts: parts }

        calls = parts.select { |p| p["functionCall"] }
        return finish(parts.map { |p| p["text"] }.compact.join("\n"), trace) if calls.empty?

        responses = calls.map do |p|
          name   = p["functionCall"]["name"]
          args   = (p["functionCall"]["args"] || {}).to_h
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
      { answer: answer.presence || "Done.", command: @tools.ui_command, tool_calls: trace }
    end

    def safe_call(name, args)
      @tools.call(name, args)
    rescue StandardError => e
      Rails.logger.error("[ai tool #{name}] #{e.class}: #{e.message}")
      { error: "#{e.class}: #{e.message}" }
    end
  end
end
