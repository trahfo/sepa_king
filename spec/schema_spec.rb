# frozen_string_literal: true

RSpec.describe SEPA::Schema do
  it 'knows every schema constant' do
    names = SEPA.constants.grep(/\APAIN_/).map { |c| SEPA.const_get(c) }
    expect(described_class.all.map(&:name)).to match_array(names)
  end

  it 'raises for an unknown schema' do
    expect { described_class['pain.001.001.99'] }.to raise_error(ArgumentError, 'Schema pain.001.001.99 is unknown!')
  end

  it 'rejects unknown features' do
    expect { described_class.new('x', family: :credit_transfer, features: %i[teleport]) }
      .to raise_error(ArgumentError, 'Unknown schema features: teleport')
  end

  it 'reports whether a schema is registered' do
    expect(described_class.registered?(SEPA::PAIN_008_001_08)).to be(true)
    expect(described_class.registered?('pain.008.001.99')).to be(false)
  end

  describe 'pain.008.001.08' do
    subject(:schema) { described_class[SEPA::PAIN_008_001_08] }

    it { expect(schema.family).to eq(:direct_debit) }
    it { expect(schema.bic_tag).to eq(:BICFI) }
    it { expect(schema).to be_iso2019 }
    it { expect(schema).to be_supports(:structured_address) }
    it { expect(schema.to_s).to eq('pain.008.001.08') }

    it 'builds the document attributes' do
      expect(schema.document_attributes).to eq(
        xmlns: 'urn:iso:std:iso:20022:tech:xsd:pain.008.001.08',
        'xmlns:xsi': 'http://www.w3.org/2001/XMLSchema-instance',
        'xsi:schemaLocation': 'urn:iso:std:iso:20022:tech:xsd:pain.008.001.08 pain.008.001.08.xsd'
      )
    end

    it 'parses the XSD only once' do
      first = schema.xsd
      expect(schema.xsd).to be(first)
    end
  end

  describe 'pain.008.001.02' do
    subject(:schema) { described_class[SEPA::PAIN_008_001_02] }

    it { expect(schema.bic_tag).to eq(:BIC) }
    it { expect(schema).not_to be_iso2019 }
  end
end
