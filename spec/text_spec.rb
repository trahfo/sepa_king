# frozen_string_literal: true

RSpec.describe SEPA::Text do
  after { SEPA.reset_configuration! }

  describe '.convert with the default DK extended set' do
    it 'keeps German umlauts and transliterates other accented letters' do
      expect(described_class.convert('Müller José Çelik Søren Œuvre Łódź')).to eq('Müller Jose Celik Soren OEuvre Lodz')
    end

    it 'still drops punctuation it does not know' do
      expect(described_class.convert('Rechnung! "Nr" <1>; [2]')).to eq('Rechnung Nr 1 2')
    end
  end

  describe '.convert with the EPC basic set' do
    it 'maps umlauts, ß and punctuation' do
      expect(described_class.convert('Größe & Co. [AG] "x"; 5*2 50%', charset: :epc_basic))
        .to eq("Grosse + Co. (AG) 'x', 5.2 50")
    end
  end

  describe 'strict mode' do
    it 'raises for characters that cannot be converted' do
      expect { described_class.convert('Preis: 5 ♥', strict: true) }
        .to raise_error(SEPA::CharacterError, "Character '♥' is not allowed in SEPA messages")
    end

    it 'applies to transactions through the configuration' do
      SEPA.configure { |config| config.strict_charset = true }
      expect { SEPA::DirectDebitTransaction.new(direct_debt_transaction(name: 'Herz ♥')) }
        .to raise_error(SEPA::CharacterError)
    end
  end

  it 'uses the configured charset' do
    SEPA.configure { |config| config.charset = :epc_basic }
    expect(SEPA::Address.new(town_name: 'München').town_name).to eq('Munchen')
  end

  it 'rejects unknown charsets' do
    expect { SEPA.configuration.charset = :klingon }.to raise_error(ArgumentError, /Unknown charset :klingon/)
  end

  describe '.truncate' do
    it 'cuts characters, not bytes' do
      expect(described_class.truncate('Müller', 2)).to eq('Mü')
      expect(described_class.truncate(nil, 2)).to be_nil
    end
  end
end
