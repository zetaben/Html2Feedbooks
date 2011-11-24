# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "html2fb/version"

Gem::Specification.new do |s|
  s.name        = "Html2Feedbooks"
  s.version     = Html2fb::VERSION
  s.authors = ["Benoit Larroque"]
  s.email = ["benoit dot larroque at feedbooks dot com"]
  s.summary = %q{Html2Feedbooks is script to automate basic publishing on feedbooks.com}
  s.homepage = %q{http://github.com/zetaben/Html2Feedbooks}
  s.description = %q{Html2Feedbooks is script to automate basic publishing on feedbooks.com}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.default_executable = 'html2fb.rb'
  s.add_dependency('hpricot', '= 0.8.1')
  s.add_dependency('htmlentities', '>= 4.2.1')
  s.add_dependency('launchy', '>= 2.0.0')
  s.add_dependency('progressbar', '>= 0.0.3')

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
end
