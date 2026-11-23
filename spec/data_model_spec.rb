# frozen_string_literal: true

RSpec.describe 'ISO 2019 data model' do
  let(:lei) { '529900T8BM49AURSDO55' }

  def sdd(**opts)
    SEPA::DirectDebit.new({ name: 'Gläubiger GmbH', bic: 'BANKDEFFXXX', iban: 'DE87200500001234567890',
                            creditor_identifier: 'DE98ZZZ09999999999' }.merge(opts))
  end

  def sct(**opts)
    SEPA::CreditTransfer.new({ name: 'Schuldner GmbH', bic: 'BANKDEFFXXX',
                               iban: 'DE87200500001234567890' }.merge(opts))
  end

  describe SEPA::LEIValidator do
    it 'checks format and check digits' do
      expect(described_class.valid?(lei)).to be(true)
      expect(described_class.valid?('529900T8BM49AURSDO56')).to be(false)
      expect(described_class.valid?('short')).to be(false)
    end
  end

  describe SEPA::CreditorReference do
    it 'validates ISO 11649 references, ignoring spaces and case' do
      expect(described_class.valid?('RF18 5390 0754 7034')).to be(true)
      expect(described_class.valid?('rf18539007547034')).to be(true)
      expect(described_class.valid?('RF19539007547034')).to be(false)
      expect(described_class.valid?('XX18539007547034')).to be(false)
    end

    it 'generates check digits' do
      expect(described_class.generate('539007547034')).to eq('RF18539007547034')
      expect(described_class.generate('a1')).to match(/\ARF\d{2}A1\z/)
      expect(described_class.valid?(described_class.generate('INV2026001'))).to be(true)
    end

    it 'rejects invalid bases' do
      expect { described_class.generate('x' * 22) }.to raise_error(ArgumentError, /must be 1 to 21 letters or digits/)
      expect { described_class.generate('a-b') }.to raise_error(ArgumentError)
    end
  end

  describe SEPA::PartyIdentification do
    it 'needs an identifier' do
      identification = described_class.new
      expect(identification).not_to be_valid
      expect(identification.errors[:base]).to include('needs a BIC, an LEI or an id')
    end

    it 'allows BIC and LEI only for organisations' do
      identification = described_class.new(type: 'private', bic: 'BANKDEFFXXX')
      expect(identification).not_to be_valid
      expect(identification.errors[:base]).to include('BIC and LEI are only allowed for organisations')
    end

    it 'keeps scheme code and proprietary scheme exclusive and needs an id for a scheme' do
      identification = described_class.new(lei: lei, scheme_code: 'CUST', scheme_proprietary: 'X')
      expect(identification).not_to be_valid
      expect(identification.errors[:base]).to include('scheme_code and scheme_proprietary are exclusive',
                                                      'a scheme needs an id')
    end

    it 'validates LEI and BIC' do
      expect(described_class.new(lei: 'invalid')).not_to be_valid
      expect(described_class.new(bic: 'invalid')).not_to be_valid
      expect(described_class.new(lei: lei)).to be_valid
    end

    it 'needs a type' do
      expect(described_class.new(type: nil, id: '1').errors_on(:type)).to be_present
    end

    it 'coerces values' do
      identification = described_class.new(id: '1')
      expect(described_class.coerce(nil)).to be_nil
      expect(described_class.coerce(identification)).to be(identification)
      expect(described_class.coerce(id: '1')).to be_organisation
      expect { described_class.coerce('1') }.to raise_error(ArgumentError, '"1" is not a party identification')
    end
  end

  describe SEPA::Party do
    it 'needs a name or an identification' do
      expect(described_class.new).not_to be_valid
      expect(described_class.new(identification: { lei: lei })).to be_valid
    end

    it 'validates address and identification' do
      party = described_class.new(name: 'X', address: { town_name: 'x' * 36 }, identification: { lei: 'bad' })
      expect(party).not_to be_valid
      expect(party.errors.attribute_names).to include(:address, :identification)
    end

    it 'coerces values' do
      party = described_class.new(name: 'X')
      expect(described_class.coerce(nil)).to be_nil
      expect(described_class.coerce(party)).to be(party)
      expect(described_class.coerce('Y').name).to eq('Y')
      expect(described_class.coerce(name: 'Z').name).to eq('Z')
      expect { described_class.coerce(1) }.to raise_error(ArgumentError, '1 is not a party')
    end

    it 'is incompatible with a 2009 schema when it carries an LEI' do
      party = described_class.new(identification: { lei: lei })
      expect(party).not_to be_schema_compatible(SEPA::Schema[SEPA::PAIN_008_001_02])
      expect(party).to be_schema_compatible(SEPA::Schema[SEPA::PAIN_008_001_08])
    end
  end

  describe 'schema profiles' do
    it 'raises for an unknown profile' do
      expect { SEPA::Schema[SEPA::PAIN_008_001_08, :nope] }
        .to raise_error(ArgumentError, /Profile nope is unknown for schema pain.008.001.08 \(known: dk, epc\)/)
    end

    it 'lists profiles' do
      expect(SEPA::Schema.profiles(SEPA::PAIN_001_001_09)).to eq(%i[dk epc])
    end

    it 'validates hybrid addresses against the EPC profile only' do
      message = sdd
      message.add_transaction(direct_debt_transaction(debtor_address: { town_name: 'Wien', country_code: 'AT',
                                                                        address_line1: 'Ring 1' }))
      expect(message).not_to be_schema_compatible(SEPA::PAIN_008_001_08)
      expect(message).to be_schema_compatible(SEPA::PAIN_008_001_08, profile: :epc)
      expect(message.to_xml(SEPA::PAIN_008_001_08, profile: :epc)).to have_xml('//Dbtr/PstlAdr/AdrLine', 'Ring 1')
    end

    it 'rejects free-text-only addresses in both 2019 profiles' do
      message = sdd
      message.add_transaction(direct_debt_transaction(debtor_address: { country_code: 'AT', address_line1: 'Ring 1' }))
      expect(message).not_to be_schema_compatible(SEPA::PAIN_008_001_08, profile: :epc)
    end
  end

  describe 'non-EEA SEPA countries' do
    it 'requires the debtor address for a Swiss IBAN in the 2019 schemas' do
      message = sdd
      message.add_transaction(direct_debt_transaction(iban: 'CH9300762011623852957'))
      expect(message).not_to be_schema_compatible(SEPA::PAIN_008_001_08)
      expect(message).to be_schema_compatible(SEPA::PAIN_008_001_02)
    end

    it 'requires the creditor address for a credit transfer to a British IBAN' do
      message = sct
      message.add_transaction(credit_transfer_transaction(iban: 'GB29NWBK60161331926819', bic: 'NWBKGB2LXXX'))
      expect(message).not_to be_schema_compatible(SEPA::PAIN_001_001_09)
    end
  end

  describe 'initiating party' do
    it 'is validated' do
      message = sdd(initiating_party: { name: 'x' * 71 })
      message.add_transaction(direct_debt_transaction)
      expect(message).not_to be_valid
      expect(message.errors[:initiating_party]).to be_present
    end

    it 'writes BICOrBEI, scheme code and issuer in the 2009 schemas' do
      message = sct(initiating_party: { name: 'Dienst', identification: { bic: 'BANKDEFFXXX', id: '1',
                                                                          scheme_code: 'CUST', issuer: 'Bank' } })
      message.add_transaction(credit_transfer_transaction)
      xml = message.to_xml(SEPA::PAIN_001_001_03)
      expect(xml).to have_xml('//InitgPty/Id/OrgId/BICOrBEI', 'BANKDEFFXXX')
      expect(xml).to have_xml('//InitgPty/Id/OrgId/Othr/SchmeNm/Cd', 'CUST')
      expect(xml).to have_xml('//InitgPty/Id/OrgId/Othr/Issr', 'Bank')
    end

    it 'renders a party without name, with address and a plain id' do
      message = sdd
      message.add_transaction(direct_debt_transaction(
                                ultimate_debtor: { address: { town_name: 'Wien', country_code: 'AT' },
                                                   identification: { id: 'K-1' } }
                              ))
      expect(message).not_to be_schema_compatible(SEPA::PAIN_008_001_08)
      xml = message.to_xml(SEPA::PAIN_008_001_08, profile: :epc)
      expect(xml).not_to have_xml('//UltmtDbtr/Nm')
      expect(xml).to have_xml('//UltmtDbtr/PstlAdr/TwnNm', 'Wien')
      expect(xml).to have_xml('//UltmtDbtr/Id/OrgId/Othr/Id', 'K-1')
      expect(xml).not_to have_xml('//UltmtDbtr/Id/OrgId/Othr/SchmeNm')
    end

    it 'is incompatible with a 2009 schema when it carries an LEI' do
      message = sct(initiating_party: { identification: { lei: lei } })
      message.add_transaction(credit_transfer_transaction)
      expect(message).not_to be_schema_compatible(SEPA::PAIN_001_001_03)
    end
  end

  describe SEPA::Transaction do
    it 'rejects unstructured and structured remittance together' do
      transaction = SEPA::CreditTransferTransaction.new(credit_transfer_transaction(creditor_reference: 'RF18539007547034'))
      expect(transaction).not_to be_valid
      expect(transaction.errors[:creditor_reference]).to include('cannot be combined with remittance_information')
    end

    it 'rejects an invalid RF reference' do
      transaction = SEPA::CreditTransferTransaction.new(
        credit_transfer_transaction(remittance_information: nil, creditor_reference: 'RF00123')
      )
      expect(transaction.errors_on(:creditor_reference)).to be_present
    end

    it 'validates ultimate parties' do
      transaction = SEPA::DirectDebitTransaction.new(direct_debt_transaction(ultimate_debtor: { name: 'x' * 71 }))
      expect(transaction.errors_on(:ultimate_debtor)).to be_present
    end

    it 'checks a requested time against the minimum date' do
      transaction = SEPA::CreditTransferTransaction.new(credit_transfer_transaction(requested_date: Time.now - (86_400 * 2)))
      expect(transaction.errors_on(:requested_date)).to be_present
    end

    it 'is incompatible with an LEI on an ultimate party in a 2009 schema' do
      transaction = SEPA::DirectDebitTransaction.new(direct_debt_transaction(ultimate_debtor: { identification: { lei: lei } }))
      expect(transaction).not_to be_schema_compatible(SEPA::PAIN_008_001_02)
    end
  end

  describe SEPA::DirectDebitTransaction do
    around do |example|
      described_class.cor1_warned = false
      deprecated = Warning[:deprecated]
      Warning[:deprecated] = true
      example.run
    ensure
      Warning[:deprecated] = deprecated
    end

    it 'warns once about COR1' do
      expect { described_class.new(direct_debt_transaction(local_instrument: 'COR1')) }.to output(/COR1 is obsolete/).to_stderr
      expect { described_class.new(direct_debt_transaction(local_instrument: 'COR1')) }.not_to output.to_stderr
    end

    it 'validates the original mandate id' do
      transaction = described_class.new(direct_debt_transaction(original_mandate_id: 'ü' * 36))
      expect(transaction.errors_on(:original_mandate_id)).to be_present
    end
  end

  describe SEPA::CreditTransferTransaction do
    it 'validates the debtor account' do
      transaction = described_class.new(credit_transfer_transaction(debtor_account: SEPA::DebtorAccount.new(name: 'X')))
      expect(transaction.errors_on(:debtor_account)).to include('is not correct')
    end

    it 'requires SLEV for SEPA payments' do
      transaction = described_class.new(credit_transfer_transaction(charge_bearer: 'SHAR'))
      expect(transaction.errors_on(:charge_bearer)).to include('must be SLEV for SEPA payments')
    end

    it 'requires EUR for instant payments' do
      transaction = described_class.new(credit_transfer_transaction(local_instrument: 'INST', currency: 'CHF'))
      expect(transaction.errors_on(:local_instrument)).to include('INST requires EUR')
    end

    it 'rejects an invalid UETR' do
      expect(described_class.new(credit_transfer_transaction(uetr: 'not-a-uuid')).errors_on(:uetr)).to be_present
    end

    it 'needs a 2019 schema for a requested time and the EPC profile for a UETR' do
      timed = described_class.new(credit_transfer_transaction(requested_date: DateTime.new(2099, 1, 2, 9)))
      expect(timed).not_to be_schema_compatible(SEPA::PAIN_001_001_03)
      with_uetr = described_class.new(credit_transfer_transaction(uetr: 'e0a7c8b2-5f3d-4b1a-9c2e-7d8f6a1b3c4d'))
      expect(with_uetr).not_to be_schema_compatible(SEPA::PAIN_001_001_09)
      expect(with_uetr).to be_schema_compatible(SEPA::Schema[SEPA::PAIN_001_001_09, :epc])
    end

    it 'keeps instant payments out of the 2009 DK subsets' do
      instant = described_class.new(credit_transfer_transaction(local_instrument: 'INST'))
      expect(instant).not_to be_schema_compatible(SEPA::PAIN_001_003_03)
      expect(instant).not_to be_schema_compatible(SEPA::PAIN_001_002_03)
    end

    it 'checks the address of a per-transaction debtor account' do
      transaction = described_class.new(credit_transfer_transaction(debtor_account: SEPA::DebtorAccount.new(
        name: 'X', iban: 'NL08RABO0135742099', address: { country_code: 'NL', address_line1: 'Weg 1' }
      )))
      expect(transaction).not_to be_schema_compatible(SEPA::PAIN_001_001_09)
    end

    it 'allows non-SEPA payments only in the EPC profile of pain.001.001.09' do
      transaction = described_class.new(credit_transfer_transaction(currency: 'USD', service_level: nil))
      expect(transaction).not_to be_schema_compatible(SEPA::PAIN_001_001_09)
      expect(transaction).to be_schema_compatible(SEPA::Schema[SEPA::PAIN_001_001_09, :epc])
    end
  end

  describe 'DK subset' do
    it 'does not allow SCT and SCT Inst in one message' do
      message = sct
      message.add_transaction(credit_transfer_transaction)
      message.add_transaction(credit_transfer_transaction(local_instrument: 'INST', reference: 'INST-1'))
      expect(message).not_to be_schema_compatible(SEPA::PAIN_001_001_09)
      expect(message).to be_schema_compatible(SEPA::PAIN_001_001_09, profile: :epc)
    end
  end

  it 'exposes the gem version' do
    expect(SEPA::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end
end
