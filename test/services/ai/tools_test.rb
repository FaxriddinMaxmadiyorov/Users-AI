require "test_helper"

class Ai::ToolsTest < ActiveSupport::TestCase
  setup do
    User.delete_all
    User.create!(name: "Sardor Karimov", email_address: "sardor@gmail.com", password: "secret1")
    User.create!(name: "Peter Novak",    email_address: "peter@mail.ru",    password: "secret1")
    User.create!(name: "Anna Ivanova",   email_address: "anna@gmail.com",   password: "secret1")
  end

  test "count_users is exact" do
    assert_equal 2, Ai::Tools.new.call("count_users", { "filters" => { "email_domain" => "gmail.com" } })[:count]
  end

  test "aggregate_users groups by domain, most common first" do
    r = Ai::Tools.new.call("aggregate_users", { "group_by" => "email_domain" })
    assert_equal({ key: "gmail.com", count: 2 }, r[:groups].first)
  end

  test "list_users never exposes password_digest" do
    r = Ai::Tools.new.call("list_users", { "limit" => 1 })
    assert_equal %i[name email registered_at], r[:users].first.keys
  end

  test "apply_table_filters records a navigate command" do
    tools = Ai::Tools.new
    r = tools.call("apply_table_filters", { "filters" => { "email_starts_with" => %w[s p] } })
    assert_equal 2, r[:matching_count]
    assert_equal({ type: "navigate", filters: { "email_starts_with" => %w[s p] } }, tools.ui_command)
  end

  test "sort_table keeps current filters" do
    tools = Ai::Tools.new(current_filters: { "email_domain" => "gmail.com" })
    tools.call("sort_table", { "sort" => "name", "dir" => "desc" })
    assert_equal({ "email_domain" => "gmail.com", "sort" => "name", "dir" => "desc" }, tools.ui_command[:filters])
  end

  test "unknown tool returns an error, not an exception" do
    assert Ai::Tools.new.call("drop_table", {})[:error]
  end
end
