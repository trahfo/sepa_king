# frozen_string_literal: true

module SEPA
  class IBANValidator < ActiveModel::Validator
    # IBAN2007Identifier (taken from schema)
    REGEX = /\A[A-Z]{2,2}[0-9]{2,2}[a-zA-Z0-9]{1,30}\z/

    def validate(record)
      field_name = options[:field_name] || :iban
      value = record.send(field_name).to_s

      return if IBANTools::IBAN.valid?(value) && value.match?(REGEX)

      record.errors.add(field_name, :invalid, message: options[:message])
    end
  end

  class BICValidator < ActiveModel::Validator
    # AnyBICIdentifier (taken from schema)
    REGEX = /\A[A-Z]{6,6}[A-Z2-9][A-NP-Z0-9]([A-Z0-9]{3,3}){0,1}\z/

    def validate(record)
      field_name = options[:field_name] || :bic
      value = record.send(field_name)

      return unless value
      return if value.to_s.match?(REGEX)

      record.errors.add(field_name, :invalid, message: options[:message])
    end
  end

  class CreditorIdentifierValidator < ActiveModel::Validator
    REGEX = %r{\A
      [a-zA-Z]{2}                 # ISO country code
      [0-9]{2}                    # Check digits
      [A-Za-z0-9]{3}              # Creditor business code
      [A-Za-z0-9+?/:().,'-]{1,28} # National identifier
    \z}x

    def validate(record)
      field_name = options[:field_name] || :creditor_identifier
      value = record.send(field_name)

      return if valid?(value)

      record.errors.add(field_name, :invalid, message: options[:message])
    end

    def valid?(creditor_identifier)
      if (ok = creditor_identifier.to_s.match?(REGEX)) && creditor_identifier[0..1].match?(/DE/i)
        # In Germany, the identifier has to be exactly 18 chars long
        ok = creditor_identifier.length == 18
      end
      ok
    end
  end

  class MandateIdentifierValidator < ActiveModel::Validator
    REGEX = %r{\A[A-Za-z0-9 +?/:().,'-]{1,35}\z}

    def validate(record)
      field_name = options[:field_name] || :mandate_id
      value = record.send(field_name)

      return if value.to_s.match?(REGEX)

      record.errors.add(field_name, :invalid, message: options[:message])
    end
  end

  # ISO 7064 MOD 97-10 check used by LEI (ISO 17442) and RF creditor references (ISO 11649).
  module Mod97
    module_function

    def remainder(value)
      value.chars.map { |char| char.to_i(36).to_s }.join.to_i % 97
    end
  end

  # Legal Entity Identifier (ISO 17442): 18 alphanumerics plus 2 check digits.
  class LEIValidator < ActiveModel::Validator
    REGEX = /\A[A-Z0-9]{18}[0-9]{2}\z/

    def self.valid?(value)
      value.to_s.match?(REGEX) && Mod97.remainder(value) == 1
    end

    def validate(record)
      field_name = options[:field_name] || :lei
      value = record.send(field_name)
      return if value.nil? || self.class.valid?(value)

      record.errors.add(field_name, :invalid, message: options[:message])
    end
  end

  # Structured creditor reference (ISO 11649), e.g. "RF18539007547034".
  class CreditorReferenceValidator < ActiveModel::Validator
    REGEX = /\ARF[0-9]{2}[A-Z0-9]{1,21}\z/

    def self.valid?(value)
      value.to_s.match?(REGEX) && Mod97.remainder(value[4..] + value[0, 4]) == 1
    end

    def validate(record)
      field_name = options[:field_name] || :creditor_reference
      value = record.send(field_name)
      return if value.nil? || self.class.valid?(value)

      record.errors.add(field_name, :invalid, message: options[:message])
    end
  end

  # Unique end-to-end transaction reference, a UUID version 4.
  class UETRValidator < ActiveModel::Validator
    REGEX = /\A[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}\z/

    def validate(record)
      field_name = options[:field_name] || :uetr
      value = record.send(field_name)
      return if value.nil? || value.to_s.match?(REGEX)

      record.errors.add(field_name, :invalid, message: options[:message])
    end
  end
end
