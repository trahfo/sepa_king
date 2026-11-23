# frozen_string_literal: true

RSpec.describe SEPA::Address do
  let(:modern_schema) { SEPA::Schema[SEPA::PAIN_008_001_08] }
  let(:legacy_schema) { SEPA::Schema[SEPA::PAIN_008_001_02] }

  describe '.coerce' do
    it 'passes nil and addresses through' do
      address = SEPA::DebtorAddress.new(town_name: 'Wien', country_code: 'AT')
      expect(described_class.coerce(nil)).to be_nil
      expect(described_class.coerce(address)).to be(address)
    end

    it 'builds an address from a Hash' do
      expect(described_class.coerce(town_name: 'Wien', country_code: 'AT').town_name).to eq('Wien')
    end

    it 'rejects other values' do
      expect { described_class.coerce('Wien') }.to raise_error(ArgumentError, '"Wien" is not an address')
    end
  end

  describe '#structured?' do
    it 'needs town and country' do
      expect(described_class.new(town_name: 'Wien', country_code: 'AT')).to be_structured
      expect(described_class.new(town_name: 'Wien')).not_to be_structured
      expect(described_class.new(country_code: 'AT')).not_to be_structured
    end

    it 'does not allow address lines' do
      expect(described_class.new(town_name: 'Wien', country_code: 'AT', address_line1: 'Ring 1')).not_to be_structured
    end
  end

  describe '#schema_compatible?' do
    let(:unstructured) { described_class.new(country_code: 'AT', address_line1: 'Ring 1', address_line2: '1010 Wien') }

    it 'accepts unstructured addresses for 2009 schemas only' do
      expect(unstructured).to be_schema_compatible(legacy_schema)
      expect(unstructured).not_to be_schema_compatible(modern_schema)
    end
  end

  describe 'validation' do
    it 'checks the length of the new PostalAddress24 elements' do
      address = described_class.new(town_name: 'Wien', country_code: 'AT', building_name: 'x' * 36, post_box: 'x' * 17)
      expect(address).not_to be_valid
      expect(address.errors.attribute_names).to contain_exactly(:building_name, :post_box)
    end
  end

  it 'keeps CreditorAddress and DebtorAddress as subclasses' do
    expect(SEPA::CreditorAddress.superclass).to be(described_class)
    expect(SEPA::DebtorAddress.superclass).to be(described_class)
  end
end
