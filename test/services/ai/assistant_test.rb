require "test_helper"

class Ai::AssistantTest < ActiveSupport::TestCase
  class FakeGemini
    def initialize(*responses) = @responses = responses
    def generate(**) = { "candidates" => [{ "content" => { "parts" => @responses.shift } }] }
  end

  setup do
    User.delete_all
    User.create!(name: "Sardor Karimov", email_address: "sardor@gmail.com", password: "secret1")
    User.create!(name: "Anna Ivanova",   email_address: "anna@gmail.com",   password: "secret1")
  end

  test "runs the tool loop and returns the final text" do
    client = FakeGemini.new(
      [{ "functionCall" => { "name" => "count_users", "args" => { "filters" => { "email_starts_with" => ["s"] } } } }],
      [{ "text" => "There is 1 such user." }]
    )
    r = Ai::Assistant.new(client: client).ask("how many start with s?")
    assert_equal "There is 1 such user.", r[:answer]
    assert_equal "count_users", r[:tool_calls].first[:name]
    assert_equal 1, r[:tool_calls].first[:result][:count]
    assert_nil r[:command]
  end

  test "ui tool produces a command" do
    client = FakeGemini.new(
      [{ "functionCall" => { "name" => "clear_table_filters", "args" => {} } }],
      [{ "text" => "Cleared." }]
    )
    r = Ai::Assistant.new(client: client).ask("clear filters")
    assert_equal({ type: "navigate", filters: {} }, r[:command])
  end

  test "stops after MAX_STEPS" do
    loop_forever = Array.new(10) { [{ "functionCall" => { "name" => "get_table_state", "args" => {} } }] }
    r = Ai::Assistant.new(client: FakeGemini.new(*loop_forever)).ask("loop")
    assert_match(/could not finish/, r[:answer])
  end
end
