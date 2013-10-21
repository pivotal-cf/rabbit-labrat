require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => "spec:all"

task "spec:all" => %w(test:unit test:integration)

desc "Run unit test suite"
RSpec::Core::RakeTask.new("test:unit") do |task|
  task.pattern = "spec/unit/*_spec.rb"
end

desc "Run integration suite"
RSpec::Core::RakeTask.new("test:integration") do |task|
  task.pattern = "spec/integration/*_spec.rb"
end
