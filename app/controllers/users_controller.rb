class UsersController < ApplicationController
  def index
    @filters = UserQuery.permit(params)
    @query   = UserQuery.new(@filters)
    @users   = @query.relation.limit(200)
    @total   = @query.count
  end

  def block            = bulk("Blocked")   { |users| users.update_all(status: "blocked", updated_at: Time.current) }
  def unblock          = bulk("Unblocked") { |users| users.update_all(status: "active",  updated_at: Time.current) }
  def destroy_selected = bulk("Deleted")   { |users| users.destroy_all }

  private

  def bulk(verb)
    ids = Array(params[:user_ids]).map(&:to_i).uniq
    return redirect_to users_path, alert: "Select at least one user." if ids.empty?

    users = User.where(id: ids)
    count = users.count
    yield users
    redirect_to users_path, notice: "#{verb} #{count} #{"user".pluralize(count)}."
  end
end
