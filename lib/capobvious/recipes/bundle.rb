Capistrano::Configuration.instance(:must_exist).load do
  after 'deploy:update_code', 'bundle:install'
  namespace :bundle do
    desc "Run bundle install"
    task :install do
      opts = []
      #opts << "-j#{fetch(:server_cores).to_i}" if fetch(:server_cores).to_i > 1
      deployment = "--deployment --quiet"
      without = ['development','test','production']-[rails_env]
      run "cd #{latest_release} && bundle install #{opts.join(' ')} --without #{without.join(" ")}"
    end
  end
end
