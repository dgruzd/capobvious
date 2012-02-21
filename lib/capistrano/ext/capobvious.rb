$:.unshift(File.expand_path('./lib', ENV['rvm_path']))
require "rvm/capistrano"

Capistrano::Configuration.instance.load do
rvmrc = "rvm use #{rvm_ruby_string}"
set :rvm_type, :user

default_run_options[:pty] = true
ssh_options[:forward_agent] = true

unless exists?(:rails_env)
  set :rails_env, "production"
end
unless exists?(:dbconf)
  set :dbconf, "database.yml"
end

config = YAML::load(File.open("config/#{dbconf}"))
adapter = config[rails_env]["adapter"]
database = config[rails_env]["database"]
db_username = config[rails_env]["username"]
db_password = config[rails_env]["password"]

set :local_folder_path, "tmp/backup"
set :timestamp, Time.new.to_i.to_s
set :db_file_name, "#{database}-#{timestamp}.sql"
set :db_archive_ext, "7z"


after "deploy:symlink", "auto:run"
after "deploy:setup", "db:create", "nginx:conf"
namespace :auto do
  task :run do
    if exists?(:assets) && fetch(:assets) == true
      assets.precompile
    end
    create.files
    if exists?(:sphinx) && fetch(:sphinx) == true
      sphinx.symlink
    end
    bundle.install
    if exists?(:auto_migrate) && fetch(:auto_migrate) == true
      deploy.migrate
    end
  end
end
namespace :create do
  task :files do
    create.rvmrc
    if fetch(:dbconf) != 'database.yml'
      create.database_yml
    end
  end
  task :database_yml do
    run "ln -sfv #{current_path}/config/#{dbconf} #{current_path}/config/database.yml"
  end
  desc "Create .rvmrc & files"
  task :rvmrc do
    put rvmrc, "#{current_path}/.rvmrc"
  end
end


namespace :db do
  task :create do
    run "echo \"create user #{db_username} with password '#{db_password}';\" | #{sudo} -u postgres psql"
    run "echo \"create database #{database} owner #{db_username};\" | #{sudo} -u postgres psql"
  end
  task :seed do
    run "cd #{current_path} && bundle exec rake RAILS_ENV=#{rails_env} db:seed"
  end
  task :reset do
    run "cd #{current_path} && bundle exec rake RAILS_ENV=#{rails_env} db:reset"
  end
  task :import do
    file_name = "#{db_file_name}.#{db_archive_ext}"
    file_path = "#{local_folder_path}/#{file_name}"
    system "cd #{local_folder_path} && 7z x #{file_name}" 
    system "echo \"drop database #{database}\" | sudo -u postgres psql"
    system "echo \"create database #{database} owner #{db_username};\" | sudo -u postgres psql"
    system "sudo -u postgres psql #{database} < #{local_folder_path}/#{db_file_name}"
    system "rm -v #{local_folder_path}/#{db_file_name}"
  end
  task :pg_import do
    backup.db
    db.import
  end
end

# PRIKHA-TASK
desc "Run custom task usage: cap rake TASK=patch:project_category"
task :rake do
  if ENV.has_key?('TASK')
  p "running rake task: #{ENV['TASK']}"
    run "cd #{current_path} && bundle exec rake RAILS_ENV=#{rails_env} #{ENV['TASK']}"
  else
    puts 'Please specify correct task: cap rake TASK= some_task'
  end
end

namespace :backup do
  desc "Backup a database"
  task :db do
    file_name = fetch(:db_file_name)
    archive_ext = fetch(:db_archive_ext)
    dump_file_path = "#{shared_path}/backup/#{file_name}"
    output_file = "#{dump_file_path}.#{archive_ext}"
    require 'yaml'
    run "mkdir -p #{shared_path}/backup"
    if adapter == "postgresql"
      run "pg_dump -U #{db_username} #{database} > #{dump_file_path}"
      run "cd #{shared_path} && 7z a #{output_file} #{dump_file_path} && rm #{dump_file_path}"
    else
      puts "Cannot backup, adapter #{adapter} is not implemented for backup yet"
    end
    system "mkdir -p #{local_folder_path}"
    download(output_file, "#{local_folder_path}/#{file_name}.#{archive_ext}")
  end
  desc "Backup public/system folder"
  task :sys do
    file_name = "#{application}-system-#{timestamp}.7z"
    file_path = "#{shared_path}/backup/#{file_name}"
    run "7z a #{file_path} #{shared_path}/system"
    download(file_path, "#{local_folder_path}/#{file_name}")
  end
  desc "Clean backup folder"
  task :clean do
    run "rm -rfv #{shared_path}/backup/*"
  end
end
if exists?(:backup_db) && fetch(:backup_db) == true
  before "deploy:update", "backup:db"
end
if exists?(:backup_sys) && fetch(:backup_sys) == true
  before "deploy:update", "backup:sys"
end

namespace :assets do
  desc "Assets precompile"
  task :precompile do
    system("bundle exec rake assets:precompile && cd public && tar czf assets.tar.gz assets/")
    upload("public/assets.tar.gz","#{current_path}/public/assets.tar.gz")
    system("rm public/assets.tar.gz && rm -rf tmp/assets && mv public/assets tmp/assets")
    run("cd #{current_path}/public && rm -rf assets/ && tar xzf assets.tar.gz && rm assets.tar.gz")
  end
