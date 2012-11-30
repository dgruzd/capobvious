Capistrano::Configuration.instance(:must_exist).load do
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
end
