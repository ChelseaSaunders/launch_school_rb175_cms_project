ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "minitest/reporters"
require "rack/test"
require "fileutils"

require_relative "../cms"

Minitest::Reporters.use!

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_file(name, text="")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(text)
    end
  end

  def test_index
    create_file("about.md")
    create_file("changes.txt")
    create_file("history.txt")

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "history.txt"
  end

  def test_about_md
    create_file("about.md", "Ruby is... easy to write.")

    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby is..."
    assert_includes last_response.body, "easy to write."
  end

  def test_changes_txt
    create_file("changes.txt", "Testing... 1...2...3")

    get "/changes.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Testing... "
    assert_includes last_response.body, "1...2...3"
  end

  def test_history_txt
    create_file("history.txt", "Another test, this is history.txt.")

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Another test, "
    assert_includes last_response.body, "this is history.txt."
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
    create_file("changes.txt")

    get "/changes.txt/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<form"
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<input type="submit")
  end

  def test_updating_file_txt
    create_file("changes.txt", "This is the original text.")

    post "/changes.txt", new_text: "This is the edited text."

    assert_equal 302, last_response.status
    get last_response["Location"]
    assert_includes last_response.body, "changes.txt has been updated"
  
    get "/changes.txt"
    
    assert_includes last_response.body, "This is the edited text."
  end

  def test_updating_file_md
    create_file("about.md", "This is the original text.")

    post "/about.md", new_text: "This is the edited text."

    assert_equal 302, last_response.status
    get last_response["Location"]
    assert_includes last_response.body, "about.md has been updated"

    get "/about.md"

    assert_includes last_response.body, "This is the edited text."
  end

  def test_view_new_document_form
    get "/new"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<input type="submit")
  end

  def test_create_new_document
    post "/create", new_file: "test.txt"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "test.txt has been created"

    get "/"
    assert_includes last_response.body, "test.txt"
  end

  def test_create_new_document_without_filename
    post "/create", new_file: ""
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

  def test_create_new_document_with_invalid_extension
    post "/create", new_file: "invalid.wrongext"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid file type"
  end

  def test_deleting_document
    create_file("new_file.md")

    post "/new_file.md/delete"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "new_file.md has been deleted."

    get "/"
    refute_includes last_response.body, "new_file.md"
  end

  def test_valid_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin."
    assert_includes last_response.body, "Welcome"
  end

  def test_invalid_signin
    post "/users/signin", username: "invalid", password: "wrong"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid Credentials"
  end

  def test_signout
    post "/users/signin", username: "admin", password: "secret"
    get last_response["Location"]
    assert_includes last_response.body, "Welcome"
    post "/users/signout"
    assert_equal 302, last_response.status 
    get last_response["Location"]
    assert_includes last_response.body, "You have been signed out."
    refute_includes last_response.body, "Signed in as admin."
  end
end