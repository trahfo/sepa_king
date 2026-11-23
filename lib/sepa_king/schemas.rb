# frozen_string_literal: true

module SEPA
  PAIN_008_001_02 = 'pain.008.001.02'
  PAIN_008_001_08 = 'pain.008.001.08'
  PAIN_008_002_02 = 'pain.008.002.02'
  PAIN_008_003_02 = 'pain.008.003.02'
  PAIN_001_001_03 = 'pain.001.001.03'
  PAIN_001_001_09 = 'pain.001.001.09'
  PAIN_001_002_03 = 'pain.001.002.03'
  PAIN_001_003_03 = 'pain.001.003.03'
  PAIN_001_001_03_CH_02 = 'pain.001.001.03.ch.02'

  # ISO 20022 version 2009 (EPC rulebooks until November 2026)
  Schema.register PAIN_008_001_02, family: :direct_debit
  Schema.register PAIN_008_002_02, family: :direct_debit, features: %i[account_bic_required]
  Schema.register PAIN_008_003_02, family: :direct_debit
  Schema.register PAIN_001_001_03, family: :credit_transfer
  Schema.register PAIN_001_002_03, family: :credit_transfer, features: %i[account_bic_required]
  Schema.register PAIN_001_003_03, family: :credit_transfer
  Schema.register PAIN_001_001_03_CH_02,
                  family: :credit_transfer,
                  namespace: 'http://www.six-interbank-clearing.com/de/pain.001.001.03.ch.02.xsd',
                  schema_location: 'http://www.six-interbank-clearing.com/de/pain.001.001.03.ch.02.xsd  ' \
                                   'pain.001.001.03.ch.02.xsd'

  # ISO 20022 version 2019, validated against the Technical Validation Subsets
  # of the Deutsche Kreditwirtschaft (DFÜ-Abkommen Anlage 3, GBIC_4). They only
  # allow structured addresses (TwnNm and Ctry mandatory, no AdrLine).
  Schema.register PAIN_008_001_08, family: :direct_debit,
                                   features: %i[bicfi postal_address_24 structured_address]
  Schema.register PAIN_001_001_09, family: :credit_transfer,
                                   features: %i[bicfi postal_address_24 structured_address date_choice]
end
