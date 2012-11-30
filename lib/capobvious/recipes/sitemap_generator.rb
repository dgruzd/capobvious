Capistrano::Configuration.instance(:must_exist).load do
  namespace :sitemap_generator do
    desc 'Start rack refresh sitemap project'
    task :refresh do
      run "cd #{latest_release} && bundle exec rake RAILS_ENV=#{rails_env} sitemap:refresh"
    end
  end
end

