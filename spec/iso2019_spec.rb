# frozen_string_literal: true

RSpec.describe 'ISO 20022 version 2019 schemas' do
  def creditor(**opts)
    SEPA::DirectDebit.new({ name: 'Gläubiger GmbH', bic: 'BANKDEFFXXX', iban: 'DE87200500001234567890',
                            creditor_identifier: 'DE98ZZZ09999999999' }.merge(opts))
  end

  def debtor(**opts)
    SEPA::CreditTransfer.new({ name: 'Schuldner GmbH', bic: 'BANKDEFFXXX',
                               iban: 'DE87200500001234567890' }.merge(opts))
  end

  describe 'pain.008.001.08' do
    it 'writes BICFI and validates against the XSD' do
      sdd = creditor
      sdd.add_transaction(direct_debt_transaction)
      xml = sdd.to_xml(SEPA::PAIN_008_001_08)
      expect(xml).to validate_against('pain.008.001.08.xsd')
      expect(xml).to have_xml('//CdtrAgt/FinInstnId/BICFI', 'BANKDEFFXXX')
      expect(xml).to have_xml('//DbtrAgt/FinInstnId/BICFI', 'GENODEF1JEV')
    end

    it 'writes the creditor address' do
      sdd = creditor(address: { town_name: 'Wien', country_code: 'AT' })
      sdd.add_transaction(direct_debt_transaction)
      expect(sdd.to_xml(SEPA::PAIN_008_001_08)).to have_xml('//PmtInf/Cdtr/PstlAdr/TwnNm', 'Wien')
    end

    {
      'COR1' => { local_instrument: 'COR1' },
      'a currency other than EUR' => { currency: 'CHF' },
      'an unstructured debtor address' => { debtor_address: { country_code: 'CH', address_line1: 'Weg 1' } },
      'an unstructured creditor account address' => {
        creditor_account: SEPA::CreditorAccount.new(name: 'Zweitgläubiger AG', iban: 'NL08RABO0135742099',
                                                    creditor_identifier: 'NL53ZZZ091734220000',
                                                    address: { country_code: 'NL', address_line1: 'Weg 1' })
      }
    }.each do |description, attributes|
      it "is incompatible with #{description}" do
        sdd = creditor
        sdd.add_transaction(direct_debt_transaction(attributes))
        expect(sdd).not_to be_schema_compatible(SEPA::PAIN_008_001_08)
        expect { sdd.to_xml(SEPA::PAIN_008_001_08) }.to raise_error(SEPA::Error, /Incompatible with schema/)
      end
    end

    it 'is incompatible with an unstructured creditor address' do
      sdd = creditor(address: { country_code: 'DE', address_line1: 'Weg 1' })
      sdd.add_transaction(direct_debt_transaction)
      expect(sdd).not_to be_schema_compatible(SEPA::PAIN_008_001_08)
      expect(sdd).to be_schema_compatible(SEPA::PAIN_008_001_02)
    end

    it 'is invalid with an invalid creditor address' do
      sdd = creditor(address: { town_name: 'x' * 36, country_code: 'AT' })
      sdd.add_transaction(direct_debt_transaction)
      expect(sdd).not_to be_valid
      expect(sdd.errors[:account]).to be_present
    end
  end

  describe 'pain.001.001.09' do
    it 'writes BICFI, ReqdExctnDt/Dt and validates against the XSD' do
      sct = debtor
      sct.add_transaction(credit_transfer_transaction(requested_date: Date.new(2099, 1, 2)))
      xml = sct.to_xml(SEPA::PAIN_001_001_09)
      expect(xml).to validate_against('pain.001.001.09.xsd')
      expect(xml).to have_xml('//ReqdExctnDt/Dt', '2099-01-02')
      expect(xml).to have_xml('//DbtrAgt/FinInstnId/BICFI', 'BANKDEFFXXX')
      expect(xml).to have_xml('//CdtrAgt/FinInstnId/BICFI', 'PBNKDEFF370')
    end

    it 'writes the debtor address' do
      sct = debtor(address: { town_name: 'München', country_code: 'DE' })
      sct.add_transaction(credit_transfer_transaction)
      expect(sct.to_xml(SEPA::PAIN_001_001_09)).to have_xml('//PmtInf/Dbtr/PstlAdr/Ctry', 'DE')
    end

    {
      'urgent payments' => { service_level: 'URGP' },
      'a currency other than EUR' => { currency: 'CHF' },
      'an unstructured creditor address' => { creditor_address: { country_code: 'CH', address_line1: 'Weg 1' } }
    }.each do |description, attributes|
      it "is incompatible with #{description}" do
        sct = debtor
        sct.add_transaction(credit_transfer_transaction(attributes))
        expect(sct).not_to be_schema_compatible(SEPA::PAIN_001_001_09)
      end
    end
  end

  describe 'addresses given as Hash' do
    it 'builds the matching address class' do
      dd = SEPA::DirectDebitTransaction.new(direct_debt_transaction(debtor_address: { town_name: 'Wien',
                                                                                      country_code: 'AT' }))
      ct = SEPA::CreditTransferTransaction.new(credit_transfer_transaction(creditor_address: { town_name: 'Wien',
                                                                                               country_code: 'AT' }))
      expect(dd.debtor_address).to be_a(SEPA::DebtorAddress)
      expect(ct.creditor_address).to be_a(SEPA::CreditorAddress)
    end
  end

  describe 'default schema' do
    around do |example|
      SEPA::DirectDebit.default_schema_warned = false
      deprecated = Warning[:deprecated]
      Warning[:deprecated] = true
      example.run
    ensure
      Warning[:deprecated] = deprecated
    end

    it 'stays the 2009 schema and warns once about the upcoming change' do
      sdd = creditor
      sdd.add_transaction(direct_debt_transaction)
      expect { sdd.to_xml }.to output(/default will change to the ISO 2019 schema/).to_stderr
      expect { sdd.to_xml }.not_to output.to_stderr
      expect(sdd.to_xml).to include('pain.008.001.02')
    end
  end
end
