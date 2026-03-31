# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |test_task|
  test_task.libs << "test"
  test_task.pattern = "test/**/test_*.rb"
end

begin
  require "rubocop/rake_task"

  RuboCop::RakeTask.new
  task default: %i[test rubocop]
rescue LoadError
  task default: :test
end
