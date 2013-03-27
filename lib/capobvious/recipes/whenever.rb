Capistrano::Configuration.instance(:must_exist).load do
  if exists?(:whenever) && fetch(:whenever) == true
    set :whenever_command, "bundle exec whenever"
    set :whenever_environment, defer { stage }
    set :whenever_identifier, defer { "#{application}_#{stage}" }
    require "whenever/capistrano/recipes"
    after "bundle:install", "whenever:update_crontab"
    after "deploy:rollback", "whenever:update_crontab"
  end
end
