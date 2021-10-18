require "tilt/erubis"
require "sinatra"
require "sinatra/reloader"
require "redcarpet"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

helpers do
  def render_markdown(text)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(text)
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
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

def invalid_filename?(filename)
  if filename.empty?
    "A name is required."
  elsif [".md", ".txt"].include?(File.extname(filename)) == false
    "Invalid file type. Only markdown (.md) and text (.txt) files are valid."
  else
    false 
  end
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  
  erb :index
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  if params[:username] == "admin" && params[:password] == "secret"
    session[:username] = params[:username]
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
  file_path = File.join(data_path, params[:filename])

  if File.exist?(file_path)
    load_file(file_path)
  elsif params[:filename] == "new"
    erb :new, layout: :layout
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @text = File.read(file_path)

  erb :edit
end

post "/:filename" do
  if params[:filename] == "create"
    invalid = invalid_filename?(params[:new_file])
   if invalid
      session[:message] = invalid #"A name is required."
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
  file_path = File.join(data_path, params[:filename])

  File.delete(file_path)

  session[:message] = "#{params[:filename]} has been deleted."
  redirect "/"
end