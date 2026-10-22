require "test_helper"

class UserQueryTest < ActiveSupport::TestCase
  setup do
    User.delete_all
    @a = User.create!(name: "Sardor Karimov", email_address: "sardor@gmail.com", password: "secret1",
                      job_position: "Banking Analyst", last_seen: Time.zone.parse("2026-03-10"), created_at: Date.new(2026, 1, 10))
    @b = User.create!(name: "Peter Novak",    email_address: "peter@mail.ru",    password: "secret1",
                      job_position: "IT Engineer",     last_seen: Time.zone.parse("2026-06-01"), created_at: Date.new(2026, 3, 5), status: "blocked")
    @c = User.create!(name: "Anna Ivanova",   email_address: "anna@gmail.com",   password: "secret1",
                      job_position: "Banking Officer", last_seen: Time.zone.parse("2026-01-20"), created_at: Date.new(2025, 12, 1))
  end

  test "email_starts_with accepts a list and ORs it" do
    q = UserQuery.new("email_starts_with" => %w[s p])
    assert_equal [@a, @b].map(&:id).sort, q.relation.map(&:id).sort
    assert_equal 2, q.count
  end

  test "email_starts_with accepts a comma string from the form" do
    assert_equal 2, UserQuery.new("email_starts_with" => "s, p").count
  end

  test "name_contains is case-insensitive" do
    assert_equal [@c.id], UserQuery.new("name_contains" => "IVAN").relation.map(&:id)
  end

  test "job_contains and query search the job position" do
    assert_equal 2, UserQuery.new("job_contains" => "banking").count
    assert_equal [@b.id], UserQuery.new("query" => "engineer").relation.map(&:id)
  end

  test "status filter accepts only known values" do
    assert_equal [@b.id], UserQuery.new("status" => "blocked").relation.map(&:id)
    assert_equal({}, UserQuery.permit("status" => "deleted"))
  end

  test "last seen range" do
    assert_equal [@b.id], UserQuery.new("seen_after" => "2026-05-01").relation.map(&:id)
    assert_equal 2, UserQuery.new("seen_before" => "2026-05-01").count
  end

  test "registration range" do
    assert_equal 2, UserQuery.new("registered_after" => "2026-01-01").count
    assert_equal 1, UserQuery.new("registered_before" => "2026-01-01").count
  end

  test "default sort is last seen, newest first" do
    assert_equal [@b, @a, @c].map(&:id), UserQuery.new.relation.map(&:id)
  end

  test "sort by name asc" do
    assert_equal [@c, @b, @a].map(&:id), UserQuery.new("sort" => "name", "dir" => "asc").relation.map(&:id)
  end

  test "unknown keys, blanks and invalid sorts are dropped" do
    assert_equal({}, UserQuery.permit("foo" => "bar", "query" => "", "sort" => "password_digest", "dir" => "sideways"))
  end

  test "LIKE wildcards in input are escaped" do
    assert_equal 0, UserQuery.new("name_contains" => "%").count
  end
end
