Capistrano::Configuration.instance(:must_exist).load do

  _cset(:nginx_config) { "#{application}-#{rails_env}" }

  after "nginx:conf", "nginx:reload"
  after "nginx:delconf", "nginx:reload"
  namespace :nginx do
    [:stop, :start, :restart, :reload].each do |action|
      desc "#{action.to_s} nginx"
      task action, :roles => :web do
        run "#{sudo} /etc/init.d/nginx #{action.to_s}"
      end
    end

    desc "Add app nginx conf to server"
    task :conf do
      assets_template = <<-EOF
    location ~ ^/(assets)/  {
      root #{current_path}/public;
      gzip_static on; # to serve pre-gzipped version
      expires max;
      add_header Cache-Control public;
    }
      EOF

      default_nginx_template = <<-EOF
    server {
    listen  80;
    server_name  #{server_name};
    root #{current_path}/public;

#    access_log  #{shared_path}/log/nginx.access_log;# buffer=32k;
#    error_log   #{shared_path}/log/nginx.error_log error;

#    location ~ ^/assets/ {
#      expires 1y;
#      add_header Cache-Control public;
#      add_header ETag "";
#      break;
#    }
      #{exists?(:nginx_add)? fetch(:nginx_add) : ""}

      #{(exists?(:assets)&&fetch(:assets)==true)? assets_template : ''}

    location / {
        try_files  $uri @unicorn;
    }
    location @unicorn {
        proxy_set_header  Client-Ip $remote_addr;
        proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header  Host $host;
        proxy_pass  http://unix:#{shared_path}/pids/unicorn.sock;
    }
    }
      EOF
      if exists?(:server_redirect)
        server_redirect = fetch(:server_redirect)#.split(" ")
        redirect_template = <<-RED
        server {
          server_name #{server_redirect};
          rewrite ^(.*)$ http://#{server_name.split(' ').first}$1 permanent;
        }
        RED
        default_nginx_template += redirect_template
      end

      puts default_nginx_template

      if exists?(:server_name)
        #location = fetch(:template_dir, "config") + '/nginx.conf.erb'
        #template = File.file?(location) ? File.read(location) : default_nginx_template
        config = ERB.new(default_nginx_template)
        #  puts config.result
        put config.result(binding), "#{shared_path}/nginx.conf"
        run "#{sudo} ln -sfv #{shared_path}/nginx.conf /etc/nginx/sites-enabled/#{fetch(:nginx_config)}"
      else
        abort "Aborting because :server_name is not setted in deploy.rb"
      end
    end
    desc "Del nginx config"
    task :delconf do
      run "#{sudo} rm -v /etc/nginx/sites-enabled/#{fetch(:nginx_config)}"
    end
  end
end
