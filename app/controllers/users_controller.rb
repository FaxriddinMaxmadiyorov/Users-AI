class UsersController < ApplicationController
  def index
    current = UserQuery.permit(params[:current_filters] || {})
    render json: Ai::Assistant.new(current_filters: current).ask(message, history: history)
  end
end
