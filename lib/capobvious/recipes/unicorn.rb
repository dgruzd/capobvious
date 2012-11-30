Capistrano::Configuration.instance(:must_exist).load do
  set :unicorn_init, "unicorn_#{fetch(:application)}"
  set :unicorn_conf, "#{current_path}/config/unicorn.rb"
  set :unicorn_pid, "#{shared_path}/pids/unicorn.pid"

  namespace :unicorn do
    desc "init autostart unicorn"
    task :autostart do
      #cd /home/rails/www/three-elements/current && sudo -u rails -H /home/rails/.rvm/bin/193_bundle exec /home/rails/.rvm/bin/193_unicorn -c /home/rails/www/three-elements/current/config/unicorn.rb -E production -D
      join_ruby = ruby_version[/\d.\d.\d/].delete('.')
      ruby_wrapper = "#{join_ruby}_unicorn"
      ruby_wrapper_path = "/home/#{user}/.rvm/bin/#{ruby_wrapper}"
      bundle_wrapper = "#{join_ruby}_bundle"
      bundle_wrapper_path = "/home/#{user}/.rvm/bin/#{bundle_wrapper}"

      run "rvm wrapper #{ruby_version} #{join_ruby} unicorn"
      run "rvm wrapper #{ruby_version} #{join_ruby} bundle"
      #puts "sudo -u #{user} -H /home/#{user}/.rvm/bin/#{wrapper} -c #{unicorn_conf} -E production -D"
      command = "cd #{current_path} && sudo -u #{user} -H #{bundle_wrapper_path} exec #{ruby_wrapper_path} -c #{unicorn_conf} -E production -D"
      puts command

      run "#{sudo} sed -i 's/exit 0//g' /etc/rc.local"
      run "echo \"#{command}\" | #{sudo} tee -a /etc/rc.local"
      run "echo \"exit 0\" | #{sudo} tee -a /etc/rc.local"
    end

    desc "start unicorn"
    task :start do
      if remote_file_exists?(unicorn_pid)
        if remote_process_exists?(unicorn_pid)
          logger.important("Unicorn is already running!", "Unicorn")
          next
        else
          run "rm #{unicorn_pid}"
        end
      end
      logger.important("Starting...", "Unicorn")
      run "cd #{current_path} && bundle exec unicorn -c #{unicorn_conf} -E #{rails_env} -D"
    end
    desc "stop unicorn"
    #task :stop, :roles => :app, :except => {:no_release => true} do
    task :stop do
      if remote_file_exists?(unicorn_pid)
        if remote_process_exists?(unicorn_pid)
          logger.important("Stopping...", "Unicorn")
          run "if [ -f #{unicorn_pid} ] && [ -e /proc/$(cat #{unicorn_pid}) ]; then kill -QUIT `cat #{unicorn_pid}`; fi"
        else
          run "rm #{unicorn_pid}"
          logger.important("Unicorn is not running.", "Unicorn")
        end
      else
        logger.important("No PIDs found. Check if unicorn is running.", "Unicorn")
      end
    end
    desc "restart unicorn"
    task :restart do
      if remote_file_exists?(unicorn_pid)
        logger.important("Stopping...", "Unicorn")
        run "kill -s USR2 `cat #{unicorn_pid}`"
      else
        logger.important("No PIDs found. Starting Unicorn server...", "Unicorn")
        run "cd #{current_path} && bundle exec unicorn -c #{unicorn_conf} -E #{rails_env} -D"
      end
    end

    task :init do
      template = <<EOF
#! /bin/sh
# File: /etc/init.d/<%= unicorn_init %>
### BEGIN INIT INFO
# Provides:          unicorn
# Required-Start:    $local_fs $remote_fs $network $syslog
# Required-Stop:     $local_fs $remote_fs $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts the unicorn web server
# Description:       starts unicorn
### END INIT INFO

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/home/nyaa/.rvm/bin/system_unicorn
DAEMON_OPTS="<%= unicorn_conf %>"
NAME=unicorn_<%= application %>
DESC="Unicorn app for <%= application %>"
PID=<% unicorn_pid %>

case "$1" in
  start)
  echo -n "Starting $DESC: "
  $DAEMON $DAEMON_OPTS
  echo "$NAME."
  ;;
  stop)
  echo -n "Stopping $DESC: "
        kill -QUIT `cat $PID`
  echo "$NAME."
  ;;
  restart)
  echo -n "Restarting $DESC: "
        kill -QUIT `cat $PID`
  sleep 1
  $DAEMON $DAEMON_OPTS
  echo "$NAME."
  ;;
  reload)
        echo -n "Reloading $DESC configuration: "
        kill -HUP `cat $PID`
        echo "$NAME."
        ;;
  *)
  echo "Usage: $NAME {start|stop|restart|reload}" >&2
  exit 1
  ;;
esac

exit 0
EOF
      erb = ERB.new(template)
      init = erb.result(binding)
      file_path = "/etc/init.d/#{unicorn_init}"
      put init, "/tmp/#{unicorn_init}"
      run "#{sudo} mv /tmp/#{unicorn_init} #{file_path} && #{sudo} chmod +x #{file_path}"
    end
    task :init_defaults do
      "#{sudo} /usr/sbin/update-rc.d -f #{unicorn_init} defaults"
    end
    task :init_remove do
      "sudo update-rc.d #{unicorn_init} remove"
    end
  end
end
