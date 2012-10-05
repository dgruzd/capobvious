# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "capobvious/version"

Gem::Specification.new do |s|
  s.name        = "capobvious"
  s.version     = Capobvious::VERSION
  s.authors     = ["Dmitry Gruzd"]
  s.email       = ["donotsendhere@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Cap recipes}
  s.description = %q{Capfile that we use every day}

  s.rubyforge_project = "capobvious"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "capistrano"
  s.add_dependency "rvm-capistrano"

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
end
