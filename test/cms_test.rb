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
    assert_includes last_response.body, "Yukihiro Matsumoto dreams"
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

  def test_file_edit_page
    get "/changes.txt/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<form"
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<input type="submit")
  end

  def test_updating_file_txt
    
    post "/changes.txt", new_text: "new content 1993 - Yukihiro Matsumoto dreams up Ruby.  2019 - Ruby 2.7 released."

    assert_equal 302, last_response.status
    get last_response["Location"]
    assert_includes last_response.body, "changes.txt has been updated"
  
    get "/changes.txt"
    assert_includes last_response.body, "new content"
  end

  def test_updating_file_md
    post "/about.md", new_text: "Ruby is... easy to write. And test edit worked."

    assert_equal 302, last_response.status
    get last_response["Location"]

    assert_includes last_response.body, "about.md has been updated"

    get "/about.md"
    assert_includes last_response.body, "edit worked"
  end
end