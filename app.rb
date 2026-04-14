# app.rb
# CarePulse - High-Efficiency Single File Backend (Sinatra + ActiveRecord)
require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  gem "sinatra", "~> 4.0"
  gem "activerecord", "~> 8.0"
  gem "rackup"
  gem "sqlite3"
  gem "bcrypt"
  gem "rack-cors"
  gem "puma"
end

require "sinatra"
require "active_record"
require "rackup"
require "rack/cors"

# Database Setup
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: "carepulse.sqlite3")

ActiveRecord::Schema.define do
  create_table :services, force: :cascade unless table_exists?(:services) do |t|
    t.string :title; t.text :description; t.string :icon; t.timestamps
  end
  create_table :appointments, force: :cascade unless table_exists?(:appointments) do |t|
    t.string :name; t.string :email; t.integer :service_id; t.datetime :date; t.text :message; t.string :status, default: "pending"; t.timestamps
  end
  create_table :feedbacks, force: :cascade unless table_exists?(:feedbacks) do |t|
    t.string :name; t.integer :rating; t.text :comment; t.boolean :is_published, default: false; t.timestamps
  end
  create_table :users, force: :cascade unless table_exists?(:users) do |t|
    t.string :email; t.string :password_digest; t.boolean :is_admin, default: false; t.timestamps
  end
end

class Service < ActiveRecord::Base; has_many :appointments; end
class Appointment < ActiveRecord::Base; belongs_to :service, optional: true; end
class Feedback < ActiveRecord::Base; end
class User < ActiveRecord::Base; has_secure_password; end

# Seed
admin = User.find_or_initialize_by(email: "admin@carepulse.com")
admin.password = "admin123"
admin.is_admin = true
admin.save! if admin.changed?

# Sinatra App Config
set :port, ENV['PORT'] || 3000
set :bind, '0.0.0.0'
set :public_folder, '.'
enable :sessions

# ✨ One-Click Experience: Automatically open the browser on Windows
Thread.new do
  sleep 2 # Wait for Sinatra to wake up
  if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
    system("start http://localhost:#{settings.port}")
    puts "🚀 CarePulse: Auto-launching browser at http://localhost:#{settings.port}"
  end
end

puts "🏥 CarePulse: Starting server on port #{settings.port}..."

use Rack::Cors do
  allow do
    origins '*'
    resource '*', headers: :any, methods: [:get, :post, :options, :delete, :put]
  end
end

helpers do
  def req_admin
    redirect "/admin/login" unless session[:uid]
  end
end

# Frontend
get '/' do
  send_file 'index.html'
end

# API Endpoints
get '/api/services' do
  content_type :json
  Service.all.to_json
end

post '/api/appointments' do
  content_type :json
  data = JSON.parse(request.body.read)
  Appointment.create(data['appointment'])
  { status: 'success' }.to_json
end

post '/api/feedback' do
  content_type :json
  data = JSON.parse(request.body.read)
  Feedback.create(data['feedback'])
  { status: 'success' }.to_json
end

# Admin Panel
get '/admin' do
  req_admin
  @services = Service.all; @appts = Appointment.all; @fbs = Feedback.all
  erb DASH_HTML
end

get '/admin/login' do
  erb LOGIN_HTML
end

post '/admin/login' do
  u = User.find_by(email: params[:email])
  if u&.authenticate(params[:password])
    session[:uid] = u.id
    redirect "/admin"
  else
    redirect "/admin/login?error=1"
  end
end

get '/admin/services/del/:id' do
  req_admin
  Service.find(params[:id]).destroy
  redirect "/admin"
end

post '/admin/services' do
  req_admin
  Service.create(params[:service])
  redirect "/admin"
end

get '/admin/appointments/up/:id/:status' do
  req_admin
  Appointment.find(params[:id]).update(status: params[:status])
  redirect "/admin"
end

get '/admin/logout' do
  session[:uid] = nil
  redirect "/admin/login"
end

