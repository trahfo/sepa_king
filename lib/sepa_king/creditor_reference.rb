# frozen_string_literal: true

module SEPA
  # Structured creditor reference according to ISO 11649 ("RF reference").
  module CreditorReference
    module_function

    # @param reference [String] e.g. "RF18 5390 0754 7034"
    def valid?(reference)
      CreditorReferenceValidator.valid?(normalize(reference))
    end

    # Builds an RF reference with check digits from a creditor's own reference.
    # @param base [String] 1 to 21 letters and digits
    # @return [String] e.g. "RF18539007547034" for "539007547034"
    def generate(base)
      base = normalize(base)
      raise ArgumentError, "#{base.inspect} must be 1 to 21 letters or digits" unless base.match?(/\A[A-Z0-9]{1,21}\z/)

      check = 98 - Mod97.remainder("#{base}RF00")
      'RF%<check>02d%<base>s' % { check: check, base: base }
    end

    # @param reference [String, nil]
    # @return [String] without spaces, upper case
    def normalize(reference)
      reference.to_s.delete(' ').upcase
    end
  end
end
