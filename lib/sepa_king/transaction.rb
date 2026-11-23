# frozen_string_literal: true

module SEPA
  # Base class of SEPA::DirectDebitTransaction and SEPA::CreditTransferTransaction.
  class Transaction
    include ActiveModel::Validations
    extend Converter

    # Placeholder for "as soon as possible".
    DEFAULT_REQUESTED_DATE = Date.new(1999, 1, 1).freeze

    attr_accessor :name,
                  :iban,
                  :bic,
                  :amount,
                  :instruction,
                  :reference,
                  :remittance_information,
                  :requested_date,
                  :batch_booking,
                  :currency,
                  :purpose_code
    attr_reader :debtor_address, :creditor_address, :ultimate_debtor, :ultimate_creditor, :creditor_reference

    convert :name, :instruction, :reference, :remittance_information, to: :text
    convert :amount, to: :decimal

    validates_length_of :name, within: 1..70
    validates_length_of :currency, is: 3
    validates_length_of :instruction, within: 1..35, allow_nil: true
    validates_length_of :reference, within: 1..35, allow_nil: true
    validates_length_of :remittance_information, within: 1..140, allow_nil: true
    validates_numericality_of :amount, greater_than: 0
    validates_presence_of :requested_date
    validates_inclusion_of :batch_booking, in: [true, false]
    validates_with BICValidator, IBANValidator, message: '%{value} is invalid'
    validates_with CreditorReferenceValidator, message: '%{value} is invalid'
    validates_length_of :purpose_code, within: 1..4, allow_nil: true

    validate do
      errors.add(:creditor_reference, :sepa_combined_with_remittance_information) if remittance_information && creditor_reference
      %i[ultimate_debtor ultimate_creditor debtor_address creditor_address].each do |attribute|
        value = public_send(attribute)
        errors.add(attribute, value.errors.full_messages.join(', ')) if value && !value.valid?
      end
    end

    def initialize(attributes = {})
      attributes.each do |name, value|
        send("#{name}=", value)
      end

      self.requested_date ||= DEFAULT_REQUESTED_DATE
      self.reference ||= 'NOTPROVIDED'
      self.batch_booking = true if batch_booking.nil?
      self.currency ||= 'EUR'
    end

    # Accepts a DebtorAddress or a Hash of its attributes.
    def debtor_address=(value)
      @debtor_address = value.is_a?(Hash) ? DebtorAddress.new(value) : Address.coerce(value)
    end

    # Accepts a CreditorAddress or a Hash of its attributes.
    def creditor_address=(value)
      @creditor_address = value.is_a?(Hash) ? CreditorAddress.new(value) : Address.coerce(value)
    end

    # Party on whose behalf the debtor pays. Accepts a Party, a Hash or a name.
    def ultimate_debtor=(value)
      @ultimate_debtor = Party.coerce(value)
    end

    # Party that ultimately receives the money. Accepts a Party, a Hash or a name.
    def ultimate_creditor=(value)
      @ultimate_creditor = Party.coerce(value)
    end

    # Structured creditor reference (ISO 11649), e.g. "RF18 5390 0754 7034".
    def creditor_reference=(value)
      @creditor_reference = value && CreditorReference.normalize(value)
    end

    # @return [Hash] the transaction's attributes (nested objects as hashes, without nil values)
    def to_h
      Serialization.to_h(self)
    end

    # Requested date with a time of day (only for schemas with <DtTm>).
    def requested_time?
      requested_date.is_a?(Time) || requested_date.is_a?(DateTime)
    end

    protected

    # Checks shared by all transactions for the 2019 schemas.
    def iso2019_compatible?(schema, counterparty_address)
      [debtor_address, creditor_address, ultimate_debtor, ultimate_creditor].compact
                                                                            .all? { |value| value.schema_compatible?(schema) } &&
        !(schema.supports?(:non_eea_address) && non_eea?(iban) && counterparty_address.nil?)
    end

    def non_eea?(iban)
      NON_EEA_SEPA_COUNTRIES.include?(iban.to_s[0, 2])
    end

    # Ultimate parties must fit the schema (an LEI needs a 2019 schema).
    def parties_compatible?(schema)
      [ultimate_debtor, ultimate_creditor].compact.all? { |party| party.schema_compatible?(schema) }
    end

    # @param min_requested_date [Date] earliest allowed date
    def validate_requested_date_after(min_requested_date)
      return unless requested_date.is_a?(Date) || requested_date.is_a?(Time)

      date = requested_date.to_date
      return unless date != DEFAULT_REQUESTED_DATE && date < min_requested_date

      errors.add(:requested_date, :sepa_too_early, date: min_requested_date)
    end
  end
end
