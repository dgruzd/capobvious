Capistrano::Configuration.instance(:must_exist).load do
  def database_yml(env = rails_env)
    yml = File.read(fetch(:database_yml_path))
    config = YAML::load(yml)[env.to_s]
    config.keys.each do |key|
      config[(key.to_sym rescue key) || key] = config.delete(key)
    end
    config
  end

  psql = "psql -h localhost"
  psql_postgres = "#{psql} -U postgres"

 #adapter = config[fetch(:rails_env)]["adapter"]
 #set :database, config[fetch(:rails_env)]["database"]
 #db_username = config[fetch(:rails_env)]["username"]
 #db_password = config[fetch(:rails_env)]["password"]

 #local_rails_env = 'development'
 #local_adapter = config[local_rails_env]["adapter"]
 #local_database = config[local_rails_env]["database"]
 #local_db_username = config[local_rails_env]["username"]||`whoami`.chop
 #local_db_password = config[local_rails_env]["password"]

  set :timestamp, Time.new.to_i.to_s
  set :db_archive_ext, "tar.bz2"
  set :arch_extract, "tar -xvjf"
  set :arch_create, "tar -cvjf"

  set :db_file_name, "#{fetch(:application)}-#{timestamp}.sql"
  set :sys_file_name, "#{application}-system-#{timestamp}.#{db_archive_ext}"

  namespace :db do
    task :create do
      yml = database_yml
      if yml[:adapter] == "postgresql"
        run "echo \"create user #{yml[:username]} with password '#{yml[:password]}';\" | #{sudo} -u postgres psql"
        run "echo \"create database #{yml[:database]} owner #{yml[:username]};\" | #{sudo} -u postgres psql"
        run "echo \"CREATE EXTENSION IF NOT EXISTS hstore;\" | #{sudo} -u postgres psql #{yml[:database]}" if exists?(:hstore) && fetch(:hstore)     == true
      else
        puts "Cannot create, adapter #{yml[:adapter]} is not implemented yet"
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
      file_path = "#{backup_folder_path}/#{file_name}"
      system "cd #{backup_folder_path} && #{arch_extract} #{file_name}"
      system "echo \"drop database IF EXISTS #{local_database}\" | #{psql_postgres}"
      system "echo \"create database #{local_database} owner #{local_db_username};\" | #{psql_postgres}"
      #    system "#{psql_postgre} #{local_database} < #{backup_folder_path}/#{db_file_name}"
      puts "ENTER your development password: #{local_db_password}"
      system "#{psql} -U#{local_db_username} #{local_database} < #{backup_folder_path}/#{db_file_name}"
      system "rm #{backup_folder_path}/#{db_file_name}"
    end
    task :pg_import do
      backup.db
      db.import
    end
  end
end
