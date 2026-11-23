# frozen_string_literal: true

RSpec.describe 'Edge cases' do
  describe SEPA::Converter do
    it 'rejects an unknown converter' do
      expect do
        Class.new do
          extend SEPA::Converter

          convert :foo, to: :unknown
        end
      end.to raise_error(ArgumentError, "Converter 'unknown' does not exist!")
    end
  end

  describe SEPA::Message do
    it 'rejects an unknown schema in schema_compatible?' do
      sdd = SEPA::DirectDebit.new(name: 'Gläubiger GmbH', iban: 'DE87200500001234567890',
                                  creditor_identifier: 'DE98ZZZ09999999999')
      expect { sdd.schema_compatible?('pain.001.001.03') }
        .to raise_error(ArgumentError, 'Schema pain.001.001.03 is unknown!')
    end
  end

  describe SEPA::Transaction do
    it 'skips the requested date check when the value is not a Date' do
      transaction = SEPA::CreditTransferTransaction.new(credit_transfer_transaction(requested_date: '2013-09-05'))
      transaction.valid?
      expect(transaction.errors[:requested_date]).to be_empty
    end
  end

  describe SEPA::CreditTransferTransaction do
    it 'is not compatible with a direct debit schema' do
      expect(described_class.new(credit_transfer_transaction)
        .schema_compatible?('pain.008.001.02')).to be_nil
    end
  end

  describe SEPA::DirectDebitTransaction do
    it 'is invalid with an invalid creditor account' do
      transaction = described_class.new(direct_debt_transaction(
                                          creditor_account: SEPA::CreditorAccount.new(name: 'X',
                                                                                      iban: 'invalid', creditor_identifier: 'invalid')
                                        ))
      expect(transaction).not_to be_valid
      expect(transaction.errors[:creditor_account]).to include('is not correct')
    end
  end

  describe 'amendment with partial original creditor account' do
    def message_with(original_creditor_account)
      sdd = SEPA::DirectDebit.new(name: 'Gläubiger GmbH', bic: 'BANKDEFFXXX', iban: 'DE87200500001234567890',
                                  creditor_identifier: 'DE98ZZZ09999999999')
      sdd.add_transaction(direct_debt_transaction(original_creditor_account: original_creditor_account))
      sdd.to_xml('pain.008.001.02')
    end

    it 'omits the name when not given' do
      xml = message_with(SEPA::CreditorAccount.new(creditor_identifier: 'NL04ZZZ987654320000'))
      expect(xml).to have_xml('//OrgnlCdtrSchmeId/Id/PrvtId/Othr/Id', 'NL04ZZZ987654320000')
      expect(xml).not_to have_xml('//OrgnlCdtrSchmeId/Nm')
    end

    it 'omits the identifier when not given' do
      xml = message_with(SEPA::CreditorAccount.new(name: 'Alter Gläubiger'))
      expect(xml).to have_xml('//OrgnlCdtrSchmeId/Nm', 'Alter Gläubiger')
      expect(xml).not_to have_xml('//OrgnlCdtrSchmeId/Id')
    end
  end

  describe 'address with a single line and no country' do
    it 'renders one AdrLine for a debtor' do
      sdd = SEPA::DirectDebit.new(name: 'Gläubiger GmbH', iban: 'DE87200500001234567890',
                                  creditor_identifier: 'DE98ZZZ09999999999')
      sdd.add_transaction(direct_debt_transaction(
                            debtor_address: SEPA::DebtorAddress.new(address_line1: 'Musterweg 1')
                          ))
      xml = sdd.to_xml('pain.008.001.02')
      expect(Nokogiri::XML(xml).remove_namespaces!.xpath('//Dbtr/PstlAdr/AdrLine').size).to eq(1)
    end

    it 'renders one AdrLine for a creditor' do
      sct = SEPA::CreditTransfer.new(name: 'Schuldner GmbH', iban: 'DE87200500001234567890')
      sct.add_transaction(credit_transfer_transaction(
                            creditor_address: SEPA::CreditorAddress.new(address_line1: 'Musterweg 1')
                          ))
      xml = sct.to_xml('pain.001.001.03')
      expect(Nokogiri::XML(xml).remove_namespaces!.xpath('//Cdtr/PstlAdr/AdrLine').size).to eq(1)
    end
  end
end
