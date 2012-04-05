# -*- encoding : utf-8 -*-
APP_PATH = File.expand_path(File.dirname(File.dirname(__FILE__)))
SHARED_PATH = File.expand_path(APP_PATH+"/../shared")

  working_directory APP_PATH
  
  pid_file   = SHARED_PATH + "/pids/unicorn.pid"
  socket_file= SHARED_PATH + "/pids/unicorn.sock"
  log_file   = APP_PATH + "/log/unicorn.log"
  err_log    = APP_PATH + "/log/unicorn.stderr.log"
  old_pid    = pid_file + '.oldbin'


  timeout 30
  worker_processes 4
  preload_app true
  listen socket_file, :backlog => 1024
  pid pid_file
  stderr_path err_log
  stdout_path log_file

  GC.copy_on_write_friendly = true if GC.respond_to?(:copy_on_write_friendly=)


before_exec do |server|
  ENV["BUNDLE_GEMFILE"] = "#{APP_PATH}/Gemfile"
end

before_fork do |server, worker|
  defined?(ActiveRecord::Base) && ActiveRecord::Base.connection.disconnect!

  if File.exists?(old_pid) && server.pid != old_pid
    begin
      #sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
      Process.kill("QUIT", File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end
end

after_fork do |server, worker|
  defined?(ActiveRecord::Base) && ActiveRecord::Base.establish_connection
end
