# frozen_string_literal: true

module SEPA
  # Identification of a party (<Id>): an organisation (BIC, LEI and/or other
  # identifier) or a private person (other identifier).
  class PartyIdentification
    include ActiveModel::Validations
    extend Converter

    TYPES = %i[organisation private].freeze

    attr_accessor :bic, :lei, :id, :scheme_code, :scheme_proprietary, :issuer
    attr_reader :type

    convert :id, :scheme_proprietary, :issuer, to: :text

    validates_inclusion_of :type, in: TYPES
    validates_with BICValidator, message: '%{value} is invalid'
    validates_with LEIValidator, message: '%{value} is invalid'
    validates_length_of :id, within: 1..35, allow_nil: true
    validates_length_of :scheme_code, within: 1..4, allow_nil: true
    validates_length_of :scheme_proprietary, within: 1..35, allow_nil: true
    validates_length_of :issuer, within: 1..35, allow_nil: true

    validate do
      errors.add(:base, 'needs a BIC, an LEI or an id') if [bic, lei, id].all?(&:nil?)
      errors.add(:base, 'BIC and LEI are only allowed for organisations') if type == :private && (bic || lei)
      errors.add(:base, 'scheme_code and scheme_proprietary are exclusive') if scheme_code && scheme_proprietary
      errors.add(:base, 'a scheme needs an id') if (scheme_code || scheme_proprietary || issuer) && id.nil?
    end

    def initialize(attributes = {})
      self.type = :organisation
      attributes.each do |name, value|
        public_send("#{name}=", value)
      end
    end

    def type=(value)
      @type = value&.to_sym
    end

    def self.coerce(value)
      case value
      when nil, PartyIdentification then value
      when Hash then new(value)
      else raise ArgumentError, "#{value.inspect} is not a party identification"
      end
    end

    def organisation?
      type == :organisation
    end

    def schema_compatible?(schema)
      lei.nil? || schema.supports?(:lei)
    end
  end
end
