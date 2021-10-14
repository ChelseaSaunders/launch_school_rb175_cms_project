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

before do
  @root = File.expand_path("..", __FILE__)
  @files = Dir.glob(@root + "/data/*").map { |filepath| filepath.split("/").last }
end

def load_file(filename)
  case File.extname(filename) 
  when ".md"
    render_markdown(File.read(@root + "/data/#{filename}"))
  when ".txt"
    headers["Content-Type"] = "text/plain"
    File.read(@root + "/data/#{filename}")
  end
end

get "/" do
  erb :index, layout: :layout
end

get "/:filename" do
  filename = params[:filename]

  if !@files.include?(filename)
    session[:message] = "#{filename} does not exist."
    redirect "/"
  else 
    load_file(filename)
  end
end

get "/:filename/edit" do
  @filename = params[:filename]
  @text = File.read(@root + "/data/#{@filename}")
  erb :edit, layout: :layout
end

post "/:filename" do
  @filename = params[:filename]
  #full_file_path = File.expand_path("../data", __FILE__) + @filename

  File.write(@root + "/data/#{@filename}", "#{params[:new_text]}")
  session[:message] = "#{@filename} has been updated."
  redirect "/"
end