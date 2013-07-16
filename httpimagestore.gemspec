# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "httpimagestore"
  s.version = "1.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jakub Pastuszek"]
  s.date = "2013-07-16"
  s.description = "Thumbnails images using httpthumbnailer and stored data on HTTP server (S3)"
  s.email = "jpastuszek@gmail.com"
  s.executables = ["httpimagestore"]
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = [
    ".document",
    ".rspec",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.md",
    "Rakefile",
    "VERSION",
    "bin/httpimagestore",
    "features/cache-control.feature",
    "features/compatibility.feature",
    "features/error-reporting.feature",
    "features/health-check.feature",
    "features/s3-store-and-thumbnail.feature",
    "features/step_definitions/httpimagestore_steps.rb",
    "features/support/env.rb",
    "features/support/test-large.jpg",
    "features/support/test.empty",
    "features/support/test.jpg",
    "features/support/test.txt",
    "httpimagestore.gemspec",
    "lib/httpimagestore/aws_sdk_regions_hack.rb",
    "lib/httpimagestore/configuration.rb",
    "lib/httpimagestore/configuration/file.rb",
    "lib/httpimagestore/configuration/handler.rb",
    "lib/httpimagestore/configuration/output.rb",
    "lib/httpimagestore/configuration/path.rb",
    "lib/httpimagestore/configuration/s3.rb",
    "lib/httpimagestore/configuration/thumbnailer.rb",
    "lib/httpimagestore/error_reporter.rb",
    "lib/httpimagestore/ruby_string_template.rb",
    "load_test/load_test.1k.23a022f6e.m1.small-comp.csv",
    "load_test/load_test.1k.ec9bde794.m1.small.csv",
    "load_test/load_test.jmx",
    "load_test/thumbnail_specs.csv",
    "spec/configuration_file_spec.rb",
    "spec/configuration_handler_spec.rb",
    "spec/configuration_output_spec.rb",
    "spec/configuration_path_spec.rb",
    "spec/configuration_s3_spec.rb",
    "spec/configuration_spec.rb",
    "spec/configuration_thumbnailer_spec.rb",
    "spec/ruby_string_template_spec.rb",
    "spec/spec_helper.rb",
    "spec/support/compute.jpg",
    "spec/support/cuba_response_env.rb",
    "spec/support/full.cfg"
  ]
  s.homepage = "http://github.com/jpastuszek/httpimagestore"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.25"
  s.summary = "HTTP based image storage and thumbnailer"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<unicorn-cuba-base>, ["~> 1.0"])
      s.add_runtime_dependency(%q<httpthumbnailer-client>, ["~> 1.0"])
      s.add_runtime_dependency(%q<aws-sdk>, ["~> 1.10"])
      s.add_runtime_dependency(%q<mime-types>, ["~> 1.17"])
      s.add_runtime_dependency(%q<sdl4r>, ["~> 0.9"])
      s.add_development_dependency(%q<httpclient>, [">= 2.3"])
      s.add_development_dependency(%q<rspec>, ["~> 2.13"])
      s.add_development_dependency(%q<cucumber>, [">= 0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.8.4"])
      s.add_development_dependency(%q<rdoc>, ["~> 3.9"])
      s.add_development_dependency(%q<daemon>, ["~> 1"])
      s.add_development_dependency(%q<prawn>, ["= 0.8.4"])
      s.add_development_dependency(%q<httpthumbnailer>, [">= 0"])
    else
      s.add_dependency(%q<unicorn-cuba-base>, ["~> 1.0"])
      s.add_dependency(%q<httpthumbnailer-client>, ["~> 1.0"])
      s.add_dependency(%q<aws-sdk>, ["~> 1.10"])
      s.add_dependency(%q<mime-types>, ["~> 1.17"])
      s.add_dependency(%q<sdl4r>, ["~> 0.9"])
      s.add_dependency(%q<httpclient>, [">= 2.3"])
      s.add_dependency(%q<rspec>, ["~> 2.13"])
      s.add_dependency(%q<cucumber>, [">= 0"])
      s.add_dependency(%q<jeweler>, ["~> 1.8.4"])
      s.add_dependency(%q<rdoc>, ["~> 3.9"])
      s.add_dependency(%q<daemon>, ["~> 1"])
      s.add_dependency(%q<prawn>, ["= 0.8.4"])
      s.add_dependency(%q<httpthumbnailer>, [">= 0"])
    end
  else
    s.add_dependency(%q<unicorn-cuba-base>, ["~> 1.0"])
    s.add_dependency(%q<httpthumbnailer-client>, ["~> 1.0"])
    s.add_dependency(%q<aws-sdk>, ["~> 1.10"])
    s.add_dependency(%q<mime-types>, ["~> 1.17"])
    s.add_dependency(%q<sdl4r>, ["~> 0.9"])
    s.add_dependency(%q<httpclient>, [">= 2.3"])
    s.add_dependency(%q<rspec>, ["~> 2.13"])
    s.add_dependency(%q<cucumber>, [">= 0"])
    s.add_dependency(%q<jeweler>, ["~> 1.8.4"])
    s.add_dependency(%q<rdoc>, ["~> 3.9"])
    s.add_dependency(%q<daemon>, ["~> 1"])
    s.add_dependency(%q<prawn>, ["= 0.8.4"])
    s.add_dependency(%q<httpthumbnailer>, [">= 0"])
  end
end

