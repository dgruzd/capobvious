Capistrano::Configuration.instance(:must_exist).load do

  namespace :import do
    task :sys, :role => :web do
      find_servers_for_task(current_task).each do |current_server|
        if which('rsync') && local_which('rsync')
          logger.important('Importing with rsync', 'import:sys')
          system "rsync -avz --rsh='ssh -p#{current_server.port}' #{user}@#{current_server.host}:#{shared_path}/system public/"
        else
          backup.sys
          system "cd public && #{arch_extract} ../#{local_folder_path}/#{sys_file_name}"
        end
        break
      end
    end
  end
end
