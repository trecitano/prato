# frozen_string_literal: true

require_relative "lib/prato/version"

Gem::Specification.new do |spec|
  spec.name = "prato"
  spec.version = Prato::VERSION
  spec.authors = ["Valter Santos"]
  spec.email = ["valter@trecitano.com"]

  spec.summary = "Build queryable tables from Active Record models."
  spec.description = "Prato defines tabular Active Record projections with filtering, sorting, and Ruby-backed columns."
  spec.homepage = "https://github.com/trecitano/prato"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.4.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/releases"

  spec.files = Dir["CHANGELOG.md", "LICENSE.txt", "README.md", "lib/**/*", "sig/**/*"]
  spec.require_path = "lib"

  spec.add_dependency "activerecord", ">= 5.0"
end
