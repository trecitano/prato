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

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/ .rubocop.yml])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 5.0"
end
