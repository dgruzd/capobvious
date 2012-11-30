Capistrano::Configuration.instance(:must_exist).load do
  namespace :delayed_job do 
    desc 'Start the delayed_job process'
    task :start, :roles => :app do
      run "cd #{latest_release} && RAILS_ENV=#{rails_env} script/delayed_job start"
    end
    desc "Restart the delayed_job process"
    task :restart, :roles => :app do
      logger.important 'Restarting delayed_job process'
      run "cd #{latest_release}; RAILS_ENV=#{rails_env} script/delayed_job restart"
    end
    desc 'Stop the delayed_job process'
    task :stop, :roles => :app do
      run "cd #{latest_release} && RAILS_ENV=#{rails_env} script/delayed_job stop"
    end
  end
end
