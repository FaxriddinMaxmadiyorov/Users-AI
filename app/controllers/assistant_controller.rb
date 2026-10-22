class AssistantController < ApplicationController
  # POST /assistant  { message:, history: [{role, content}] }
  def create
    message = params[:message].to_s.strip
    return render json: { error: "Empty message" }, status: :unprocessable_entity if message.blank?

    history = Array(params[:history]).first(20)
                .map { |m| { role: m[:role].to_s, content: m[:content].to_s } }
                .select { |m| %w[user assistant].include?(m[:role]) }

    render json: Ai::Assistant.new.ask(message, history: history)
  rescue Ai::GeminiClient::Error, Net::OpenTimeout, Net::ReadTimeout => e
    render json: { error: "AI provider error: #{e.message}" }, status: :bad_gateway
  end
end
