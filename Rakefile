# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop yard_audit rbs]

desc 'Fail unless every public object has YARD documentation'
task :yard_audit do
  output = `bundle exec yard stats --list-undoc 2>&1`
  puts output
  abort 'YARD documentation is incomplete' unless output.include?('100.00% documented')
end

desc 'Validate the RBS signatures in sig/'
task :rbs do
  sh 'bundle exec rbs -r bigdecimal -r date -I sig validate'
end
