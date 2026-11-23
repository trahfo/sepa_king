# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- Requires Ruby 3.3 or newer and ActiveModel 7.2 – 8.1 (dropped Ruby < 3.3, ActiveModel < 7.2).
- `bigdecimal` is now an explicit runtime dependency (no longer a default gem in Ruby 3.4+).
- Gem file list no longer depends on `git ls-files`; gemspec metadata (changelog, source, docs, MFA) added.

### Development
- CI on GitHub Actions: Ruby 3.3 / 3.4 / 4.0 × ActiveModel 7.2 / 8.0 / 8.1, plus Ruby head and JRuby (allowed to fail), RuboCop and a strict gem build.
- RuboCop with `rubocop-rspec`, `rubocop-performance` and `rubocop-rake`; `# frozen_string_literal: true` everywhere.
- SimpleCov with 100 % line **and branch** coverage enforced; Coveralls replaced by Codecov (OIDC upload).
- Golden-file regression suite (`spec/golden/`): byte-for-byte XML for 7 scenarios across all compatible schemas.
- Dependabot for Bundler and GitHub Actions.

## [0.14.0] - 2023-12-26

See the [GitHub releases](https://github.com/salesking/sepa_king/releases) for earlier versions.
