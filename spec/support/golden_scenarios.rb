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
      'ct_structured' => method(:ct_structured),
      'dd_data_model' => method(:dd_data_model),
      'dd_hybrid' => method(:dd_hybrid),
      'dd_non_eea' => method(:dd_non_eea),
      'ct_data_model' => method(:ct_data_model),
      'ct_instant' => method(:ct_instant),
      'ct_instant_dk' => method(:ct_instant_dk),
      'ct_non_sepa' => method(:ct_non_sepa)
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

  LEI = '529900T8BM49AURSDO55'

  # Initiating party, ultimate parties, RF reference, purpose, category
  # purpose and a full mandate amendment.
  def dd_data_model
    sdd = stamp(dd_base(initiating_party: { name: 'Abrechnungsdienst GmbH',
                                            identification: { lei: LEI, id: 'ABR-1', scheme_code: 'CUST' } }),
                'GOLDEN/DD/MODEL')
    sdd.add_transaction(dd_txn(
                          sequence_type: 'RCUR', category_purpose: 'OTHR', purpose_code: 'OTHR',
                          remittance_information: nil, creditor_reference: 'RF18 5390 0754 7034',
                          ultimate_creditor: { name: 'Carsharing Verein',
                                               identification: { bic: 'BANKDEFFXXX' } },
                          ultimate_debtor: { name: 'Max Mustermann',
                                             identification: { type: :private, id: '4711',
                                                               scheme_proprietary: 'Kundennummer' } },
                          debtor_address: { town_name: 'Wien', country_code: 'AT' },
                          original_mandate_id: 'K-01-2010-1',
                          original_debtor_account: 'NL08RABO0135742099',
                          original_creditor_account: SEPA::CreditorAccount.new(
                            name: 'Alter Gläubiger', creditor_identifier: 'NL04ZZZ987654320000'
                          )
                        ))
    sdd
  end

  # Hybrid address: town and country plus free-text lines (EPC profile only).
  def dd_hybrid
    sdd = stamp(dd_base, 'GOLDEN/DD/HYBRID')
    sdd.add_transaction(dd_txn(debtor_address: { town_name: 'Wien', country_code: 'AT',
                                                 address_line1: 'Hauptstraße 5a', address_line2: 'Stiege 2' }))
    sdd
  end

  # Debtor with a Swiss IBAN: the address is mandatory in the 2019 schemas.
  def dd_non_eea
    sdd = stamp(dd_base, 'GOLDEN/DD/NONEEA')
    sdd.add_transaction(dd_txn(iban: 'CH9300762011623852957', bic: 'UBSWCHZH80A',
                               debtor_address: { street_name: 'Bahnhofstrasse', building_number: '1',
                                                 post_code: '8001', town_name: 'Zürich', country_code: 'CH' }))
    sdd
  end

  # Debtor account per transaction, ultimate parties, RF reference, purpose.
  def ct_data_model
    sct = stamp(ct_base(initiating_party: 'Zahlungsdienst GmbH'), 'GOLDEN/CT/MODEL')
    sct.add_transaction(ct_txn(remittance_information: nil, creditor_reference: 'RF18539007547034',
                               purpose_code: 'SALA', category_purpose: 'SALA', instruction_priority: 'NORM',
                               ultimate_debtor: { name: 'Tochter GmbH', identification: { lei: LEI } },
                               ultimate_creditor: 'Endempfänger AG'))
    sct.add_transaction(ct_txn(reference: 'OTHER-DEBTOR', debtor_account: SEPA::DebtorAccount.new(
      name: 'Zweitkonto GmbH', bic: 'RABONL2UXXX', iban: 'NL08RABO0135742099',
      address: { town_name: 'Utrecht', country_code: 'NL' }
    )))
    sct
  end

  # SEPA Instant with execution date and time and a UETR (EPC profile).
  def ct_instant
    sct = stamp(ct_base, 'GOLDEN/CT/INSTANT')
    sct.add_transaction(ct_txn(local_instrument: 'INST', uetr: 'e0a7c8b2-5f3d-4b1a-9c2e-7d8f6a1b3c4d',
                               requested_date: Time.new(2099, 1, 2, 9, 30, 0, '+01:00')))
    sct
  end

  # SEPA Instant without UETR (DK subset): a message must not mix SCT and SCT Inst.
  def ct_instant_dk
    sct = stamp(ct_base, 'GOLDEN/CT/INSTANTDK')
    sct.add_transaction(ct_txn(local_instrument: 'INST', requested_date: DateTime.new(2099, 1, 2, 9, 30, 0, '+01:00')))
    sct
  end

  # Non-SEPA payment (USD, shared charges, high priority).
  def ct_non_sepa
    sct = stamp(ct_base, 'GOLDEN/CT/NONSEPA')
    sct.add_transaction(ct_txn(currency: 'USD', service_level: nil, charge_bearer: 'SHAR',
                               instruction_priority: 'HIGH'))
    sct
  end
end
