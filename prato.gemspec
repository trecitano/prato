# frozen_string_literal: true

require_relative "lib/prato/version"

Gem::Specification.new do |spec|
  spec.name = "prato"
  spec.version = Prato::VERSION
  spec.authors = ["Valter Santos"]
  spec.email = ["valter@trecitano.com"]

  spec.summary = "Filter, sort, and paginate Active Record queries from a table definition."
  spec.description = <<~DESCRIPTION
Prato is a library that simplifies the backend code required to support queryable data, 
by mapping parameters onto a table structure, 
allowing Prato to invoke Active Record methods like  `.where`, `.order`, `.joins`, `.pluck` and others.

The immediate use case for this is fetching data for tables in the frontend, 
and with a simple *Prato* table, it becomes trivial to provide any kind of filtering / sorting / pagination operations 
over an Active Record relation.
  DESCRIPTION
  spec.homepage = "https://prato.trecitano.com/"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.4.0"

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/trecitano/prato",
    "changelog_uri" => "https://github.com/trecitano/prato/releases",
  }

  spec.files = Dir["CHANGELOG.md", "LICENSE.txt", "README.md", "lib/**/*"]
  spec.require_path = "lib"

  spec.add_dependency "activerecord", ">= 5.0"
end
