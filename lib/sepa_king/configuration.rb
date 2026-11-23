# frozen_string_literal: true

module SEPA
  # Global settings.
  #
  #   SEPA.configure do |config|
  #     config.charset = :epc_basic      # default :dk_extended
  #     config.strict_charset = true     # raise instead of dropping characters
  #   end
  class Configuration
    # Supported character sets.
    CHARSETS = %i[dk_extended epc_basic].freeze

    # @return [Symbol] character set for text fields: +:dk_extended+ (Latin plus
    #   German umlauts, ß and & * $ %, the default) or +:epc_basic+ (EPC basic
    #   Latin set only)
    attr_reader :charset

    # @return [Boolean] raise SEPA::CharacterError for characters that can be
    #   neither kept nor transliterated, instead of dropping them (default false)
    attr_accessor :strict_charset

    def initialize
      @charset = :dk_extended
      @strict_charset = false
    end

    # @param value [Symbol] one of CHARSETS
    def charset=(value)
      raise ArgumentError, "Unknown charset #{value.inspect} (known: #{CHARSETS.join(', ')})" unless CHARSETS.include?(value)

      @charset = value
    end
  end

  class << self
    # @return [Configuration] the global configuration
    def configuration
      @configuration ||= Configuration.new
    end

    # @yieldparam config [Configuration]
    def configure
      yield configuration
    end

    # Restores the default configuration.
    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
