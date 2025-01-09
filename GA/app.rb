require 'sinatra'
require 'puma'
require 'sinatra/flash'
require 'bcrypt'
require 'fileutils'
require 'sinatra/reloader'
require 'sqlite3'

enable :sessions

# Database setup
DB_FILE = 'app.db'

def setup_database
  db = SQLite3::Database.new(DB_FILE)
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL
    );
  SQL
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS uploads (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      filename TEXT NOT NULL,
      upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(user_id) REFERENCES users(id)
    );
  SQL
  db.close
end

setup_database

# Helper method to connect to the database
def db_connection
  SQLite3::Database.new(DB_FILE)
end

# Ensure the uploads directory exists
uploads_dir = "./uploads"
FileUtils.mkdir_p(uploads_dir)

# Home page (or dashboard)
get '/' do
  session[:logged_in] ? redirect('/dashboard') : slim(:login)
end

# Login handler
post '/login' do
  username, password = params.values_at(:username, :password)
  db = db_connection

  user = db.execute("SELECT id, password FROM users WHERE username = ?", [username]).first

  if user && BCrypt::Password.new(user[1]) == password
    session[:logged_in] = true
    session[:user_id] = user[0]
    session[:username] = username
    redirect '/dashboard'
  else
    flash[:error] = "Invalid username or password."
    redirect '/'
  end
end

# Logout route
get '/logout' do
  session.clear
  redirect '/'
end

# Registration page
get '/register' do
  slim :register
end

# Registration handler
post '/register' do
  username, password = params.values_at(:username, :password)
  db = db_connection

  if username.empty? || password.empty?
    flash[:error] = "Username and password cannot be empty."
  else
    begin
      hashed_password = BCrypt::Password.create(password)
      db.execute("INSERT INTO users (username, password) VALUES (?, ?)", [username, hashed_password])
      flash[:success] = "Account created successfully. You can now log in."
      redirect '/'
    rescue SQLite3::ConstraintException
      flash[:error] = "Username already exists. Please choose another."
    end
  end

  redirect '/register'
end

# Dashboard (file upload and list)
get '/dashboard' do
  redirect '/' unless session[:logged_in]

  db = db_connection
  @uploaded_files = db.execute("SELECT filename FROM uploads WHERE user_id = ?", [session[:user_id]])
  
  slim :dashboard
end

# Handle file uploads
post '/upload' do
  redirect '/' unless session[:logged_in]

  if params[:file]&.dig(:filename)
    filename = params[:file][:filename]
    tempfile = params[:file][:tempfile]

    user_dir = "#{uploads_dir}/#{session[:username]}"
    FileUtils.mkdir_p(user_dir)

    # Save file on disk
    File.open("#{user_dir}/#{filename}", 'wb') { |f| f.write(tempfile.read) }

    # Save file metadata in the database
    db = db_connection
    db.execute("INSERT INTO uploads (user_id, filename) VALUES (?, ?)", [session[:user_id], filename])

    flash[:success] = "File uploaded successfully!"
  else
    flash[:error] = "No file selected for upload."
  end
  redirect '/dashboard'
end

# Download file
get '/download/:filename' do |filename|
  redirect '/' unless session[:logged_in]

  user_file = "#{uploads_dir}/#{session[:username]}/#{filename}"
  if File.exist?(user_file)
    send_file(user_file, filename: filename, type: 'Application/octet-stream')
  else
    flash[:error] = "File not found."
    redirect '/dashboard'
  end
end

# Clear all uploaded files for the logged-in user
post '/clear_files' do
  redirect '/' unless session[:logged_in]

  user_dir = "#{uploads_dir}/#{session[:username]}"
  db = db_connection

  if Dir.exist?(user_dir)
    FileUtils.rm_rf(Dir.glob("#{user_dir}/*")) # Deletes all files in the directory

    # Clear file metadata from the database
    db.execute("DELETE FROM uploads WHERE user_id = ?", [session[:user_id]])
    flash[:success] = "All files have been cleared successfully."
  else
    flash[:error] = "No files to delete."
  end

  redirect '/dashboard'
end
