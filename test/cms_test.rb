ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "minitest/reporters"
require "rack/test"

require_relative "../cms"

Minitest::Reporters.use!

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "history.txt"
  end

  def test_about_md
    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby is..."
    assert_includes last_response.body, "easy to write."
  end

  def test_changes_txt
    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "1993 - Yukihiro Matsumoto dreams up Ruby."
    assert_includes last_response.body, "2019 - Ruby 2.7 released."
  end

  def test_history_txt
    get "/history.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "1993 - Yukihiro Matsumoto dreams up Ruby."
    assert_includes last_response.body, "2019 - Ruby 2.7 released."
  end

  def test_file_does_not_exist
    get "/nonexistant.txt"
    assert_equal 302, last_response.status
    get last_response["Location"] # Request the page that the user was redirected to
    assert_equal 200, last_response.status
    assert_includes last_response.body, "nonexistant.txt does not exist."
    get "/" # Reload the page
    refute_includes last_response.body, "nonexistant.txt does not exist."
  end
end