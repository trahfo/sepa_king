# sepa_king — Roadmap to the next level

> Status: plan, 2026-11-23. Fork: `trahfo/sepa_king` (identical to `salesking/sepa_king` master, last release 0.14.0, Dec 2023).
> Goal: make `sepa_king` the reference Ruby gem for SEPA payment initiation again — current ISO 20022 versions, current Ruby/Rails, first-class tests and docs — then contribute it back upstream.

## Status (2026-11-23)

| Milestone | State |
|---|---|
| M0 Modernise tooling | ✅ merged (trahfo/sepa_king#1) |
| M1 New formats | ✅ released as `v0.15.0` on the fork |
| M2 2019 data model | ✅ released as `v0.16.0` on the fork |
| M3 Text, DX, docs | in progress |
| M4 – M5 | open (after upstream answers #124) |

Deviations from the M1 plan, decided during implementation:
- **Hybrid addresses deferred to M2.** The vendored DK GBIC_4 XSDs (from #117) allow only structured addresses (`TwnNm` + `Ctry`, `AdrLine` forbidden). M1 therefore supports `:structured` (and the 2009 free-text form for old schemas). Hybrid needs a second XSD profile (generic ISO / newer DK TVS), planned as `to_xml(schema, profile:)` in M2.
- **No extra amount bounds.** Every SEPA XSD already caps the amount; a Ruby-side check would only have changed the error class for existing callers.
- **M2:** hybrid addresses are implemented as the `:epc` profile (generic ISO XSD from iso20022.org + EPC rules in Ruby); the DK GBIC_4 subset stays the default `:dk` profile. The DK subset forbids addresses on initiating/ultimate parties and UETR, so those need `:epc`. The non-EEA country list is a constant to keep in sync with the EPC list.
- **Injectable clock / message id** already existed (`creation_date_time=`, `message_identification=`); the golden suite uses them.

---

## 1. Situation

**Why now.** German banks (DFÜ-Abkommen / EBICS, Anlage 3 v3.7+) switched off the 2009 ISO formats (`pain.001.001.03`, `pain.008.001.02`) around **14 Nov 2026**; only the 2019 versions `pain.001.001.09` / `pain.008.001.08` are accepted. In parallel, the EPC rulebooks require that any postal address is **structured or hybrid** (`TwnNm` + `Ctry` mandatory). One secondary source reports that the EPC postponed the address deadline; that hasn't been confirmed. Today `sepa_king` can't produce either the new versions or a compliant hybrid address.

**Upstream state.**
- Unmaintained since Dec 2023. The original author is **looking for a new maintainer** ([#124](https://github.com/salesking/sepa_king/issues/124)).
- Relevant open work we should absorb and credit:

| Upstream | What | Our handling |
|---|---|---|
| [#117](https://github.com/salesking/sepa_king/pull/117) (tobischo / viafintech) | `pain.001.001.09` + `pain.008.001.08` (DK GBIC_4 XSDs, `BICFI`, `ReqdExctnDt/Dt`), Rails 8 matrix | Base for M1; cherry-pick with authorship kept (`Co-authored-by`) |
| [#105](https://github.com/salesking/sepa_king/pull/105) | EPC character conversion table instead of whitelist (fixes [#92](https://github.com/salesking/sepa_king/issues/92)) | M3 |
| [#121](https://github.com/salesking/sepa_king/pull/121) | SCT Inst (`LclInstrm=INST`) | M2 (needs `DtTm` from .09) |
| [#113](https://github.com/salesking/sepa_king/pull/113) | Debtor account per transaction (CT) | M2 |
| [#112](https://github.com/salesking/sepa_king/pull/112) | BBAN credit transfers | M4 (non-SEPA) |
| [#118](https://github.com/salesking/sepa_king/issues/118) / [#120](https://github.com/salesking/sepa_king/pull/120) | Container messages | M4 |
| [#115](https://github.com/salesking/sepa_king/issues/115) | Make ActiveModel optional | M5 (2.0) |
| [#122](https://github.com/salesking/sepa_king/issues/122), [#89](https://github.com/salesking/sepa_king/issues/89), [#51](https://github.com/salesking/sepa_king/issues/51) | XSD root error, multiple batches, structured remittance | M1 / M2 |
| [#125](https://github.com/salesking/sepa_king/pull/125) | Ruby 4 support | M0 |

**Code health today.** About 900 LOC in `lib`. Two strengths: the XSD gate on every `to_xml`, and a well-liked DSL. Weaknesses:
- Schema differences are `case schema_name` / `if schema_name ==` branches spread over `message.rb`, both message classes and both transaction classes.
- `CreditorAddress` and `DebtorAddress` are copy-pasted, and so are the two `PstlAdr` builders.
- The XSD is read and parsed again on every `to_xml`.
- `convert_text` silently deletes characters instead of transliterating them.
- Amounts have no upper bound.
- Some EPC rules are missing (address, charset, non-EEA debtor).
- Coveralls depends on a service that is now unreliable, and there's no linter, no typed signatures and no API docs.

---

## 2. Principles

1. **Never break existing callers in 0.x.** Every public constructor argument, `add_transaction` key, `to_xml(schema)` call and default stays valid. New behaviour is opt-in until 1.0.
2. **The XSD gate stays the last line of defence.** We add Ruby-side rules for things XSDs can't express (EPC/DK usage rules), but never weaken the gate.
3. **One place per schema difference.** A schema is an object with capabilities. Builders ask it questions (`schema.bic_tag`, `schema.supports?(:hybrid_address)`) instead of comparing strings.
4. **Upstream-friendly.** Small, reviewable, self-contained PRs, with authorship of absorbed PRs preserved.
5. **Model the richest version.** Model the 2019 superset: structured addresses, LEI, ultimate parties, structured remittance. Older schemas then degrade explicitly: they raise in strict mode and never drop data silently.

---

## 3. Target architecture (evolution, not rewrite)

The public API (`SEPA::DirectDebit`, `SEPA::CreditTransfer`, `add_transaction`, `to_xml`) stays. Internals move to this shape:

```
lib/sepa_king.rb
lib/sepa_king/
├── version.rb  error.rb (Error, ValidationError, SchemaError, IncompatibleSchemaError)
├── configuration.rb          # SEPA.configure { |c| c.charset = :epc_basic; c.strict = true }
├── schema.rb                 # Schema value object + registry
├── schemas/                  # one file per schema id: namespace, xsd, capabilities, rules
│   ├── pain_001_001_03.rb  pain_001_001_09.rb  pain_001_001_09_ch_03.rb  ...
│   └── pain_008_001_02.rb  pain_008_001_08.rb  ...
├── xsd_cache.rb              # parse each XSD once, thread-safe
├── text/                     # charset.rb (EPC conversion table), truncation
├── values/                   # address.rb (one class; CreditorAddress/DebtorAddress = aliases)
│                             # party_identification.rb (LEI, AnyBIC, Othr), creditor_reference.rb (ISO 11649),
│                             # remittance.rb (Ustrd/Strd), uetr.rb, lei.rb
├── validators/               # existing ActiveModel validators + LEIValidator, CreditorReferenceValidator,
│                             # HybridAddressValidator
├── builders/                 # shared XML fragments, schema-aware
│   ├── agent.rb  (BIC vs BICFI, NOTPROVIDED)
│   ├── party.rb  (Nm, PstlAdr, Id)
│   ├── postal_address.rb  (structured / hybrid / legacy)
│   ├── remittance.rb
│   └── date.rb   (ReqdExctnDt Dt vs DtTm)
├── account*.rb  transaction*.rb  message*.rb   # unchanged public classes, slimmer
└── schema/*.xsd              # vendored XSDs + SOURCES.md (origin, version, checksum)
```

**Schema object** (replaces `PAIN_*` string branches; the constants stay as aliases):

```ruby
SEPA::Schema.register(
  id:            'pain.008.001.08',
  family:        :direct_debit,
  namespace:     'urn:iso:std:iso:20022:tech:xsd:pain.008.001.08',
  xsd:           'pain.008.001.08.xsd',          # DK GBIC_4 TVS (strictest EPC-conformant subset)
  bic_tag:       :BICFI,
  capabilities:  %i[structured_address hybrid_address lei ultimate_parties structured_remittance creditor_address],
  rules:         [Rules::HybridAddress, Rules::NonEeaDebtorAddress, Rules::SingleLocalInstrument]
)
```

`Message#to_xml(schema = default_schema, **opts)` does these steps:
1. Resolve the schema.
2. Check the message's capabilities against it (strict: raise `IncompatibleSchemaError` listing the unsupported features; lenient: warn and omit).
3. Run the rules.
4. Build the XML with schema-aware builders.
5. Run the XSD gate, using the cached `Nokogiri::XML::Schema`.

Adding `pain.001.001.12` later means a new schema file plus XSD, with no edits to existing builders.

---

## 4. Feature scope

Legend: **M#** = milestone (§6). ★ = needed by Autobill (our production user).

### 4.1 New message versions
- ★ **`pain.008.001.08`** (SDD Core/B2B, ISO 2019): namespace, `BICFI`, `PostalAddress24`, new `OrgId`/`PrvtId` shapes, `AnyBIC`, LEI. **M1**
- **`pain.001.001.09`** (SCT / SCT Inst, ISO 2019): `ReqdExctnDt/Dt` **and `/DtTm`**, `BICFI`, `PostalAddress24`, `UETR` (generic ISO XSD only; the DK TVS has no UETR, so it's gated by capability). **M1** (Dt) / **M2** (DtTm, UETR)
- **`pain.001.001.09.ch.03`** (Swiss Payment Standards), the successor of the existing `.ch.02`, including the QR reference (`QRR`) and SCOR for QR-bills. **M4**
- **Container messages** (DK `container.nnn.001.GBIC4`) ([#118](https://github.com/salesking/sepa_king/issues/118)). **M4**
- Default schema stays `*.02`/`*.03` in 0.x and switches to `.08`/`.09` in **1.0**. In 0.x a one-time deprecation warning fires when someone relies on the default.

### 4.2 Parties, addresses, identifiers (2019 data model)
- ★ One `SEPA::Address` with **all `PostalAddress24` fields**: `department`, `sub_department`, `street_name`, `building_number`, `building_name`, `floor`, `post_box`, `room`, `post_code`, `town_name`, `town_location_name`, `district_name`, `country_sub_division`, `country_code`, `address_line1/2`. **M1**
- ★ **Address modes, validated:**
  - `:structured`: `TwnNm` + `Ctry` are required.
  - `:hybrid`: `TwnNm` + `Ctry` plus at most 2 `AdrLine`s.
  - `:legacy`: free text, allowed only for `*.02`/`*.03` (strict mode raises for 2019 schemas).
  - Rendering per schema: legacy schemas keep today's output byte-for-byte.
- ★ **Creditor postal address** in SDD `PmtInf/Cdtr` (missing today) and **debtor address** in SCT `PmtInf/Dbtr`. **M1**
- ★ **Non-EEA SEPA rule:** debtor address is mandatory in SDD (and creditor address in SCT) when the counterparty's agent country is outside the EEA (CH, GB, MC, SM, VA, AD, JE, GG, IM, PM, …), derived from the IBAN country. **M2**
- **Ultimate parties:** `UltmtCdtr` / `UltmtDbtr` with name, address and identification. **M2**
- **Party identification:**
  - organisations: `AnyBIC`, **LEI** (ISO 17442 checksum), `Othr` + scheme
  - private persons: `DtAndPlcOfBirth`, `Othr`
  - Applies to initiating party, creditor, debtor and ultimate parties.
  - Fixes today's odd `InitgPty/Id/OrgId/Othr = creditor identifier`; that stays as the legacy default. **M2**
- **Initiating party ≠ creditor/debtor**, for payment factories and service providers. **M2**

### 4.3 Payment features
- **SCT Inst:** `LclInstrm=INST` plus `ReqdExctnDt/DtTm`. Rules: EUR only, a single kind of instant payment per message, optional amount limit configurable by the caller (no fixed scheme maximum hardcoded) ([#121](https://github.com/salesking/sepa_king/pull/121)). **M2**
- **Structured remittance:**
  - `Strd/CdtrRefInf` with an **ISO 11649 RF creditor reference** (generator + validator), `Tp/CdOrPrtry/Cd=SCOR`
  - mutually exclusive with `Ustrd` per EPC (fixes [#51](https://github.com/salesking/sepa_king/issues/51)). **M2**
- **Purpose** (`Purp/Cd`, ExternalPurpose1Code) per transaction; **category purpose** for SDD too (SCT has it already). **M2**
- **Instruction priority** (`InstrPrty` HIGH/NORM) and **charge bearer** per batch for non-SEPA credit transfers. **M2**
- **Debtor account per CT transaction** ([#113](https://github.com/salesking/sepa_king/pull/113)): batches grouped per debtor account, like the existing creditor-account-per-transaction feature for SDD. **M2**
- **Mandate amendment** on 2019 schemas: `OrgnlDbtrAgt/FinInstnId/Othr/Id=SMNDA`, `OrgnlDbtrAcct`, `OrgnlCdtrSchmeId`, original mandate id (`OrgnlMndtId`; missing today). **M2**
- **Electronic mandate data:** `ElctrncSgntr`, plus the mandate's own `FinInstnId` when applicable (`AmdmntInd`, `DtOfSgntr` already exist). **M3**
- **COR1** is obsolete in EPC since 2017. Keep accepting it for old schemas, warn on 2019 schemas. **M2**
- **Amount bounds** 0.01 .. 999 999 999.99. Reject floats that don't round to 2 decimals instead of rounding them silently (behind a `strict_amounts` option until 1.0). **M1**
- **BBAN / non-IBAN accounts** for non-SEPA credit transfers ([#112](https://github.com/salesking/sepa_king/pull/112)). **M4**

### 4.4 Text & character set
- ★ **EPC conversion table** ([#105](https://github.com/salesking/sepa_king/pull/105)):
  - transliterate instead of deleting (`é→e`, `ł→l`, `Ø→O`, …), keeping today's German-umlaut behaviour where DK allows it
  - configurable: `charset: :epc_basic | :dk_extended (default, today's behaviour + transliteration) | :custom(Proc)`. **M3**
- Field-length truncation helpers (`SEPA::Text.truncate(value, 70)`) that never cut inside a multibyte character. **M3**
- **Fail-loud option:** `charset_mode: :strict` raises on characters that can't be mapped. **M3**

### 4.5 Quality of life
- **Dry run / introspection:** `message.validate!` returns structured errors without building XML; `message.to_h` gives a schema-neutral hash for logging and audit trails. **M3**
- **Summary helpers:** `message.batches_summary` (count and sum per `PmtInf`), handy for confirmation screens. **M3**
- **`to_xml` options:** `pretty: false` (compact output for upload size), `validate: true` (opt-out only for benchmarks and tests), `io:` (stream to a file for very large batches). **M3**
- **Deterministic output** for testing: an injectable clock (`creation_date_time`) and message-id generator. **M1**
- **i18n:** ActiveModel error messages get `en` and `de` locale files instead of hardcoded English strings. **M3**

### 4.6 Out of scope (point to other gems)
- Parsing bank responses (`pain.002`, `camt.052/053/054`): `sepa_file_parser` already covers this, so link it from the README.
- Transport (EBICS): use `epics`.
- Verification of Payee: the bank does this on its own channels, and pain.001.001.09 has no VoP element. Mention it in the README FAQ.

---

## 5. Engineering quality ("top gem" bar)

| Area | Target |
|---|---|
| **Ruby** | `required_ruby_version >= 3.3`: 3.2 has been EOL since Mar 2026, and 3.3 is what Autobill runs today. CI: 3.3, 3.4, 4.0, `head` (allowed to fail), plus JRuby 10 (allowed to fail until green). |
| **ActiveModel** | `>= 7.2, < 9`; CI matrix 7.2 / 8.0 / 8.1 / `main` (allowed to fail). Optional in 2.0 (M5). |
| **Nokogiri** | `>= 1.16`; CI also runs once against the latest nokogiri. |
| **Dependencies** | Runtime: `activemodel`, `nokogiri`, `bigdecimal`, `iban-tools` (re-evaluated in M5: a 60-line in-house mod-97 plus country-length table removes a lightly maintained dependency). |
| **Linting** | RuboCop with `rubocop-rspec`, `rubocop-performance` and `rubocop-rake`; `# frozen_string_literal: true` everywhere; drop the `# encoding: utf-8` headers. |
| **Coverage** | SimpleCov with **100% line and branch coverage enforced** (`minimum_coverage line: 100, branch: 100`). Coveralls is dropped; coverage goes to Codecov via OIDC (no token). |
| **Test suite** | <ul><li>**XSD conformance:** every schema × every feature combination is generated and validated against its XSD. Golden files are regenerated with `rake golden:update` and reviewed as diffs.</li><li>**Byte-for-byte regression:** every legacy example in `spec/examples` must stay identical in 0.x.</li><li>**Official samples:** EPC/DK sample files, where licensing allows, are round-tripped through the builder.</li><li>**Property-based tests** (`prop_check`) for IBAN, LEI, RF reference, transliteration and amount rounding.</li><li>**Mutation testing** (`mutant`, free for OSS) on `values/`, `validators/` and `text/`, gated in CI on changed files.</li><li>**Performance:** `benchmark-ips` script for 10k transactions, compared against the previous release.</li></ul> |
| **Types** | RBS signatures in `sig/`, checked by `steep` in CI for the public API. |
| **Docs** | YARD with 100% public API coverage (`yard stats --list-undoc` in CI), published on rubydoc.info; README restructured (§7); `CHANGELOG.md` (Keep a Changelog); `UPGRADING.md` for 1.0 / 2.0; `SECURITY.md`. |
| **Repo hygiene** | Dependabot (bundler and actions); GitHub Actions pinned by SHA, `permissions: read-all`; OpenSSF Scorecard; `bundler-audit`; `.editorconfig`; issue and PR templates; `CODEOWNERS`. |
| **Release** | gemspec metadata (`changelog_uri`, `source_code_uri`, `documentation_uri`, `bug_tracker_uri`, `rubygems_mfa_required`); git-independent `files` list (`Dir[...]`, so it builds from a tarball); release workflow on tag via RubyGems **Trusted Publishing**, but only once we have push rights on `sepa_king` (§8); signed tags. |

### README badges

The badges point to upstream for the PR, or to the fork until then:
- CI status
- Codecov coverage
- Gem version
- Gem downloads
- Ruby versions (shields.io, from the gemspec)
- License
- Documentation (rubydoc)
- OpenSSF Scorecard

---

## 6. Milestones

Each milestone is a set of small PRs against the fork's `master`, all green, and all suitable to send upstream as-is.

| M | Contents | Version | Done when |
|---|---|---|---|
| **M0 Modernise tooling** | Ruby ≥ 3.3, CI matrix (Ruby × ActiveModel), RuboCop setup and autofix, frozen string literals, SimpleCov branch coverage + Codecov, drop coveralls, Dependabot, gemspec metadata, `Dir[]` file list, CHANGELOG, README badges | 0.15.0.pre | CI green on the whole matrix; no behaviour change (golden files identical) |
| **M1 New formats (★ Autobill)** | Schema registry + `xsd_cache`; builders extracted; `pain.008.001.08` + `pain.001.001.09` (Dt) based on #117; unified `Address` with structured/hybrid/legacy modes; creditor address in SDD; amount bounds; injectable clock and id | **0.15.0** | Golden files for both new schemas validate; legacy output identical; Autobill runs on it in production |
| **M2 2019 data model** | Ultimate parties, LEI / party identification, initiating party ≠ creditor, structured remittance + RF reference, purpose, SCT Inst + `DtTm`, UETR, debtor account per transaction, non-EEA address rule, mandate amendment completeness, COR1 warning | 0.16.0 | Feature matrix test (every feature × every schema that supports it) green |
| **M3 Text, DX, docs** | EPC charset (#105), `validate!`/`to_h`/summary, `to_xml` options, i18n, YARD 100%, RBS + steep, README rewrite | 0.17.0 | YARD/steep gates in CI |
| **M4 Beyond SEPA basics** | `pain.001.001.09.ch.03`, container messages, BBAN | 0.18.0 | Samples from SIX/DK validate |
| **M5 1.0 / 2.0** | 1.0: default schemas switch to 2019 versions, deprecations removed, `strict` on by default. 2.0: ActiveModel optional (plain-Ruby validation core with an ActiveModel adapter), `iban-tools` replaced | 1.0.0 / 2.0.0 | `UPGRADING.md`; at least one release candidate tested by Autobill |

M0 + M1 are the urgent path (German banks reject `.02` now). M2–M5 can follow at a normal pace.

---

## 7. README structure (target)

1. Title, badges, and a one-line pitch: "SEPA XML (ISO 20022 pain.001 / pain.008) for Ruby".
2. **Supported messages table:** schema × SCT / SCT Inst / SDD Core / SDD B2B × notes (EPC, DK, SIX); default schema highlighted.
3. **"November 2026" box:** which schema to use now, plus the structured-address rule.
4. Installation and requirements (Ruby / ActiveModel / Nokogiri versions).
5. Quick start: one SDD and one SCT example, 15 lines each.
6. Full option reference, generated from YARD-tagged attribute docs.
7. Recipes: structured addresses, SCT Inst, RF creditor references, ultimate parties, mandate amendments, large files, choosing a charset.
8. Validation and errors (strict vs lenient, error classes).
9. Migration guides (0.14 → 0.15, → 1.0).
10. Related gems (parsing, EBICS), FAQ (VoP, COR1, bank variants).
11. Contributing, Security, Changelog, Credits (including the absorbed PR authors), License.

---

## 8. Upstream strategy

1. **Before writing code:** comment on [#124](https://github.com/salesking/sepa_king/issues/124) and offer to help maintain, linking this roadmap. Ping @tobischo on #117 and say we'd build on their branch with credit.
2. **PR series, not one big PR.** Send each item as its own PR against `salesking/sepa_king:master`, in order. Later PRs are stacked on the fork and rebased as earlier ones merge.

   | Order | PR |
   |---|---|
   | 1 | M0 tooling |
   | 2 | Schema registry refactor (no behaviour change) |
   | 3 | `pain.008.001.08` + `pain.001.001.09` (crediting #117) |
   | 4 | Unified address + structured/hybrid |
   | 5 | Each M2 feature |
3. **Distribution until upstream merges and releases.** Consumers (Autobill) use `gem 'sepa_king', github: 'trahfo/sepa_king', tag: 'v0.15.0'`. We **don't publish `sepa_king` to RubyGems** because we don't own the name.
4. **If upstream stays silent** for about 8 weeks after M1, two options:
   - (a) ask for RubyGems ownership via #124, or
   - (b) publish under a new name (e.g. `sepa_king_next`, check availability) and keep the `SEPA` namespace so switching back is one line.

   That's a decision for the fork owner at that point.

---

## 9. Risks

| Risk | Mitigation |
|---|---|
| Bank variants (DK TVS vs EPC vs Austrian/Swiss) | Vendor the DK GBIC_4 TVS as default (strictest EPC-conformant subset), document others in `schema/SOURCES.md`; schema `profile:` option if a bank needs the generic ISO XSD |
| Accidental output change for existing users | Legacy golden files must stay byte-identical in 0.x; enforced in CI |
| Upstream never merges | §8.4; fork stays fully usable via git source |
| XSD licensing | ISO / DK / SIX XSDs are published for implementers; record source and terms in `SOURCES.md`; replace a file if its terms forbid redistribution |
| Scope creep delays the urgent fix | M1 is releasable on its own and ships to Autobill first; everything else is after |

---

## Sources

- [salesking/sepa_king #124 – Looking for a new maintainer](https://github.com/salesking/sepa_king/issues/124)
- [salesking/sepa_king #117 – Add pain.001.001.09 and pain.008.001.08](https://github.com/salesking/sepa_king/pull/117)
- [UniCredit/HVB – Format changes Nov 2026](https://www.hypovereinsbank.de/content/dam/hypovereinsbank/unternehmen/pdf/Downloadcenter/Overview_Format_Changes_in_November_2026_EN.pdf)
- [GLS Bank – PAIN](https://www.gls.de/pain/)
- [EPC153-22 v2.1 – Provision of addresses](https://www.europeanpaymentscouncil.eu/sites/default/files/kb/file/2025-10/EPC153-22%20v2.1%20EPC%20guidance%20document%20-%20Provision%20of%20Addresses%20under%20the%20EPC%20Payment%20Schemes.pdf)
- [Bank Austria – ISO migration](https://www.bankaustria.at/files/iso_migration.pdf)
