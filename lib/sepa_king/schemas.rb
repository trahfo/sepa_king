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

  # Countries in the SEPA scheme area outside the EEA (EPC list of SEPA scheme
  # countries). For these, the EPC rulebooks require the address of the
  # debtor (SDD) or creditor (SCT). Verify against the current EPC list.
  NON_EEA_SEPA_COUNTRIES = %w[AD AL CH GB GG IM JE MC MD ME MK PM SM VA].freeze

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

  ISO2019_FEATURES = %i[bicfi postal_address_24 non_eea_address lei].freeze
  private_constant :ISO2019_FEATURES

  # ISO 20022 version 2019.
  # :dk  – Technical Validation Subsets of the Deutsche Kreditwirtschaft
  #        (DFÜ-Abkommen Anlage 3, GBIC_4): structured addresses only.
  # :epc – generic ISO 20022 XSD plus EPC rulebook rules: structured or hybrid
  #        addresses (TwnNm + Ctry, up to two AdrLine), UETR for credit transfers.
  Schema.register PAIN_008_001_08, profile: :dk, family: :direct_debit,
                                   features: ISO2019_FEATURES + %i[structured_address]
  Schema.register PAIN_008_001_08, profile: :epc, family: :direct_debit,
                                   features: ISO2019_FEATURES + %i[hybrid_address],
                                   xsd_file: 'pain.008.001.08.iso.xsd'
  Schema.register PAIN_001_001_09, profile: :dk, family: :credit_transfer,
                                   features: ISO2019_FEATURES + %i[structured_address date_choice uniform_local_instrument]
  Schema.register PAIN_001_001_09, profile: :epc, family: :credit_transfer,
                                   features: ISO2019_FEATURES + %i[hybrid_address date_choice uetr],
                                   xsd_file: 'pain.001.001.09.iso.xsd'
end
