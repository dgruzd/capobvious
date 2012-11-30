Capistrano::Configuration.instance(:must_exist).load do
  psql = "psql -h localhost"
  psql_postgres = "#{psql} -U postgres"

  database_yml_path = "config/database.yml"

  serv_path = "#{current_path}/#{database_yml_path}"
  #if capture("if [ -f #{serv_path} ]; then echo '1'; fi") == '1'
  #  database_yml = capture("cat #{serv_path}")
  #else
  database_yml = File.open(database_yml_path) rescue nil
  #end
  if database_yml
    config = YAML::load(database_yml)
    adapter = config[rails_env]["adapter"]
    database = config[rails_env]["database"]
    db_username = config[rails_env]["username"]
    db_password = config[rails_env]["password"]

    local_rails_env = 'development'
    local_adapter = config[local_rails_env]["adapter"]
    local_database = config[local_rails_env]["database"]
    local_db_username = config[local_rails_env]["username"]||`whoami`.chop
    local_db_password = config[local_rails_env]["password"]
  end

  set :local_folder_path, "tmp/backup"
  set :timestamp, Time.new.to_i.to_s
  set :db_archive_ext, "tar.bz2"
  set :arch_extract, "tar -xvjf"
  set :arch_create, "tar -cvjf"

  set :db_file_name, "#{database}-#{timestamp}.sql"
  set :sys_file_name, "#{application}-system-#{timestamp}.#{db_archive_ext}"

  namespace :db do
    task :create do
      if adapter == "postgresql"
        run "echo \"create user #{db_username} with password '#{db_password}';\" | #{sudo} -u postgres psql"
        run "echo \"create database #{database} owner #{db_username};\" | #{sudo} -u postgres psql"
        run "echo \"CREATE EXTENSION IF NOT EXISTS hstore;\" | #{sudo} -u postgres psql #{database}" if exists?(:hstore) && fetch(:hstore)     == true
      else
        puts "Cannot create, adapter #{adapter} is not implemented yet"
      end
    end

    [:seed, :migrate].each do |t|
      task t do
        run "cd #{latest_release} && bundle exec rake RAILS_ENV=#{rails_env} db:#{t}"
      end
    end

    task :reset do
      run "cd #{latest_release} && bundle exec rake RAILS_ENV=#{rails_env} db:reset"
    end

    task :import do
      file_name = "#{db_file_name}.#{db_archive_ext}"
      file_path = "#{local_folder_path}/#{file_name}"
      system "cd #{local_folder_path} && #{arch_extract} #{file_name}"
      system "echo \"drop database IF EXISTS #{local_database}\" | #{psql_postgres}"
      system "echo \"create database #{local_database} owner #{local_db_username};\" | #{psql_postgres}"
      #    system "#{psql_postgre} #{local_database} < #{local_folder_path}/#{db_file_name}"
      puts "ENTER your development password: #{local_db_password}"
      system "#{psql} -U#{local_db_username} #{local_database} < #{local_folder_path}/#{db_file_name}"
      system "rm #{local_folder_path}/#{db_file_name}"
    end
    task :pg_import do
      backup.db
      db.import
    end
  end
end
