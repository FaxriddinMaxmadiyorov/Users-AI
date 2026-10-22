class AssistantController < ApplicationController
  # POST /assistant  { message:, history: [{ role, content }], current_filters: {} }
  rate_limit to: 20, within: 1.minute, with: -> { render json: { error: "Too many requests, try again in a minute." }, status: :too_many_requests }

  def create
    message = params[:message].to_s.strip
    return render json: { error: "Empty message" }, status: :unprocessable_entity if message.blank?

    assistant = Ai::Assistant.new(current_filters: current_filters)
    render json: assistant.ask(message, history: history)
  rescue Ai::GeminiClient::Error, Net::OpenTimeout, Net::ReadTimeout => e
    render json: { error: "AI provider error: #{e.message}" }, status: :bad_gateway
  end

  private

  # Jadvalning hozirgi filtrlari (brauzer yuboradi), faqat ma'lum kalitlar qoladi.
  def current_filters
    UserQuery.permit(params[:current_filters] || {})
  end

  # Suhbat tarixi: oxirgi 20 ta xabar, faqat user/assistant rollari.
  def history
    Array(params[:history]).last(20).filter_map do |m|
      role = m[:role].to_s
      next unless %w[user assistant].include?(role)
      { role: role, content: m[:content].to_s }
    end
  end
end
