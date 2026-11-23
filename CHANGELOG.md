# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.15.0] - 2026-11-23

### Added
- **`pain.008.001.08`** (SEPA Direct Debit, ISO 20022 version 2019) and **`pain.001.001.09`** (SEPA Credit Transfer, ISO 2019), validated against the DK Technical Validation Subsets (GBIC_4). Based on salesking/sepa_king#117 by Tobias Schoknecht. German banks only accept these versions since November 2026.
- `SEPA::Address` with all ISO 20022 `PostalAddress24` elements (`department`, `building_name`, `floor`, `post_box`, `room`, `town_location_name`, `district_name`, `country_sub_division`, …). `SEPA::DebtorAddress` and `SEPA::CreditorAddress` are now subclasses.
- Structured-address rule for the 2019 schemas: an address needs `town_name` and `country_code` and no address lines; otherwise the message is not `schema_compatible?`.
- Postal address of the account holder: `SEPA::DirectDebit.new(..., address: {...})` (creditor) and `SEPA::CreditTransfer.new(..., address: {...})` (debtor).
- Addresses can be given as a Hash wherever an address is accepted.
- `SEPA::Schema` registry: namespace, XSD and capabilities per schema; parsed XSDs are cached instead of being read on every `to_xml`.
- `SEPA::PAIN_008_001_08` and `SEPA::PAIN_001_001_09` constants.

### Changed
- `to_xml` without a schema still uses the 2009 version but emits a deprecation warning (visible with `Warning[:deprecated] = true`); the default switches to the 2019 version in 1.0.
- The 2009 schemas now also write `Dept`, `SubDept` and `CtrySubDvsn` when given. Output for existing callers is byte-for-byte unchanged (golden files).
- XML builders extracted into `SEPA::Builders`; schema differences live in `SEPA::Schema` instead of `if schema_name ==` branches.

### Changed (development and requirements)
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
