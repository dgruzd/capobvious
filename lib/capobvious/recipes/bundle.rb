Capistrano::Configuration.instance(:must_exist).load do
  after 'deploy:update_code', 'bundle:install'
  namespace :bundle do
    desc "Run bundle install"
    task :install do
      deployment = "--deployment --quiet"
      without = ['development','test','production']-[rails_env]
      run "cd #{latest_release} && bundle install --without #{without.join(" ")}"
    end
  end
end
