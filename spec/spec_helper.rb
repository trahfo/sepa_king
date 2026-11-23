# frozen_string_literal: true

require 'simplecov'

SimpleCov.start do
  enable_coverage :branch
  primary_coverage :line
  add_filter '/spec/'
  minimum_coverage line: 100, branch: 100
  if ENV['CI']
    require 'simplecov-cobertura'
    formatter SimpleCov::Formatter::MultiFormatter.new([
                                                         SimpleCov::Formatter::HTMLFormatter,
                                                         SimpleCov::Formatter::CoberturaFormatter
                                                       ])
  end
end

require 'sepa_king'

Dir[File.expand_path(File.join(__dir__, 'support', '**', '*.rb'))].each { |f| require f }

RSpec.configure do |config|
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
