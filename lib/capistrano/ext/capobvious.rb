#$:.unshift(File.expand_path('./lib', ENV['rvm_path']))
require "rvm/capistrano"
require 'capobvious/recipes/main'
require 'capobvious/recipes/unicorn'
require 'capobvious/recipes/delayed_job'
require 'capobvious/recipes/sitemap_generator'
require 'capobvious/recipes/assets'
require 'capobvious/recipes/bundle'
require 'capobvious/recipes/db'
require 'capobvious/recipes/backup'
require 'capobvious/recipes/logrotate'
require 'capobvious/recipes/whenever'
require 'capobvious/recipes/rake'
require 'capobvious/recipes/import'
require 'capobvious/recipes/nginx'
require 'capobvious/recipes/log'


