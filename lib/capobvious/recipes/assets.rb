Capistrano::Configuration.instance(:must_exist).load do

  if exists?(:assets) && fetch(:assets) == true
    after 'bundle:install', 'assets:precompile'
    before 'deploy:finalize_update', 'assets:symlink'
  end

  namespace :assets do
    desc "Local Assets precompile"
    task :local_precompile do
      system("bundle exec rake assets:precompile && cd public && tar czf assets.tar.gz assets/")
      upload("public/assets.tar.gz","#{latest_release}/public/assets.tar.gz")
      system("rm public/assets.tar.gz && rm -rf tmp/assets && mv public/assets tmp/assets")
      run("cd #{latest_release}/public && rm -rf assets/ && tar xzf assets.tar.gz && rm assets.tar.gz")
    end
   desc "Assets precompile"
   task :precompile, :roles => :web, :except => { :no_release => true } do
     run("cd #{latest_release} && bundle exec rake RAILS_ENV=#{rails_env} assets:precompile")
   end
   task :symlink, :roles => :web, :except => { :no_release => true } do
     run <<-CMD
       rm -rf #{latest_release}/public/assets &&
       mkdir -p #{latest_release}/public &&
       mkdir -p #{shared_path}/assets &&
       ln -s #{shared_path}/assets #{latest_release}/public/assets
     CMD
   end
  end
end
