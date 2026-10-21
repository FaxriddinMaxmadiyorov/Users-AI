class UsersController < ApplicationController
  def index
    @filters = UserQuery.permit(params)
    @query   = UserQuery.new(@filters)
    @users   = @query.relation.limit(200)
    @total   = @query.count
  end
end
