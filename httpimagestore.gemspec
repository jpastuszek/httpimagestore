# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "httpimagestore"
  s.version = "0.0.8"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jakub Pastuszek"]
  s.date = "2011-12-01"
  s.description = "Thumbnails images using httpthumbnailer and stored data on HTTP server (S3)"
  s.email = "jpastuszek@gmail.com"
  s.executables = ["httpimagestore"]
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]
  s.files = [
    ".document",
    ".rspec",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "bin/httpimagestore",
    "features/httpimagestore.feature",
    "features/step_definitions/httpimagestore_steps.rb",
    "features/support/env.rb",
    "features/support/test-large.jpg",
    "features/support/test.jpg",
    "features/support/test.txt",
    "httpimagestore.gemspec",
    "lib/httpimagestore/configuration.rb",
    "lib/httpimagestore/pathname.rb",
    "lib/httpimagestore/thumbnail_class.rb",
    "spec/configuration_spec.rb",
    "spec/pathname_spec.rb",
    "spec/spec_helper.rb",
    "spec/test.cfg"
  ]
  s.homepage = "http://github.com/jpastuszek/httpimagestore"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.10"
  s.summary = "HTTP based image storage and thumbnailer"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<sinatra>, [">= 1.2.6"])
      s.add_runtime_dependency(%q<mongrel>, [">= 1.1.5"])
      s.add_runtime_dependency(%q<s3>, ["~> 0.3"])
      s.add_runtime_dependency(%q<httpthumbnailer-client>, ["~> 0.0.3"])
      s.add_runtime_dependency(%q<ruby-ip>, ["~> 0.9"])
      s.add_runtime_dependency(%q<cli>, ["~> 0.0.3"])
      s.add_development_dependency(%q<rspec>, ["~> 2.3.0"])
      s.add_development_dependency(%q<cucumber>, [">= 0"])
      s.add_development_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.6.4"])
      s.add_development_dependency(%q<rcov>, [">= 0"])
      s.add_development_dependency(%q<rdoc>, ["~> 3.9"])
      s.add_development_dependency(%q<daemon>, ["~> 1"])
      s.add_development_dependency(%q<httpthumbnailer>, ["~> 0.0.8"])
      s.add_development_dependency(%q<prawn>, ["= 0.8.4"])
    else
      s.add_dependency(%q<sinatra>, [">= 1.2.6"])
      s.add_dependency(%q<mongrel>, [">= 1.1.5"])
      s.add_dependency(%q<s3>, ["~> 0.3"])
      s.add_dependency(%q<httpthumbnailer-client>, ["~> 0.0.3"])
      s.add_dependency(%q<ruby-ip>, ["~> 0.9"])
      s.add_dependency(%q<cli>, ["~> 0.0.3"])
      s.add_dependency(%q<rspec>, ["~> 2.3.0"])
      s.add_dependency(%q<cucumber>, [">= 0"])
      s.add_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_dependency(%q<jeweler>, ["~> 1.6.4"])
      s.add_dependency(%q<rcov>, [">= 0"])
      s.add_dependency(%q<rdoc>, ["~> 3.9"])
      s.add_dependency(%q<daemon>, ["~> 1"])
      s.add_dependency(%q<httpthumbnailer>, ["~> 0.0.8"])
      s.add_dependency(%q<prawn>, ["= 0.8.4"])
    end
  else
    s.add_dependency(%q<sinatra>, [">= 1.2.6"])
    s.add_dependency(%q<mongrel>, [">= 1.1.5"])
    s.add_dependency(%q<s3>, ["~> 0.3"])
    s.add_dependency(%q<httpthumbnailer-client>, ["~> 0.0.3"])
    s.add_dependency(%q<ruby-ip>, ["~> 0.9"])
    s.add_dependency(%q<cli>, ["~> 0.0.3"])
    s.add_dependency(%q<rspec>, ["~> 2.3.0"])
    s.add_dependency(%q<cucumber>, [">= 0"])
    s.add_dependency(%q<bundler>, ["~> 1.0.0"])
    s.add_dependency(%q<jeweler>, ["~> 1.6.4"])
    s.add_dependency(%q<rcov>, [">= 0"])
    s.add_dependency(%q<rdoc>, ["~> 3.9"])
    s.add_dependency(%q<daemon>, ["~> 1"])
    s.add_dependency(%q<httpthumbnailer>, ["~> 0.0.8"])
    s.add_dependency(%q<prawn>, ["= 0.8.4"])
  end
end

