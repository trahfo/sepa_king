# frozen_string_literal: true

module SEPA
  # Raised when a message cannot be turned into XML (invalid message,
  # incompatible schema or XSD violation).
  class Error < RuntimeError
  end

  # Raised by Message#validate! for an invalid message.
  class ValidationError < Error
    # @return [Array<String>] the full error messages
    attr_reader :errors

    # @param errors [Array<String>]
    def initialize(errors)
      @errors = errors
      super(errors.join("\n"))
    end
  end

  # Raised in strict charset mode for characters that cannot be converted.
  class CharacterError < ArgumentError
  end
end
