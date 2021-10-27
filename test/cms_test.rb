ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "minitest/reporters"
require "rack/test"
require "fileutils"
require "bcrypt"

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

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
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

  def test_about_md_signed_in
    create_file("about.md", "Ruby is... easy to write.")

    get "/about.md", {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby is..."
    assert_includes last_response.body, "easy to write."
  end

  def test_about_md_not_signed_in
    create_file("about.md", "Ruby is... easy to write.")
    get "/about.md"

    assert_equal 302, last_response.status
    assert_includes session[:message], "You must be signed in to do that."
    refute_includes last_response.body, "Ruby is..."
  end

  def test_changes_txt_signed_in
    create_file("changes.txt", "Testing... 1...2...3")

    get "/changes.txt", {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Testing... "
    assert_includes last_response.body, "1...2...3"
  end

  def test_changes_txt_not_signed_in
    create_file("changes.txt", "Testing... 1...2...3")

    get "/changes.txt"

    assert_equal 302, last_response.status
    assert_includes session[:message], "You must be signed in to do that."
    refute_includes last_response.body, "Testing..."
  end

  def test_history_txt_signed_in
    create_file("history.txt", "Another test, this is history.txt.")

    get "/history.txt", {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Another test, "
    assert_includes last_response.body, "this is history.txt."
  end

  def test_history_txt_not_signed_in
    create_file("history.txt", "Another test, this is history.txt.")

    get "/history.txt"

    assert_equal 302, last_response.status
    assert_includes session[:message], "You must be signed in to do that."
    refute_includes last_response.body, "Another test"
  end

  def test_file_does_not_exist
    get "/nonexistant.txt", {}, admin_session

    assert_equal 302, last_response.status
    assert_includes session[:message], "nonexistant.txt does not exist."

    get last_response["Location"]
    assert_equal 200, last_response.status

    get "/"

    refute_includes last_response.body, "nonexistant.txt does not exist."
  end

  def test_file_edit_page_signed_in
    create_file("changes.txt")

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<form"
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<input type="submit")
  end

  def test_file_edit_page_not_signed_in
    create_file("changes.txt")

    get "/changes.txt/edit"
    assert_equal 302, last_response.status
    assert_includes session[:message], "You must be signed in to do that."
    refute_includes last_response.body, "<form"
  end

  def test_updating_file_txt_signed_in
    create_file("changes.txt", "This is the original text.")

    post "/changes.txt", { new_text: "This is the edited text." }, admin_session
    assert_equal 302, last_response.status
    assert_includes session[:message], "changes.txt has been updated"

    get "/changes.txt"
    assert_includes last_response.body, "This is the edited text."
  end

  def test_updating_file_txt_not_signed_in
    create_file("changes.txt", "This is the original text.")

    post "/changes.txt", new_text: "This is the edited text."
    assert_equal 302, last_response.status
    assert_includes session[:message], "You must be signed in to do that."
    
    get "/changes.txt", {}, admin_session
    assert_includes last_response.body, "This is the original text."
    refute_includes last_response.body, "This is the edited text."
  end

  def test_updating_file_md_signed_in
    create_file("about.md", "This is the original text.")

    post "/about.md", { new_text: "This is the edited text." }, admin_session

    assert_equal 302, last_response.status
    assert_includes session[:message], "about.md has been updated"

    get "/about.md"
    assert_includes last_response.body, "This is the edited text."
  end

  def test_updating_file_md_not_signed_in
    create_file("about.md", "This is the original text.")

    post "/about.md", { new_text: "This is the edited text." }
    assert_equal 302, last_response.status
    assert_includes session[:message], "You must be signed in to do that."

    get "/about.md", {}, admin_session
    assert_includes last_response.body, "This is the original text."
    refute_includes last_response.body, "This is the edited text."
  end

  def test_view_new_document_form_signed_in
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<input type="submit")
  end

  def test_view_new_document_form_not_signed_in
    get "/new"

    assert_equal 302, last_response.status
    assert_includes session[:message], "You must be signed in to do that."
    refute_includes last_response.body, "<input"
  end

  def test_create_new_document_signed_in
    post "/create", { new_file: "test.txt" }, admin_session
    assert_equal 302, last_response.status
    assert_includes session[:message], "test.txt has been created"

    get "/"
    assert_includes last_response.body, "test.txt"
  end

  def test_create_new_document_not_signed_in
    post "/create", new_file: "test.txt"
    assert_equal 302, last_response.status
    assert_includes session[:message], "You must be signed in to do that."

    get "/"
    refute_includes last_response.body, "test.txt"
  end

  def test_create_new_document_without_filename
    post "/create", { new_file: "" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

  def test_create_new_document_with_invalid_extension
    post "/create", { new_file: "invalid.wrongext" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid file type"
  end

  def test_deleting_document_signed_in
    create_file("new_file.md")

    post "/new_file.md/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_includes session[:message], "new_file.md has been deleted."

    get "/"
    refute_includes last_response.body, %q(href="new_file.md")
  end

  def test_deleting_document_not_signed_in
    create_file("new_file.md")

    post "/new_file.md/delete"
    assert_equal 302, last_response.status
    assert_includes session[:message], "You must be signed in to do that."
    
    get "/"
    assert_includes last_response.body, "new_file.md"
  end

  def test_duplicating_document_signed_in
    create_file("new.txt", "original text")
    post"/new.txt/duplicate", {}, admin_session
    assert_equal 302, last_response.status
    assert_includes session[:message], "Created copy of new.txt"

    get "/"
    assert_includes last_response.body, "new_copy.txt"

    get "/new_copy.txt"
    assert_includes last_response.body, "original text"
  end

  def test_duplicating_document_not_signed_in
    create_file("new.txt", "original text")
    post"/new.txt/duplicate"
  
    assert_equal 302, last_response.status
    assert_includes session[:message], "You must be signed in to do that."

    get "/"
    refute_includes last_response.body, "new_copy.txt"

    get "/new_copy.txt"
    assert_equal 302, last_response.status
    assert_includes session[:message], "You must be signed in to do that."
  end
  
  def test_viewing_valid_image_signed_in
    get "/image/aubrey2.JPG", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<img src=)
  end

  def test_viewing_valid_image_not_signed_in
    get "/image/aubrey2.JPG"
    assert_equal 302, last_response.status
    assert_includes session[:message], "You must be signed in to do that."
  end

  def test_viewing_invalid_image_signed_in
    get "/image/notafile.JPG", {}, admin_session
    assert_equal 302, last_response.status
    assert_includes session[:message], "Image does not exist."
  end
  
  def test_viewing_invalid_image_not_signed_in
    get "/image/notafile.JPG"
    assert_equal 302, last_response.status
    assert_includes session[:message], "You must be signed in to do that."
  end

  def test_adding_image_signed_in
    skip
    stored_image_path = File.expand_path("../test/public/images", __FILE__)
    image = ENV[File.open("#{stored_image_path}/aubrey.jpg")]
    
    post "/image/upload", { image: { filename: "aubrey.jpg", tempfile: image } }, admin_session
    assert_equal 302, last_response.status
    assert_includes session[:message], "Image uploaded successfully"

    get "/"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "aubrey.jpg"
  end

  def test_adding_image_not_signed_in
    skip
  end

  def test_valid_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_includes session[:message], "Welcome"
    assert_equal session[:username], "admin"

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin."
  end

  def test_invalid_signin
    post "/users/signin", username: "invalid", password: "wrong"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid Credentials"
  end

  def test_signout
    get "/", {}, { "rack.session" => { username: "admin" } }
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    assert_equal 302, last_response.status
    assert_includes session[:message], "You have been signed out."
    get last_response["Location"]
    assert_includes last_response.body, "Sign In"
    refute_includes last_response.body, "Signed in as admin"
  end
end
