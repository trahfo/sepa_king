# frozen_string_literal: true

# Deterministic message scenarios used by spec/golden_spec.rb.
# Every scenario is rendered for every schema it is compatible with and the
# result is compared byte-for-byte with spec/golden/<scenario>.<schema>.xml.
#
# Regenerate after an intended output change with:
#   GOLDEN_UPDATE=1 bundle exec rspec spec/golden_spec.rb
module GoldenScenarios
  REQUESTED_DATE = Date.new(2099, 1, 2)
  SIGNATURE_DATE = Date.new(2020, 1, 15)
  CREATED_AT     = '2026-11-23T10:00:00+01:00'

  module_function

  def all
    {
      'dd_basic' => method(:dd_basic),
      'dd_amendments' => method(:dd_amendments),
      'dd_creditor_per_txn' => method(:dd_creditor_per_txn),
      'dd_b2b' => method(:dd_b2b),
      'ct_basic' => method(:ct_basic),
      'ct_chf' => method(:ct_chf),
      'ct_no_bic' => method(:ct_no_bic),
      'dd_structured' => method(:dd_structured),
      'ct_structured' => method(:ct_structured)
    }
  end

  def stamp(message, id)
    message.message_identification = id
    message.creation_date_time = CREATED_AT
    message
  end

  def dd_base(**opts)
    SEPA::DirectDebit.new({
      name: 'Gläubiger GmbH',
      bic: 'BANKDEFFXXX',
      iban: 'DE87200500001234567890',
      creditor_identifier: 'DE98ZZZ09999999999'
    }.merge(opts))
  end

  def dd_txn(**opts)
    {
      name: 'Zahlemann & Söhne GbR',
      bic: 'SPUEDE2UXXX',
      iban: 'DE21500500009876543210',
      amount: 39.99,
      instruction: '12345',
      reference: 'XYZ/2013-08-ABO/6789',
      remittance_information: 'Unsere Rechnung vom 10.08.2013',
      mandate_id: 'K-02-2011-12345',
      mandate_date_of_signature: SIGNATURE_DATE,
      local_instrument: 'CORE',
      sequence_type: 'FRST',
      requested_date: REQUESTED_DATE,
      batch_booking: true
    }.merge(opts)
  end

  def dd_basic
    sdd = stamp(dd_base, 'GOLDEN/DD/BASIC')
    sdd.add_transaction(dd_txn)
    sdd.add_transaction(dd_txn(name: 'Max Mustermann', bic: nil, iban: 'DE68210501700012345678',
                               amount: 100, sequence_type: 'RCUR', mandate_id: 'K-03-2011-99',
                               instruction: nil, remittance_information: nil))
    sdd.add_transaction(dd_txn(name: 'Adressat', amount: 1.5, reference: 'ADR-1',
                               debtor_address: SEPA::DebtorAddress.new(
                                 street_name: 'Hauptstraße', building_number: '5a', post_code: '1010',
                                 town_name: 'Wien', country_code: 'AT'
                               )))
    sdd.add_transaction(dd_txn(name: 'Freitext', amount: 2, reference: 'ADR-2',
                               debtor_address: SEPA::DebtorAddress.new(
                                 country_code: 'CH', address_line1: 'Musterweg 1', address_line2: '8000 Zürich'
                               )))
    sdd
  end

  def dd_amendments
    sdd = stamp(dd_base, 'GOLDEN/DD/AMEND')
    sdd.add_transaction(dd_txn(original_debtor_account: 'NL08RABO0135742099'))
    sdd.add_transaction(dd_txn(reference: 'SMNDA-1', same_mandate_new_debtor_agent: true))
    sdd.add_transaction(dd_txn(reference: 'OCSI-1', original_creditor_account: SEPA::CreditorAccount.new(
      name: 'Alter Gläubiger', creditor_identifier: 'NL04ZZZ987654320000'
    )))
    sdd
  end

  def dd_creditor_per_txn
    sdd = stamp(dd_base, 'GOLDEN/DD/CREDITORS')
    sdd.add_transaction(dd_txn)
    sdd.add_transaction(dd_txn(reference: 'OTHER-CRED', creditor_account: SEPA::CreditorAccount.new(
      name: 'Zweitgläubiger AG', bic: 'RABONL2UXXX', iban: 'NL08RABO0135742099',
      creditor_identifier: 'NL53ZZZ091734220000'
    )))
    sdd
  end

  def dd_b2b
    sdd = stamp(dd_base, 'GOLDEN/DD/B2B')
    sdd.add_transaction(dd_txn(local_instrument: 'B2B', sequence_type: 'OOFF', batch_booking: false))
    sdd
  end

  def ct_base(**opts)
    SEPA::CreditTransfer.new({
      name: 'Schuldner GmbH',
      bic: 'BANKDEFFXXX',
      iban: 'DE87200500001234567890'
    }.merge(opts))
  end

  def ct_txn(**opts)
    {
      name: 'Telekomiker AG',
      bic: 'PBNKDEFF370',
      iban: 'DE37112589611964645802',
      amount: 102.50,
      instruction: '12345',
      reference: 'XYZ-1234/123',
      remittance_information: 'Rechnung vom 22.08.2013',
      requested_date: REQUESTED_DATE,
      batch_booking: true
    }.merge(opts)
  end

  def ct_basic
    sct = stamp(ct_base, 'GOLDEN/CT/BASIC')
    sct.add_transaction(ct_txn)
    sct.add_transaction(ct_txn(name: 'Ohne BIC', bic: nil, amount: 7, reference: 'NOBIC', batch_booking: false))
    sct.add_transaction(ct_txn(name: 'Mit Adresse', reference: 'ADR-1', category_purpose: 'SALA',
                               creditor_address: SEPA::CreditorAddress.new(
                                 street_name: 'Mustergasse', building_number: '12', post_code: '80331',
                                 town_name: 'München', country_code: 'DE'
                               )))
    sct.add_transaction(ct_txn(name: 'Freitext', reference: 'ADR-2',
                               creditor_address: SEPA::CreditorAddress.new(
                                 country_code: 'DE', address_line1: 'Mustergasse 12', address_line2: '80331 München'
                               )))
    sct
  end

  def ct_chf
    sct = stamp(ct_base(bic: 'CRESCHZZ80A', iban: 'CH9300762011623852957'), 'GOLDEN/CT/CHF')
    sct.add_transaction(ct_txn(currency: 'CHF', iban: 'CH5604835012345678009', bic: 'CRESCHZZ80A',
                               service_level: nil))
    sct
  end

  def ct_no_bic
    sct = stamp(ct_base(bic: nil), 'GOLDEN/CT/NOBIC')
    sct.add_transaction(ct_txn(bic: nil))
    sct
  end

  STRUCTURED_ADDRESS = {
    department: 'Buchhaltung', sub_department: 'Lastschriften', street_name: 'Hauptstraße',
    building_number: '5a', building_name: 'Haus Nord', floor: '3', post_box: 'PF 12', room: '301',
    post_code: '1010', town_name: 'Wien', town_location_name: 'Innere Stadt', district_name: 'Wien 1',
    country_sub_division: 'W', country_code: 'AT'
  }.freeze

  # Structured addresses everywhere, as required by the ISO 2019 schemas.
  def dd_structured
    sdd = stamp(dd_base(bic: nil, address: { street_name: 'Ringstraße', building_number: '1',
                                             post_code: '1010', town_name: 'Wien', country_code: 'AT' }),
                'GOLDEN/DD/STRUCTURED')
    sdd.add_transaction(dd_txn(sequence_type: 'RCUR', debtor_address: STRUCTURED_ADDRESS))
    sdd.add_transaction(dd_txn(name: 'Ohne Adresse', bic: nil, reference: 'NOADR', sequence_type: 'RCUR'))
    sdd.add_transaction(dd_txn(name: 'Nur Ort', reference: 'TOWN', sequence_type: 'RCUR',
                               debtor_address: { town_name: 'Graz', country_code: 'AT' }))
    sdd
  end

  def ct_structured
    sct = stamp(ct_base(address: { street_name: 'Mustergasse', building_number: '12', post_code: '80331',
                                   town_name: 'München', country_code: 'DE' }),
                'GOLDEN/CT/STRUCTURED')
    sct.add_transaction(ct_txn(category_purpose: 'SALA', creditor_address: STRUCTURED_ADDRESS))
    sct.add_transaction(ct_txn(name: 'Ohne BIC', bic: nil, reference: 'NOBIC'))
    sct
  end
end
