require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "accepts a one-character password" do
    user = User.new(name: "A", email_address: "a@example.com", password: "x", password_confirmation: "x")
    assert user.valid?, user.errors.full_messages.to_sentence
  end

  test "rejects an empty password" do
    user = User.new(name: "A", email_address: "a@example.com", password: "")
    assert_not user.valid?
  end
end
