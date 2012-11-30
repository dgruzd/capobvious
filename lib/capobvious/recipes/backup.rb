Capistrano::Configuration.instance(:must_exist).load do
  namespace :backup do
    desc "Backup a database"
    task :db do
      file_name = fetch(:db_file_name)
      archive_ext = fetch(:db_archive_ext)
      dump_file_path = "#{shared_path}/backup/#{file_name}"
      output_file = "#{file_name}.#{archive_ext}"
      output_file_path = "#{dump_file_path}.#{archive_ext}"
      require 'yaml'
      run "mkdir -p #{shared_path}/backup"
      if adapter == "postgresql"
        logger.important("Backup database #{database}", "Backup:db")
        run "export PGPASSWORD=\"#{db_password}\" && pg_dump -U #{db_username} #{database} > #{dump_file_path}"
        run "cd #{shared_path}/backup && #{arch_create} #{output_file} #{file_name} && rm #{dump_file_path}"
      else
        puts "Cannot backup, adapter #{adapter} is not implemented for backup yet"
      end
      system "mkdir -p #{local_folder_path}"
      download_path = "#{local_folder_path}/#{file_name}.#{archive_ext}"
      logger.important("Downloading database to #{download_path}", "Backup:db")
      download(output_file_path, download_path)
      run "rm -v #{output_file_path}" if fetch(:del_backup)
    end
    desc "Backup public/system folder"
    task :sys do
      file_path = "#{shared_path}/backup/#{sys_file_name}"
      logger.important("Backup shared/system folder", "Backup:sys")
      run "#{arch_create} #{file_path} -C #{shared_path} system"
      download_path = "#{local_folder_path}/#{sys_file_name}"
      logger.important("Downloading system to #{download_path}", "Backup:db")
      download(file_path, download_path)
      run "rm -v #{file_path}" if fetch(:del_backup)
    end
    task :all do
      backup.db
      backup.sys
    end
    desc "Clean backup folder"
    task :clean do
      run "rm -rfv #{shared_path}/backup/*"
    end
  end
  if exists?(:backup_db) && fetch(:backup_db) == true
    before "deploy:update", "backup:db"
  end
  if exists?(:backup_sys) && fetch(:backup_sys) == true
    before "deploy:update", "backup:sys"
  end
end
