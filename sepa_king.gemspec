# frozen_string_literal: true

require_relative 'lib/sepa_king/version'

Gem::Specification.new do |s|
  s.name          = 'sepa_king'
  s.version       = SEPA::VERSION
  s.authors       = ['Georg Leciejewski', 'Georg Ledermann']
  s.email         = ['gl@salesking.eu', 'georg@ledermann.dev']
  s.summary       = 'Ruby gem for creating SEPA XML files (ISO 20022 pain.001 / pain.008)'
  s.description   = 'Builds and validates SEPA Credit Transfer (pain.001) and Direct Debit (pain.008) ' \
                    'initiation messages according to ISO 20022, the EPC rulebooks and the DK specifications.'
  s.homepage      = 'https://github.com/salesking/sepa_king'
  s.license       = 'MIT'

  s.metadata = {
    'source_code_uri' => s.homepage,
    'changelog_uri' => "#{s.homepage}/blob/master/CHANGELOG.md",
    'bug_tracker_uri' => "#{s.homepage}/issues",
    'documentation_uri' => "https://www.rubydoc.info/gems/sepa_king/#{s.version}",
    'rubygems_mfa_required' => 'true'
  }

  # Git-independent so the gem also builds from a source tarball.
  s.files = Dir['lib/**/*.{rb,xsd}', 'README.md', 'CHANGELOG.md', 'LICENSE.txt']
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 3.3'

  s.add_dependency 'activemodel', '>= 7.2', '< 9'
  s.add_dependency 'bigdecimal', '>= 3.1', '< 5'
  s.add_dependency 'iban-tools', '~> 1.2'
  s.add_dependency 'nokogiri', '>= 1.16', '< 2'
end
