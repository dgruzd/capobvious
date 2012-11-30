Capistrano::Configuration.instance(:must_exist).load do

  namespace :import do
    task :sys do
      #system "rm -rfv public/system/"
      if which('rsync') && local_which('rsync')
        logger.important('Importing with rsync', 'import:sys')
        system "rsync -avz --rsh='ssh -p#{ssh_port}' #{user}@#{serv}:#{shared_path}/system public/"
      else
        backup.sys
        system "cd public && #{arch_extract} ../#{local_folder_path}/#{sys_file_name}"
      end
    end
  end
end
