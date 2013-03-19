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
  _cset :backup_folder_path, "tmp/backup"
  _cset :database_yml_path, 'config/database.yml'
  _cset :auto_migrate, true
  _cset(:ssh) {"ssh -p #{fetch(:port, 22)} #{user}@#{serv}"}

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



  VarGems = {'delayed_job' => :delayed_job, 'activerecord-postgres-hstore' => :hstore, 'sitemap_generator' => :sitemap_generator, 'whenever' => 'whenever', 'turbo-sprockets-rails3' => 'turbo_sprockets_rails3'}

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

  namespace :create do
    desc "Create .rvmrc"
    task :rvmrc do
      run "cd #{latest_release} && rvm use #{exists?(:ruby_version) ? fetch(:ruby_version) : ''} --create --rvmrc"
    end
  end


  after "bundle:install", "auto:run"
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
