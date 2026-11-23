# Ruby gem for creating SEPA XML files

[![CI](https://github.com/trahfo/sepa_king/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/trahfo/sepa_king/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/trahfo/sepa_king/branch/master/graph/badge.svg)](https://codecov.io/gh/trahfo/sepa_king)
[![Gem Version](https://img.shields.io/gem/v/sepa_king.svg)](https://rubygems.org/gems/sepa_king)
[![Downloads](https://img.shields.io/gem/dt/sepa_king.svg)](https://rubygems.org/gems/sepa_king)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.3-CC342D.svg)](https://www.ruby-lang.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)
[![Docs](https://img.shields.io/badge/docs-rubydoc.info-blue.svg)](https://www.rubydoc.info/gems/sepa_king)

We love building payment applications! So after developing the [DTAUS library for Ruby](https://github.com/salesking/king_dtaus) we move on with SEPA.


## Features

This gem implements the following two messages out of the ISO 20022 standard:

| Message | ISO 2019 (current) | ISO 2009 (legacy) |
|---|---|---|
| Credit Transfer Initiation | `pain.001.001.09` | `pain.001.001.03`, `pain.001.002.03`, `pain.001.003.03`, `pain.001.001.03.ch.02` |
| Direct Debit Initiation | `pain.008.001.08` | `pain.008.001.02`, `pain.008.002.02`, `pain.008.003.02` |

The 2019 versions are validated against the Technical Validation Subsets of the
Deutsche Kreditwirtschaft (DFÜ-Abkommen Anlage 3, GBIC_4), the strictest
EPC-conformant variant. Every generated file passes the XSD of its schema
before it is returned.

BTW: **pain** is a shortcut for **Pa**yment **In**itiation.

> **November 2026:** German banks no longer accept the 2009 versions
> (`pain.001.001.03`, `pain.008.001.02`). Use `pain.001.001.09` / `pain.008.001.08`:
>
> ```ruby
> sdd.to_xml(SEPA::PAIN_008_001_08)
> sct.to_xml(SEPA::PAIN_001_001_09)
> ```
>
> These schemas only accept **structured addresses**: if you pass an address,
> it needs at least `town_name` and `country_code` and no `address_line1/2`.
> Passing no address at all is fine. `to_xml` without an argument still uses
> the 2009 version; this default changes in 1.0.


## Requirements

* Ruby 3.3 or newer (tested on 3.3, 3.4 and 4.0)
* ActiveModel 7.2, 8.0 or 8.1
* Nokogiri 1.16 or newer


## Installation

    gem install sepa_king


## Usage

How to create the XML for **Direct Debit Initiation** (in German: "Lastschriften")

```ruby
# First: Create the main object
sdd = SEPA::DirectDebit.new(
  # Name of the initiating party and creditor, in German: "Auftraggeber"
  # String, max. 70 char
  name:       'Gläubiger GmbH',

  # OPTIONAL: Business Identifier Code (SWIFT-Code) of the creditor
  # String, 8 or 11 char
  bic:        'BANKDEFFXXX',

  # International Bank Account Number of the creditor
  # String, max. 34 chars
  iban:       'DE87200500001234567890',

  # Creditor Identifier, in German: Gläubiger-Identifikationsnummer
  # String, max. 35 chars
  creditor_identifier: 'DE98ZZZ09999999999',

  # OPTIONAL: Postal address of the creditor (Hash or SEPA::CreditorAddress)
  address: { street_name: 'Hauptstraße', building_number: '1', post_code: '10115',
             town_name: 'Berlin', country_code: 'DE' }
)

# Second: Add transactions
sdd.add_transaction(
  # Name of the debtor, in German: "Zahlungspflichtiger"
  # String, max. 70 char
  name:                      'Zahlemann & Söhne GbR',

  # OPTIONAL: Business Identifier Code (SWIFT-Code) of the debtor's account
  # String, 8 or 11 char
  bic:                       'SPUEDE2UXXX',

  # International Bank Account Number of the debtor's account
  # String, max. 34 chars
  iban:                      'DE21500500009876543210',

  # Amount
  # Number with two decimal digit
  amount:                    39.99,

  # OPTIONAL: Currency, EUR by default (ISO 4217 standard)
  # String, 3 char
  currency:                  'EUR',

  # OPTIONAL: Instruction Identification, will not be submitted to the debtor
  # String, max. 35 char
  instruction:               '12345',

  # OPTIONAL: End-To-End-Identification, will be submitted to the debtor
  # String, max. 35 char
  reference:                 'XYZ/2013-08-ABO/6789',

  # OPTIONAL: Unstructured remittance information, in German "Verwendungszweck"
  # String, max. 140 char
  remittance_information:    'Vielen Dank für Ihren Einkauf!',

  # Mandate identifikation, in German "Mandatsreferenz"
  # String, max. 35 char
  mandate_id:                'K-02-2011-12345',

  # Mandate Date of signature, in German "Datum, zu dem das Mandat unterschrieben wurde"
  # Date
  mandate_date_of_signature: Date.new(2011,1,25),

  # Local instrument, in German "Lastschriftart"
  # One of these strings:
  #   'CORE' ("Basis-Lastschrift")
  #   'COR1' ("Basis-Lastschrift mit verkürzter Vorlagefrist")
  #   'B2B' ("Firmen-Lastschrift")
  local_instrument: 'CORE',

  # Sequence type
  # One of these strings:
  #   'FRST' ("Erst-Lastschrift")
  #   'RCUR' ("Folge-Lastschrift")
  #   'OOFF' ("Einmalige Lastschrift")
  #   'FNAL' ("Letztmalige Lastschrift")
  sequence_type: 'OOFF',

  # OPTIONAL: Requested collection date, in German "Fälligkeitsdatum der Lastschrift"
  # Date
  requested_date: Date.new(2013,9,5),

  # OPTIONAL: Enables or disables batch booking, in German "Sammelbuchung / Einzelbuchung"
  # True or False
  batch_booking: true

  # OPTIONAL: Use a different creditor account
  # CreditorAccount
  creditor_account: SEPA::CreditorAccount.new(
    name:                'Creditor Inc.',
    bic:                 'RABONL2U',
    iban:                'NL08RABO0135742099',
    creditor_identifier: 'NL53ZZZ091734220000'
  )

  # OPTIONAL: Specify the country & address of the debtor (REQUIRED for SEPA debits outside of EU. The individually required fields depend on the target country)
  debtor_address: SEPA::DebtorAddress.new(
    country_code:        'CH',
    # Not required if individual fields are used
    address_line1:       'Mustergasse 123a',
    address_line2:       '1234 Musterstadt'
    # Not required if address_line1 and address_line2 are used
    street_name:         'Mustergasse',
    building_number:     '123a',
    post_code:           '1234',
    town_name:           'Musterstadt'
  )
)
sdd.add_transaction ...

# Last: create XML string
xml_string = sdd.to_xml(SEPA::PAIN_008_001_08) # Use schema pain.008.001.08 (recommended)
xml_string = sdd.to_xml('pain.008.002.02')     # Use schema pain.008.002.02
xml_string = sdd.to_xml                        # Use schema pain.008.001.02 (default until 1.0)
```


How to create the XML for **Credit Transfer Initiation** (in German: "Überweisungen")

```ruby
# First: Create the main object
sct = SEPA::CreditTransfer.new(
  # Name of the initiating party and debtor, in German: "Auftraggeber"
  # String, max. 70 char
  name: 'Schuldner GmbH',

  # OPTIONAL: Business Identifier Code (SWIFT-Code) of the debtor
  # String, 8 or 11 char
  bic:  'BANKDEFFXXX',

  # International Bank Account Number of the debtor
  # String, max. 34 chars
  iban: 'DE87200500001234567890'
)

# Second: Add transactions
sct.add_transaction(
  # Name of the creditor, in German: "Zahlungsempfänger"
  # String, max. 70 char
  name:                   'Telekomiker AG',

  # OPTIONAL: Business Identifier Code (SWIFT-Code) of the creditor's account
  # String, 8 or 11 char
  bic:                    'PBNKDEFF370',

  # International Bank Account Number of the creditor's account
  # String, max. 34 chars
  iban:                   'DE37112589611964645802',

  # Amount
  # Number with two decimal digit
  amount:                 102.50,

  # OPTIONAL: Currency, EUR by default (ISO 4217 standard)
  # String, 3 char
  currency:               'EUR',

  # OPTIONAL: Instruction Identification, will not be submitted to the creditor
  # String, max. 35 char
  instruction:               '12345',

  # OPTIONAL: End-To-End-Identification, will be submitted to the creditor
  # String, max. 35 char
  reference:              'XYZ-1234/123',

  # OPTIONAL: Unstructured remittance information, in German "Verwendungszweck"
  # String, max. 140 char
  remittance_information: 'Rechnung vom 22.08.2013',

  # OPTIONAL: Requested execution date, in German "Ausführungstermin"
  # Date
  requested_date: Date.new(2013,9,5),

  # OPTIONAL: Enables or disables batch booking, in German "Sammelbuchung / Einzelbuchung"
  # True or False
  batch_booking: true,

  # OPTIONAL: Urgent Payment
  # One of these strings:
  #   'SEPA' ("SEPA-Zahlung")
  #   'URGP' ("Taggleiche Eilüberweisung")
  service_level: 'URGP'

  # OPTIONAL: Unstructured information to indicate the purpose of the payment
  # String, max. 4 char
  category_purpose:         'SALA',

  # OPTIONAL: Specify the country & address of the creditor (REQUIRED for SEPA debits outside of EU. The individually required fields depend on the target country)
  creditor_address: SEPA::CreditorAddress.new(
    country_code:        'CH',
    # Not required if individual fields are used
    address_line1:       'Mustergasse 123a',
    address_line2:       '1234 Musterstadt'
    # Not required if address_line1 and address_line2 are used
    street_name:         'Mustergasse',
    building_number:     '123a',
    post_code:           '1234',
    town_name:           'Musterstadt'
  )
)
sct.add_transaction ...

# Last: create XML string
xml_string = sct.to_xml(SEPA::PAIN_001_001_09) # Use schema pain.001.001.09 (recommended)
xml_string = sct.to_xml('pain.001.002.03')     # Use schema pain.001.002.03
xml_string = sct.to_xml                        # Use schema pain.001.001.03 (default until 1.0)
```

## Addresses

`SEPA::Address` (and its subclasses `SEPA::DebtorAddress`, `SEPA::CreditorAddress`)
supports every element of ISO 20022 `PostalAddress24`. Wherever an address is
accepted you can also pass a Hash:

| Attribute | XML | Max |
|---|---|---|
| `department`, `sub_department` | `Dept`, `SubDept` | 70 |
| `street_name`, `building_number`, `building_name` | `StrtNm`, `BldgNb`, `BldgNm` | 70, 16, 35 |
| `floor`, `post_box`, `room` | `Flr`, `PstBx`, `Room` | 70, 16, 70 |
| `post_code`, `town_name`, `town_location_name` | `PstCd`, `TwnNm`, `TwnLctnNm` | 16, 35, 35 |
| `district_name`, `country_sub_division`, `country_code` | `DstrctNm`, `CtrySubDvsn`, `Ctry` | 35, 35, 2 |
| `address_line1`, `address_line2` | `AdrLine` | 70 |

The 2009 schemas only write the elements they know (`Dept`, `SubDept`, `StrtNm`,
`BldgNb`, `PstCd`, `TwnNm`, `CtrySubDvsn`, `Ctry`, `AdrLine`). The 2019 schemas
write all of them and require a structured address (`town_name` and
`country_code`, no address lines); otherwise `schema_compatible?` returns
false and `to_xml` raises `SEPA::Error`.

The account holder's address goes into the message itself
(`SEPA::DirectDebit.new(..., address: {...})` for the creditor,
`SEPA::CreditTransfer.new(..., address: {...})` for the debtor).


## Validations

You can rely on our internal validations, raising errors when needed, during
message creation.
To validate your models holding SEPA related information (e.g. BIC, IBAN,
mandate_id) you can use our validator classes or rely on some constants.

Examples:

```ruby
class BankAccount < ActiveRecord::Base
  # IBAN validation, by default it validates the attribute named "iban"
  validates_with SEPA::IBANValidator, field_name: :iban_the_terrible

  # BIC validation, by default it validates the attribute named "bic"
  validates_with SEPA::BICValidator, field_name: :bank_bic
end

class Payment < ActiveRecord::Base
  validates_inclusion_of :sepa_sequence_type, in: SEPA::DirectDebitTransaction::SEQUENCE_TYPES

  # Mandate ID validation, by default it validates the attribute named "mandate_id"
  validates_with SEPA::MandateIdentifierValidator, field_name: :mandate_id
end
```

**Beware:** The SEPA::IBANValidator is strict - e.g. it does not allow any spaces in the IBAN.

Also see:
* [lib/sepa_king/validator.rb](https://github.com/salesking/sepa_king/blob/master/lib/sepa_king/validator.rb)
* [lib/sepa_king/transaction/direct_debit_transaction.rb](https://github.com/salesking/sepa_king/blob/master/lib/sepa_king/transaction/direct_debit_transaction.rb)


## Changelog

See [CHANGELOG.md](CHANGELOG.md).


## Development

```sh
bundle install
bundle exec rake          # RSpec (100 % line and branch coverage enforced) + RuboCop
BUNDLE_GEMFILE=gemfiles/Gemfile-activemodel-7.2.x bundle exec rspec   # another ActiveModel
GOLDEN_UPDATE=1 bundle exec rspec spec/golden_spec.rb                 # after an intended XML change
```

`spec/golden/` holds the exact XML produced for a set of scenarios and every
supported schema. Any change to the generated XML shows up as a diff there.


## Contributors

https://github.com/salesking/sepa_king/graphs/contributors


## Resources

* https://www.ebics.de/de/datenformate
* EPC rulebooks and implementation guidelines: https://www.europeanpaymentscouncil.eu/what-we-do/epc-payment-schemes
* SalesKing: http://salesking.eu


## License

Released under the MIT license

Copyright (c) 2013-2022 Georg Leciejewski (SalesKing), Georg Ledermann (https://github.com/ledermann)
