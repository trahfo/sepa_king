# frozen_string_literal: true

module SEPA
  # A party other than the account holders: initiating party, ultimate debtor
  # or ultimate creditor. Name, optional postal address and identification.
  class Party
    include ActiveModel::Validations
    extend Converter

    attr_accessor :name
    attr_reader :address, :identification

    convert :name, to: :text

    validates_length_of :name, within: 1..70, allow_nil: true
    validate do
      errors.add(:base, 'needs a name or an identification') if name.nil? && identification.nil?
      errors.add(:address, :invalid) if address && !address.valid?
      errors.add(:identification, identification.errors.full_messages.join(', ')) if identification && !identification.valid?
    end

    def initialize(attributes = {})
      attributes.each do |name, value|
        public_send("#{name}=", value)
      end
    end

    def address=(value)
      @address = Address.coerce(value)
    end

    def identification=(value)
      @identification = PartyIdentification.coerce(value)
    end

    # Builds a party from a Party, a Hash of attributes or just a name.
    def self.coerce(value)
      case value
      when nil, Party then value
      when Hash then new(value)
      when String then new(name: value)
      else raise ArgumentError, "#{value.inspect} is not a party"
      end
    end

    # The DK subsets do not allow a postal address on initiating or ultimate parties.
    def schema_compatible?(schema)
      (address.nil? || (!schema.supports?(:structured_address) && address.schema_compatible?(schema))) &&
        (identification.nil? || identification.schema_compatible?(schema))
    end
  end
end
