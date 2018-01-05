#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-
# This gemspec has been crafted by hand - do not overwrite with Jeweler!
# See http://yehudakatz.com/2010/12/16/clarifying-the-roles-of-the-gemspec-and-gemfile/
# See http://yehudakatz.com/2010/04/02/using-gemspecs-as-intended/
# for more information on bundler and gems.

require 'date'

Gem::Specification.new do |s|
  s.name = "saxchange"
  s.summary = "Ruby Filemaker adapter SAX parser."
  s.version = "0.0.0" #File.read('./lib/rfm/VERSION') #Rfm::VERSION

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1") if s.respond_to? :required_rubygems_version=
  s.authors = ["Bill Richardson"]
  s.date = Date.today.to_s
  s.description = "Flexible declarative SAX parser."
  s.email = "http://groups.google.com/group/rfmcommunity"
  s.homepage = "https://github.com/ginjo/saxchange"
  
  s.require_paths = ["lib"]
  #s.files = Dir['lib/**/*.rb', 'lib/**/handler/*.rb', 'lib/**/VERSION',  '.yardopts']
  s.files = Dir['lib/**/*']
  
  s.rdoc_options = ["--line-numbers", "--main", "README.md"]
  s.extra_rdoc_files = [
    #"LICENSE",
    #"README.md",
    #"lib/rfm/VERSION"
  ]
  
end # Gem::Specification.new

