Capistrano::Configuration.instance(:must_exist).load do
  after 'deploy:setup', 'logrotate:init'

  _cset :logrotate_path, '/etc/logrotate.d'
  _cset(:logrotate_file_name){ "cap_#{application}_#{rails_env}"}
  _cset(:logrotate_file){ "#{logrotate_path}/#{logrotate_file_name}"}

  namespace :logrotate do
    #http://stackoverflow.com/questions/4883891/ruby-on-rails-production-log-rotation
    task :init do
      str = %|
      #{shared_path}/log/*.log {
    size=32M
    rotate 10
    missingok
    compress
    delaycompress
    notifempty
    copytruncate
}
        |
      temp_path =  "/tmp/#{logrotate_file_name}"
      put str, temp_path
      run "#{sudo} mv -v #{temp_path} #{logrotate_file}"
    end
    task :stop do
      run "#{sudo} rm #{logrotate_file}"
    end
  end
end
