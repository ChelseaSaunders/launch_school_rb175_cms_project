require "tilt/erubis"
require "sinatra"
require "sinatra/reloader"
require "redcarpet"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, escape_html: true
end

helpers do
  def render_markdown(text)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(text)
  end
end

VALID_FILE_EXTENSIONS = %w(.md .txt)

# rubocop:disable Style/ExpandPathArguments
# Rubocop's preferred style breaks code/does not return correct path.

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def image_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/public/images", __FILE__)
  else
    File.expand_path("../public/images", __FILE__)
  end
end

def load_file(path)
  text = File.read(path)
  case File.extname(path)
  when ".md"
    erb render_markdown(text)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    text
  end
end

def load_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
                       File.expand_path("../test/users.yml", __FILE__)
                     else
                       File.expand_path("../users.yml", __FILE__)
                     end
  YAML.load_file(credentials_path)
end

# rubocop:enable Style/ExpandPathArguments

def valid_credentials?(username, password)
  credentials = load_credentials
  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def invalid_filename?(filename)
  if filename.empty?
    "A name is required."
  elsif VALID_FILE_EXTENSIONS.include?(File.extname(filename).downcase) == false
    "Invalid file type. Only markdown (.md) and text (.txt) files are valid."
  else
    false
  end
end

def invalid_image?(imagename)
  if imagename.empty?
    "A name is required."
  elsif File.extname(imagename).downcase != ".jpg"
    "Invalid vile type. Only jpeg (.jpg) files allowed."
  else
    false
  end
end

def signed_in?
  session[:username]
end

def require_signed_in_user
  return if signed_in?

  session[:message] = "You must be signed in to do that."
  redirect "/users/signin"
end

def create_duplicate_file_name(file_name)
  file_ext = File.extname(file_name)
  file_basename = File.basename(file_name, ".*")
  "#{file_basename}_copy#{file_ext}"
end

get "/" do
  document_pattern = File.join(data_path, "*")
  @files = Dir.glob(document_pattern).map { |path| File.basename(path) }

  image_pattern = File.join(image_path, "*")
  @images = Dir.glob(image_pattern).map { |path| File.basename(path) }

  erb :index
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  username = params[:username]
  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    status 422
    erb :signin
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

get "/:filename" do
  require_signed_in_user

  @file_path = File.join(data_path, params[:filename])

  if File.exist?(@file_path)
    load_file(@file_path)
  elsif params[:filename] == "new"
    erb :new
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @text = File.read(file_path)

  erb :edit
end

post "/:filename" do
  require_signed_in_user

  if params[:filename] == "create"
    invalid = invalid_filename?(params[:new_file])

    if invalid
      session[:message] = invalid
      status 422
      erb :new
    else
      File.new("#{data_path}/#{params[:new_file]}", "w")
      session[:message] = "#{params[:new_file]} has been created."
      redirect "/"
    end
  else
    file_path = File.join(data_path, params[:filename])

    File.write(file_path, params[:new_text])

    session[:message] = "#{params[:filename]} has been updated."
    redirect "/"
  end
end

post "/:filename/delete" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])
  File.delete(file_path)

  session[:message] = "#{params[:filename]} has been deleted."
  redirect "/"
end

post "/:filename/duplicate" do
  require_signed_in_user

  original_file_name = params[:filename]
  new_file_name = create_duplicate_file_name(original_file_name)
  original_file_path = File.join(data_path, original_file_name)
  original_file_text = File.read(original_file_path)
  new_file_path = File.join(data_path, new_file_name)

  File.write(new_file_path, original_file_text)

  session[:message] = "Created copy of #{original_file_name}"

  redirect "/"
end

get "/image/:image" do
  require_signed_in_user
  @image = params[:image]
  file_path = File.join(image_path, @image)

  if File.exist?(file_path)
    erb :image
  else
    session[:message] = "Image does not exist. Please select image from list."
    redirect "/"
  end
end

post "/image/upload" do
  require_signed_in_user

  imagename = params[:image][:filename]
  tempfile = params[:image][:tempfile]
  invalid_image = invalid_image?(imagename)

  if invalid_image
    session[:message] = invalid_image
    status 422
  else
    path = "#{image_path}/#{imagename}"
    File.open(path, "w") { |image| image.write tempfile.read }
    session[:message] = "Image uploaded successfully."
  end

  redirect "/"
end
