# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.17.0] - 2026-11-24

### Added
- **EPC character set conversion** (EPC217-08, cf. salesking/sepa_king#105 / #92): accented and special letters are transliterated (é → e, Ø → O, Æ → AE) instead of dropped. `SEPA::Text.convert`, `SEPA::Text.truncate` (never splits a character).
- `SEPA.configure`: `charset` (`:dk_extended` default, `:epc_basic`) and `strict_charset` (raise `SEPA::CharacterError` instead of dropping characters).
- `Message#validate!` (raises `SEPA::ValidationError` with `#errors`), `Message#batches_summary`, `Message#to_h` / `Transaction#to_h`.
- `to_xml(..., pretty: false)` for compact XML and `validate: false` to skip the XSD check (benchmarks only).
- German translations of the gem's own validation messages (`lib/sepa_king/locale/de.yml`).
- RBS signatures for the public API in `sig/`; 100 % YARD documentation, both enforced in CI.
- README rewritten: supported messages, quick start, recipes, errors, upgrading, FAQ, credits.

### Changed
- Text fields: letters outside the allowed set are transliterated instead of removed (`José` → `Jose`, was `Jos`). Everything else, including the XML of all golden scenarios, is unchanged.

## [0.16.0] - 2026-11-24

### Added
- **Schema profiles** for the 2019 versions: `:dk` (default, DK GBIC_4 subset, structured addresses) and `:epc` (generic ISO 20022 XSD from iso20022.org plus EPC rules in Ruby: hybrid addresses, UETR, non-SEPA credit transfers). `to_xml(schema, profile:)`, `schema_compatible?(schema, profile:)`, `SEPA::Schema.profiles`.
- **Hybrid addresses** (town + country + up to two address lines) in the `:epc` profile.
- **Non-EEA SEPA rule**: debtor (SDD) / creditor (SCT) address mandatory for counterparties in `SEPA::NON_EEA_SEPA_COUNTRIES` (2019 schemas).
- **Initiating party** different from the account holder (`initiating_party:`), **ultimate debtor / creditor** per transaction, all with `SEPA::Party` and `SEPA::PartyIdentification` (BIC, LEI, other id with scheme and issuer; organisations and private persons).
- **Structured creditor reference** (ISO 11649): `creditor_reference:` → `<Strd><CdtrRefInf>` with `SCOR`; `SEPA::CreditorReference.valid?` / `.generate`.
- **Purpose code** (`purpose_code:`) for SDD and SCT, **category purpose** for SDD.
- **SEPA Instant**: `local_instrument: 'INST'`, requested execution date with time (`<DtTm>`) in pain.001.001.09.
- **UETR** (`uetr:`) for credit transfers (`:epc` profile), **instruction priority** and **charge bearer** for credit transfers.
- **Debtor account per credit transfer transaction** (`debtor_account:`), cf. salesking/sepa_king#113.
- **Original mandate id** (`original_mandate_id:`) for mandate amendments.
- Validators: `SEPA::LEIValidator`, `SEPA::CreditorReferenceValidator`, `SEPA::UETRValidator`.
- `require 'sepa_king'` now defines `SEPA::VERSION`.

### Changed
- `COR1` prints a deprecation warning (obsolete since 2017, rejected by the 2019 schemas).
- Addresses, parties and their identifications are validated when a transaction is added; `country_code` stays optional for the 2009 schemas.
- Mandate amendment details are written in schema order (`OrgnlMndtId`, `OrgnlCdtrSchmeId`, then debtor account/agent); combining creditor and debtor amendments used to fail the XSD.
- Output for existing callers is byte-for-byte unchanged (golden files).

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
