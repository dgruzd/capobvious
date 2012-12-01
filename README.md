# Capobvious

capobvious is a recipes, which i use every day

## Installation

Add this line to your application's Gemfile:

    gem 'capobvious'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install capobvious

## Usage

If project don't have capistrano yet, you can run
```sh
capobvious .
```
Inside of you'r project, it create Capfile and config/deploy.rb (you need to configure it)

Or if you have exsisting project with capistrano and you want to use all recipes - just add to the end of Capfile  
```ruby
require 'capistrano/ext/capobvious'
```

## Recipes

### unicorn
```ruby
require 'capobvious/recipes/unicorn'
```
```sh
cap unicorn:start
cap unicorn:stop
cap unicorn:restart
```
### db
```ruby
require 'capobvious/recipes/db'
```
```sh
cap db:create       # Will create user and production database, taken from database.yml
cap db:seed         # rake db:seed
cap db:migrate      # rake db:migrate
cap db:pg_import    # import remote server postgresql database to your development postgresql database
                    # IT WILL DELETE YOUR DEV DATABASE 
```
### rake
```ruby
require 'capobvious/recipes/rake'
```
```sh
cap rake TASK='your:custom:task'
```
### import
```ruby
require 'capobvious/recipes/import'
```
```sh
cap import:sys  # Import shared/system folder from server to you development machine
                # (with rsync works much faster)
```
### backup
```ruby
require 'capobvious/recipes/backup'
```
```sh
cap backup:db   # Backup postgresql server database to local project/tmp/backup folder
cap backup:sys  # Backup shared/system folder to local project/tmp/backup folder
cap backup:all  # Run backup:db backup:sys
```
### bundle
```ruby
require 'capobvious/recipes/bundle'
```
```sh
cap bundle:install  # run automatically on deploy
```

### log
```ruby
require 'capobvious/recipes/log'
```
```sh
cap log:tail    # stream production.log
```

### logrotate
```ruby
require 'capobvious/recipes/logrotate'
```
```sh
cap logrotate:init    # uses logrotate to clean logs automaticly
```


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
