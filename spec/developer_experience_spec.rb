# frozen_string_literal: true

RSpec.describe 'Developer helpers' do
  let(:sdd) do
    message = SEPA::DirectDebit.new(name: 'Gläubiger GmbH', bic: 'BANKDEFFXXX', iban: 'DE87200500001234567890',
                                    creditor_identifier: 'DE98ZZZ09999999999')
    message.message_identification = 'DX/1'
    message.add_transaction(direct_debt_transaction(amount: 10, sequence_type: 'FRST'))
    message.add_transaction(direct_debt_transaction(amount: 2.5, sequence_type: 'RCUR'))
    message
  end

  describe '#validate!' do
    it 'returns true for a valid message' do
      expect(sdd.validate!).to be(true)
    end

    it 'raises with all messages' do
      expect { SEPA::DirectDebit.new(name: 'X').validate! }.to raise_error(SEPA::ValidationError) { |error|
        expect(error.errors).to include("Transactions can't be blank")
      }
    end
  end

  it 'summarises the batches' do
    expect(sdd.batches_summary).to eq([
                                        { id: 'DX/1/1', requested_date: Date.today + 1, count: 1, amount: 10 },
                                        { id: 'DX/1/2', requested_date: Date.today + 1, count: 1, amount: 2.5 }
                                      ])
  end

  it 'serialises to a Hash' do
    hash = sdd.to_h
    expect(hash).to include(message_identification: 'DX/1', count: 2, amount: 12.5)
    expect(hash[:account]).to include(name: 'Gläubiger GmbH', creditor_identifier: 'DE98ZZZ09999999999')
    expect(hash[:batches].first[:transactions].first).to include(mandate_id: 'K-08-2010-42123', sequence_type: 'FRST')
    expect(hash[:batches].first[:transactions].first).not_to have_key(:errors)
  end

  describe '#to_xml options' do
    it 'writes compact XML' do
      xml = sdd.to_xml(SEPA::PAIN_008_001_08, pretty: false)
      expect(xml).not_to include("\n  ")
      expect(xml).to validate_against('pain.008.001.08.xsd')
    end

    it 'can skip the XSD check' do
      schema = SEPA::Schema[SEPA::PAIN_008_001_08]
      allow(schema).to receive(:validate).and_call_original
      sdd.to_xml(SEPA::PAIN_008_001_08, validate: false)
      expect(schema).not_to have_received(:validate)
    end
  end

  it 'translates its own error messages' do
    I18n.with_locale(:de) do
      transaction = SEPA::DirectDebitTransaction.new(direct_debt_transaction(mandate_date_of_signature: Date.today + 1))
      expect(transaction.errors_on(:mandate_date_of_signature)).to include('liegt in der Zukunft')
    end
  end
end
