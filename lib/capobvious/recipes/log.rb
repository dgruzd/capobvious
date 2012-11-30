Capistrano::Configuration.instance(:must_exist).load do

  namespace :log do
    desc "tail -f .log"
    task :tail do
      stream("tail -f -n 0 #{current_path}/log/#{fetch(:rails_env)}.log")
    end
  end
end