LOGIN_HTML = <<~HTML
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CarePulse Admin Login</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
    <style>
      :root { --primary: #0f4c81; --primary-l: #1a65a8; --bg: #f4f8fb; }
      body {
        font-family: 'Inter', sans-serif; margin: 0; padding: 0;
        background: linear-gradient(135deg, #0c3e6e 0%, #0f4c81 100%);
        display: flex; align-items: center; justify-content: center; height: 100vh;
      }
      .card {
        background: rgba(255, 255, 255, 0.95); padding: 3rem; border-radius: 20px;
        box-shadow: 0 10px 40px rgba(0,0,0,0.3); width: 100%; max-width: 400px;
        text-align: center; backdrop-filter: blur(10px);
      }
      h2 { color: var(--primary); font-weight: 800; margin-bottom: 2rem; }
      input {
        width: 100%; padding: 1rem; margin-bottom: 1.5rem;
        border: 1.5px solid #e2e8f0; border-radius: 10px; font-size: 1rem;
        box-sizing: border-box; transition: all 0.2s;
      }
      input:focus { outline: none; border-color: var(--primary-l); box-shadow: 0 0 0 3px rgba(15,76,129,0.1); }
      button {
        width: 100%; padding: 1rem; background: var(--primary); color: white;
        border: none; border-radius: 10px; font-size: 1.1rem; font-weight: 700;
        cursor: pointer; transition: all 0.2s;
      }
      button:hover { background: var(--primary-l); transform: translateY(-2px); box-shadow: 0 4px 12px rgba(15,76,129,0.3); }
      .back { margin-top: 1.5rem; display: block; color: var(--primary); text-decoration: none; font-size: 0.9rem; font-weight: 600; }
      .err { color: #dc2626; font-size: 0.85rem; margin-bottom: 1rem; }
    </style>
  </head>
  <body>
    <div class="card">
      <div style="font-size: 3rem; margin-bottom: 1rem;">🏥</div>
      <h2>CarePulse Admin</h2>
      <% if params[:error] %><div class="err">❌ Invalid credentials. Try again.</div><% end %>
      <form action="/admin/login" method="post">
        <input type="email" name="email" placeholder="Email" required autofocus>
        <input type="password" name="password" placeholder="Password" required>
        <button type="submit">Login to Dashboard</button>
      </form>
      <a href="/" class="back">← Back to Website</a>
    </div>
  </body>
  </html>
HTML

DASH_HTML = <<~HTML
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CarePulse Admin Dashboard</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
    <style>
      :root { --primary: #0f4c81; --green: #22c55e; --bg: #f4f8fb; --text: #1e293b; --muted: #64748b; }
      body { font-family: 'Inter', sans-serif; background: var(--bg); color: var(--text); margin: 0; }
      header {
        background: white; padding: 1rem 2rem; border-bottom: 1px solid #e2e8f0;
        display: flex; justify-content: space-between; align-items: center;
        position: sticky; top: 0; z-index: 10;
      }
      .logo { font-size: 1.2rem; font-weight: 800; color: var(--primary); }
      .logout { color: #dc2626; text-decoration: none; font-weight: 600; font-size: 0.9rem; }
      .container { max-width: 1200px; margin: 2rem auto; padding: 0 2rem; }
      .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1.5rem; margin-bottom: 3rem; }
      .stat-card {
        background: white; padding: 1.5rem; border-radius: 16px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.05); text-align: center;
      }
      .stat-card h3 { font-size: 0.9rem; color: var(--muted); margin: 0; text-transform: uppercase; letter-spacing: 0.05em; }
      .stat-card p { font-size: 2rem; font-weight: 800; color: var(--primary); margin: 0.5rem 0 0; }
      section { background: white; padding: 2rem; border-radius: 16px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); margin-bottom: 2rem; }
      h2 { color: var(--primary); margin-top: 0; }
      table { width: 100%; border-collapse: collapse; margin-top: 1rem; }
      th, td { text-align: left; padding: 1rem; border-bottom: 1px solid #e2e8f0; }
      th { font-size: 0.85rem; color: var(--muted); background: #f8fafc; }
      .status { padding: 0.25rem 0.75rem; border-radius: 99px; font-size: 0.75rem; font-weight: 600; }
      .status-pending { background: #fefce8; color: #854d0e; }
      .btn { padding: 0.4rem 0.8rem; border-radius: 6px; font-size: 0.8rem; text-decoration: none; font-weight: 600; transition: 0.2s; display: inline-block; }
      .btn-del { color: #dc2626; background: #fee2e2; }
      .btn-del:hover { background: #fecaca; }
      .btn-pub { color: white; background: var(--green); }
      .form-add { display: flex; gap: 1rem; margin-bottom: 2rem; }
      .form-add input { padding: 0.6rem; border: 1px solid #e2e8f0; border-radius: 8px; flex: 1; }
      .form-add button { padding: 0.6rem 1.2rem; background: var(--primary); color: white; border: none; border-radius: 8px; cursor: pointer; }
    </style>
  </head>
  <body>
    <header>
      <div class="logo">CarePulse 🏥</div>
      <a href="/admin/logout" class="logout">Logout</a>
    </header>
    <div class="container">
      <div class="stats">
        <div class="stat-card"><h3>Total Services</h3><p><%= @services.count %></p></div>
        <div class="stat-card"><h3>Appointments</h3><p><%= @appts.count %></p></div>
        <div class="stat-card"><h3>Feedbacks</h3><p><%= @fbs.count %></p></div>
      </div>

      <section>
        <h2>Services</h2>
        <form action="/admin/services" method="post" class="form-add">
          <input type="text" name="service[title]" placeholder="Service Name (e.g. Cardiology)" required>
          <input type="text" name="service[icon]" placeholder="Icon (emoji)" required>
          <button type="submit">+ Add Service</button>
        </form>
        <table>
          <thead><tr><th>Icon</th><th>Title</th><th>Actions</th></tr></thead>
          <tbody><% @services.each do |s| %><tr><td><%= s.icon %></td><td><%= s.title %></td><td><a href="/admin/services/del/<%= s.id %>" class="btn btn-del" onclick="return confirm('Are you sure?')">Delete</a></td></tr><% end %></tbody>
        </table>
      </section>

      <section>
        <h2>Appointments</h2>
        <table>
          <thead><tr><th>Patient</th><th>Email</th><th>Service</th><th>Date</th><th>Status</th><th>Actions</th></tr></thead>
          <tbody><% @appts.order(created_at: :desc).each do |a| %><tr>
            <td><%= a.name %></td>
            <td><%= a.email %></td>
            <td><%= a.service&.title || 'N/A' %></td>
            <td><%= a.date.strftime("%b %d, %H:%M") %></td>
            <td><span class="status status-<%= a.status %>"><%= a.status.upcase %></span></td>
            <td>
              <% if a.status == 'pending' %><a href="/admin/appointments/up/<%= a.id %>/confirmed" class="btn btn-pub">Confirm</a><% end %>
            </td>
          </tr><% end %></tbody>
        </table>
      </section>
    </div>
  </body>
  </html>
HTML

# 🚀 Start the Application Engine
Sinatra::Application.run!