end

namespace :nginx do
  task :restart do
    run "#{sudo} /etc/init.d/nginx restart"
  end
  task :reload do
    run "#{sudo} /etc/init.d/nginx reload"
  end
  task :start do
    run "#{sudo} /etc/init.d/nginx start"
  end
  task :stop do
    run "#{sudo} /etc/init.d/nginx stop"
  end
  desc "Add app nginx conf to server"
  task :conf do
  default_nginx_template = <<-EOF
    server {
    listen  80;
    server_name  #{server_name};
    root #{current_path}/public;
    location / {
        try_files  $uri @unicorn;
    }
    location @unicorn {
        proxy_set_header  Client-Ip $remote_addr;
        proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header  Host $host;
        proxy_pass  http://unix:#{shared_path}/pids/unicorn.sock;
    }
    }
    EOF
    if exists?(:server_redirect)
      server_redirect = fetch(:server_redirect)#.split(" ")
      redirect_template = <<-RED
        server {
          server_name #{server_redirect};
          rewrite ^(.*)$ http://#{server_name}$1 permanent;
        }
      RED
      default_nginx_template += redirect_template
    end

puts default_nginx_template

    if exists?(:server_name)
      #location = fetch(:template_dir, "config") + '/nginx.conf.erb'
      #template = File.file?(location) ? File.read(location) : default_nginx_template
      config = ERB.new(default_nginx_template)
      #  puts config.result
      put config.result(binding), "#{shared_path}/nginx.conf"
      run "#{sudo} ln -sfv #{shared_path}/nginx.conf /etc/nginx/sites-enabled/#{application}"
    else
      puts "Aborting because :server_name is not setted in deploy.rb"
    end
  end
  desc "Del nginx config"
  task :delconf do
    run "#{sudo} rm -v /etc/nginx/sites-enabled/#{application}"
  end
end
after "nginx:conf", "nginx:reload"
after "nginx:delconf", "nginx:reload"


namespace :bundle do
  desc "Run bundle install"
  task :install do
    without = ['development','test','production']-[rails_env]
    run "cd #{current_path} && bundle install --without #{without.join(" ")}"
  end
end

namespace :log do
  desc "tail -f production.log"
  task :tail do
    stream("tail -f -n 0 #{current_path}/log/production.log")
  end
end




namespace :install do
  desc "Install apt-nyaa"
  task :aptnyaa do
    run "#{sudo} apt-get --assume-yes install wget > /dev/null 2>&1 && cd /usr/bin/ && #{sudo} wget -Nq https://raw.github.com/nyaa/UbuntuScript/master/apt-nyaa && #{sudo} chmod +x apt-nyaa"
  end
end


namespace :sphinx do
  desc "Rebuild indexes"
  task :rebuild, :roles => :app, :except => {:no_release => true} do
    run "cd #{current_path} && bundle exec rake RAILS_ENV=#{rails_env} ts:rebuild"
  end
  desc "Sphinx start"
  task :start, :roles => :app, :except => {:no_release => true} do
    run "cd #{current_path} && bundle exec rake RAILS_ENV=#{rails_env} ts:start"
  end
  desc "Sphinx stop"
  task :stop, :roles => :app, :except => {:no_release => true} do
    run "cd #{current_path} && bundle exec rake RAILS_ENV=#{rails_env} ts:stop"
  end
  desc "Sphinx configure"
  task :stop, :roles => :app, :except => {:no_release => true} do
    run "cd #{current_path} && bundle exec rake RAILS_ENV=#{rails_env} ts:conf"
  end
  desc "Re-establish symlinks"
  task :symlink do
    if exists?(:sphinx) && fetch(:sphinx) == true
      run "mkdir -pv #{shared_path}/sphinx"
      run "rm -rf #{release_path}/db/sphinx && ln -sfv #{shared_path}/sphinx #{release_path}/db/sphinx"
      run "ln -sfv #{shared_path}/sphinx/#{rails_env}.sphinx.conf #{release_path}/config/#{rails_env}.sphinx.conf"
    else
      puts "sphinx is disabled in config/deploy.rb to enable add line set :sphinx, true"
    end
  end
end



set :unicorn_conf, "#{current_path}/config/unicorn.rb"
set :unicorn_pid, "#{shared_path}/pids/unicorn.pid"
namespace :unicorn do
  desc "start unicorn"
  task :start do
    run "cd #{current_path} && bundle exec unicorn -c #{unicorn_conf} -E #{rails_env} -D"
  end
  desc "stop unicorn"
  #task :stop, :roles => :app, :except => {:no_release => true} do
  task :stop do
    run "if [ -f #{unicorn_pid} ] && [ -e /proc/$(cat #{unicorn_pid}) ]; then kill -QUIT `cat #{unicorn_pid}`; fi"
  end
  desc "restart unicorn"
  task :restart do
    puts "Restarting unicorn"
    unicorn.stop
    unicorn.start
  end
end

namespace :deploy do
  task :restart do
    unicorn.restart
  end
end
end
