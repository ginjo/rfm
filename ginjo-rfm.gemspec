#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-
# This gemspec has been crafted by hand - do not overwrite with Jeweler!
# See http://yehudakatz.com/2010/12/16/clarifying-the-roles-of-the-gemspec-and-gemfile/
# See http://yehudakatz.com/2010/04/02/using-gemspecs-as-intended/
# for more information on bundler and gems.

require 'date'

Gem::Specification.new do |s|
  s.name = "ginjo-rfm"
  s.summary = "Ruby Filemaker adapter"
  s.version = File.read('./lib/rfm/VERSION') #Rfm::VERSION

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1") if s.respond_to? :required_rubygems_version=
  #s.authors = ["Geoff Coffey", "Mufaddal Khumri", "Atsushi Matsuo", "Larry Sprock", "Bill Richardson"]
  s.authors = ["Bill Richardson", "Geoff Coffey", "Mufaddal Khumri", "Atsushi Matsuo", "Larry Sprock"]
  s.date = Date.today.to_s
  s.description = "Rfm is a standalone database adapter for Filemaker server. Ginjo-rfm features multiple xml parser support, ActiveModel integration, field mapping, compound queries, logging, scoping, and a configuration framework."
  s.email = "http://groups.google.com/group/rfmcommunity"
  s.homepage = "https://github.com/ginjo/rfm"
  
  s.require_paths = ["lib"]
  s.files = Dir['lib/**/*.rb', 'lib/**/sax/*', 'lib/**/VERSION',  '.yardopts']
  
  s.rdoc_options = ["--line-numbers", "--main", "README.md"]
  s.extra_rdoc_files = [
    "LICENSE",
    "README.md",
    "CHANGELOG.md",
    "lib/rfm/VERSION"
  ]

  # s.add_runtime_dependency('activesupport', '>= 2.3.5')
  s.add_development_dependency(%q<activemodel>, [">= 0"])
  s.add_development_dependency(%q<rake>, [">= 0"])
  s.add_development_dependency(%q<rdoc>, [">= 0"])
  s.add_development_dependency(%q<rspec>, ["~> 2"])
  s.add_development_dependency(%q<minitest>, [">= 0"])
  s.add_development_dependency(%q<diff-lcs>, [">= 0"])
  s.add_development_dependency(%q<yard>, [">= 0"])
  s.add_development_dependency(%q<redcarpet>, [">= 0"])
  s.add_development_dependency(%q<ruby-prof>, [">= 0"])
  s.add_development_dependency(%q<libxml-ruby>, [">= 0"]) unless RUBY_PLATFORM == 'java'
  s.add_development_dependency(%q<ox>, [">= 0"])
  s.add_development_dependency(%q<nokogiri>, [">= 0"])
  
end # Gem::Specification.new

