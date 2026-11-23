# frozen_string_literal: true

module SEPA
  class Account
    include ActiveModel::Validations
    extend Converter

    attr_accessor :name, :iban, :bic
    attr_reader :address

    convert :name, to: :text

    validates_length_of :name, within: 1..70
    validates_with BICValidator, IBANValidator, message: '%{value} is invalid'
    validate { errors.add(:address, :invalid) if address && !address.valid? }

    def initialize(attributes = {})
      attributes.each do |name, value|
        public_send("#{name}=", value)
      end
    end

    # Postal address of the account holder (creditor of a direct debit,
    # debtor of a credit transfer). Accepts an Address or a Hash.
    def address=(value)
      @address = Address.coerce(value)
    end
  end
end
