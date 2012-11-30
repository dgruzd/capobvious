#$:.unshift(File.expand_path('./lib', ENV['rvm_path']))
require "rvm/capistrano"
require 'capobvious/recipes/unicorn'
require 'capobvious/recipes/delayed_job'
require 'capobvious/recipes/sitemap_generator'
require 'capobvious/recipes/assets'
require 'capobvious/recipes/bundle'
require 'capobvious/recipes/db'
require 'capobvious/recipes/backup'
require 'capobvious/recipes/logrotate'
require 'capobvious/recipes/whenever'

Capistrano::Configuration.instance(:must_exist).load do
  _cset(:ruby_version) { RUBY_VERSION }
  _cset :rvm_type, :user
  _cset :rails_env, 'production'
  _cset :branch, 'master'
  _cset :deploy_via, :remote_cache
  _cset :keep_releases, 5
  _cset :use_sudo, false
  _cset :scm, :git
  _cset :del_backup, true

  set :rvmrc_string ,"rvm use #{fetch(:ruby_version)}"
  after "deploy:update_code", "create:rvmrc"
  after "deploy:update", "deploy:cleanup"

  #set :deploy_to, (exists?(:deploy_folder)? fetch(:deploy_folder) : "/home/#{user}/www/#{application}")

  default_run_options[:pty] = true
  ssh_options[:forward_agent] = true


  def gem_use?(name)
    gemfile_lock = File.read("Gemfile.lock")
    return (gemfile_lock =~ /^\s*#{name}\s+\(/)? true : false
  end

  def which(name)
    str = capture("which #{name}").chop
    return false if str == ''
    str
  rescue
    false
  end
  def local_which(name)
    str = `which #{name}`.chop
    return false if str == ''
    str
  rescue
    false
  end
  def ssh_port
    exists?(:port) ? fetch(:port) : 22
  end
  def local_gem_available?(name)
    Gem::Specification.find_by_name(name)
  rescue Gem::LoadError
    false
  rescue
    Gem.available?(name)
  end


  def file_size(file_path)
    size = run("wc -c #{file_path} | cut -d' ' -f1")
    return size
  end



  VarGems = {'delayed_job' => :delayed_job, 'activerecord-postgres-hstore' => :hstore, 'sitemap_generator' => :sitemap_generator, 'whenever' => 'whenever'}

  VarGems.each do |gem,var|
    gem = gem.to_s
    var = var.to_sym
    if gem_use?(gem)
      unless exists?(var)
        logger.debug "gem '#{gem}' is found"
        logger.important("#{var} set to true")
        set var, true
      end
    end
  end

  after "deploy:update_code", "create:dbconf"
  namespace :create do
    desc "Create .rvmrc"
    task :rvmrc do
      put rvmrc_string, "#{latest_release}/.rvmrc"
    end
   #task :dbconf do
   #  serv_path = (exists?(:dbconf) && fetch(:dbconf)) || "#{database_yml_path}.server"
   #  if File.exist?(serv_path)
   #    run "cd #{latest_release} && cp -v #{serv_path} #{database_yml_path}"
   #  end
   #end
  end


  after "deploy:update_code", "auto:run"
  namespace :auto do
    task :run do
      if exists?(:auto_migrate) && fetch(:auto_migrate) == true
        db.migrate
      end
      if exists?(:sitemap_generator)  && fetch(:sitemap_generator) == true
        sitemap_generator.refresh
      end
      if exists?(:delayed_job) && fetch(:delayed_job) == true
        delayed_job.restart
      end


    end
    task :prepare do
      db.create
      nginx.conf
    end

    task :runtask do
      path = "#{latest_release}/script/autorun.task"
      if remote_file_exists?(path)
        logger.important "Launching autorun commands"
        cmds = capture("cat #{path}").split("\n").map(&:strip).map{|cmd| "RAILS_ENV=#{rails_env} #{cmd}" }
        puts "cd #{latest_release} && #{cmds.join(' && ')}"
      else
        logger.important "autorun script not found"
      end
    end
  end





  namespace :import do
    task :sys do
      #system "rm -rfv public/system/"
      if which('rsync') && local_which('rsync')
        logger.important('Importing with rsync', 'import:sys')
        system "rsync -avz --rsh='ssh -p#{ssh_port}' #{user}@#{serv}:#{shared_path}/system public/"
      else
        backup.sys
        system "cd public && #{arch_extract} ../#{local_folder_path}/#{sys_file_name}"
      end
    end
  end
  namespace :export do
  end

  namespace :restore do
    task :sys do
      result = {}
      i = 0
      Dir.foreach(local_folder_path) do |d|
        regexp = Regexp.new("\d+?(\.#{archive_ext})")
        if d.include?(sys_file_name.gsub(regexp,""))
          result[i.to_s] = d
          i+=1
        end
      end
      result.each{|key,value| puts "#{key} - #{value} ##{Time.at(value.scan(/\d+/).first.to_i)} #{File.size(local_folder_path+'/'+value)}"}
      puts "WARNING: IT WILL OVERWRITE public/system FOLDER!"
      select = Capistrano::CLI.ui.ask "select : "
      file = result[select]
      unless file.nil?
        puts "You selected #{file}"
        upload("#{local_folder_path}/#{file}","#{shared_path}/#{file}")
        run "rm -rfv #{shared_path}/system/*"
        run "#{arch_extract} #{shared_path}/#{file} -o#{shared_path}"
        run "chmod -R o=rX #{shared_path}/system"
        run "rm -v #{shared_path}/#{file}"
      end
    end
  end

  # PRIKHA-TASK
  desc "Run custom task usage: cap rake TASK=patch:project_category"
  task :rake do
    if ENV.has_key?('TASK')
      logger.important "running rake task: #{ENV['TASK']}"
      run "cd #{current_path} && bundle exec rake RAILS_ENV=#{rails_env} #{ENV['TASK']}"
    else
      puts 'Please specify correct task: cap rake TASK= some_task'
    end
  end



  namespace :nginx do
    [:stop, :start, :restart, :reload].each do |action|
      desc "#{action.to_s} nginx"
      task action, :roles => :web do
        run "#{sudo} /etc/init.d/nginx #{action.to_s}"
      end
    end

    desc "Add app nginx conf to server"
    task :conf do
      default_nginx_template = <<-EOF
    server {
    listen  80;
    server_name  #{server_name};
    root #{current_path}/public;

#    access_log  #{shared_path}/log/nginx.access_log;# buffer=32k;
#    error_log   #{shared_path}/log/nginx.error_log error;

#    location ~ ^/assets/ {
#      expires 1y;
#      add_header Cache-Control public;
#      add_header ETag "";
#      break;
#    }
      #{exists?(:nginx_add)? fetch(:nginx_add) : ""}

    location ~ ^/(assets)/  {
      root #{current_path}/public;
      gzip_static on; # to serve pre-gzipped version
      expires max;
      add_header Cache-Control public;
    }

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
          rewrite ^(.*)$ http://#{server_name.split(' ').first}$1 permanent;
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
    task :p7zip do
      run "#{sudo} apt-get --assume-yes install p7zip-full"
    end
    desc "cap install:shmmax MAX=1024 (MB)"
    task :shmmax do
      if ENV.has_key?('MAX')
        bits = ENV['MAX'].to_i*1024*1024
        puts "setting shmmax to #{bits}"
        run "#{sudo} sysctl -w kernel.shmmax=#{bits}"
        run "echo 'kernel.shmmax=#{bits}' | #{sudo} tee -a /etc/sysctl.conf"
      else
        puts "Please run with MAX="
      end
    end
  end

  after 'deploy:update_code', 'sphinx:symlink' if exists?(:sphinx) && fetch(:sphinx)
  namespace :sphinx do
    desc "Rebuild indexes"
    task :rebuild, :roles => :app, :except => {:no_release => true} do
      run "cd #{latest_release} && bundle exec rake RAILS_ENV=#{rails_env} ts:rebuild"
    end
    desc "Reindex"
    task :reindex, :roles => :app, :except => {:no_release => true} do
      run "cd #{latest_release} && bundle exec rake RAILS_ENV=#{rails_env} ts:reindex"
    end
    desc "Sphinx start"
    task :start, :roles => :app, :except => {:no_release => true} do
      run "cd #{latest_release} && bundle exec rake RAILS_ENV=#{rails_env} ts:start"
    end
    desc "Sphinx stop"
    task :stop, :roles => :app, :except => {:no_release => true} do
      run "cd #{latest_release} && bundle exec rake RAILS_ENV=#{rails_env} ts:stop"
    end
    desc "Sphinx configure"
    task :stop, :roles => :app, :except => {:no_release => true} do
      run "cd #{latest_release} && bundle exec rake RAILS_ENV=#{rails_env} ts:conf"
    end
    desc "Re-establish symlinks"
    task :symlink do
      run "mkdir -pv #{shared_path}/sphinx"
      run "rm -rf #{release_path}/db/sphinx && ln -sfv #{shared_path}/sphinx #{release_path}/db/sphinx"
      run "ln -sfv #{shared_path}/sphinx/#{rails_env}.sphinx.conf #{release_path}/config/#{rails_env}.sphinx.conf"
    end
  end



  namespace :runit do
    [:stop, :start, :restart, :reload].each do |action|
      desc "#{action.to_s} runit"
      task action, :roles => :web do
        run "#{sudo} sv #{action.to_s} #{application}"
      end
    end

    desc "init"
    task :init, :roles => :web do
      join_ruby = ruby_version[/\d.\d.\d/].delete('.')
      local_runit_path = "#{shared_path}/runit_temp"
      runit = "/etc/sv/#{application}"
      runit_path = "/etc/service/#{application}"
      wrapper = "#{join_ruby}_unicorn"
      logger.important('Creating unicorn wrapper', 'runit')
      run "rvm wrapper #{ruby_version} #{join_ruby} unicorn"

      runit_run = <<EOF
#!/bin/sh
exec 2>&1
export USER=#{user}
export HOME=/home/$USER
export RAILS_ENV=#{rails_env}
UNICORN="/home/#{user}/.rvm/bin/#{wrapper}"
UNICORN_CONF=#{unicorn_conf}
cd #{current_path}
exec chpst -u $USER:$USER $UNICORN -c $UNICORN_CONF
EOF
log_run = <<EOF
#!/bin/bash
LOG_FOLDER=/var/log/#{application}
mkdir -p $LOG_FOLDER
exec svlogd -tt $LOG_FOLDER
EOF

logger.important('Creating local runit path', 'runit')
run "mkdir -p #{local_runit_path}/log"
logger.important('Creating run script', 'runit')
put runit_run, "#{local_runit_path}/run"
run "chmod +x #{local_runit_path}/run"
logger.important('Creating log script', 'runit')
put log_run, "#{local_runit_path}/log/run"
run "chmod +x #{local_runit_path}/log/run"

run "#{sudo} mv #{local_runit_path} #{runit} && #{sudo} ln -s #{runit} #{runit_path}"
run "#{sudo} chown -R root:root #{runit}"

#logger.important('Creating symlink', 'runit')
#symlink = "#{sudo} ln -s #{local_runit_path} #{runit_path}"
#run symlink

#puts "$ cat #{runit_path}/run"
#puts run
    end
  end



  # Check if remote file exists
  #
  def remote_file_exists?(full_path)
    'true' ==  capture("if [ -e #{full_path} ]; then echo 'true'; fi").strip
  end

  # Check if process is running
  #
  def remote_process_exists?(pid_file)
    capture("ps -p $(cat #{pid_file}) ; true").strip.split("\n").size == 2
  end


  namespace :deploy do
    task :restart do
      unicorn.restart
    end
  end


end
