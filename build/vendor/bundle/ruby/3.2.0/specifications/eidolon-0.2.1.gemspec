# -*- encoding: utf-8 -*-
# stub: eidolon 0.2.1 ruby lib

Gem::Specification.new do |s|
  s.name = "eidolon".freeze
  s.version = "0.2.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Solistra".freeze]
  s.date = "2014-05-07"
  s.description = "Eidolon is a minimalistic recreation of the RGSSx hidden classes and data structures required to load RPG Maker data directly into pure Ruby.".freeze
  s.email = ["solistra@gmx.com".freeze]
  s.homepage = "https://github.com/sesvxace/eidolon".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Allows for the loading of RGSSx data into pure Ruby.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<yard>.freeze, ["~> 0.8"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 10.3"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 2.14"])
end
