# frozen_string_literal: true

module SEPA
  # Account of the creditor of a direct debit, with the creditor identifier
  # (Gläubiger-ID).
  class CreditorAccount < Account
    attr_accessor :creditor_identifier

    validates_with CreditorIdentifierValidator, message: '%{value} is invalid'
  end
end
