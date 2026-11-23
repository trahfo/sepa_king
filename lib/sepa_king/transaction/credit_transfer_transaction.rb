# frozen_string_literal: true

module SEPA
  class CreditTransferTransaction < Transaction
    LOCAL_INSTRUMENTS = %w[INST].freeze
    INSTRUCTION_PRIORITIES = %w[HIGH NORM].freeze
    CHARGE_BEARERS = %w[DEBT CRED SHAR SLEV].freeze

    attr_accessor :service_level,
                  :category_purpose,
                  :local_instrument,
                  :instruction_priority,
                  :charge_bearer,
                  :debtor_account,
                  :uetr

    validates_inclusion_of :service_level, in: %w[SEPA URGP], allow_nil: true
    validates_length_of :category_purpose, within: 1..4, allow_nil: true
    validates_inclusion_of :local_instrument, in: LOCAL_INSTRUMENTS, allow_nil: true
    validates_inclusion_of :instruction_priority, in: INSTRUCTION_PRIORITIES, allow_nil: true
    validates_inclusion_of :charge_bearer, in: CHARGE_BEARERS, allow_nil: true
    validates_with UETRValidator, message: '%{value} is invalid'

    validate { |t| t.validate_requested_date_after(Date.today) }
    validate do
      errors.add(:debtor_account, 'is not correct') if debtor_account && !debtor_account.valid?
      errors.add(:charge_bearer, 'must be SLEV for SEPA payments') if service_level == 'SEPA' && charge_bearer && charge_bearer != 'SLEV'
      errors.add(:local_instrument, 'INST requires EUR') if instant? && currency != 'EUR'
    end

    def initialize(attributes = {})
      super
      self.service_level ||= 'SEPA' if currency == 'EUR'
    end

    # SEPA Instant Credit Transfer
    def instant?
      local_instrument == 'INST'
    end

    # @param schema [Schema, String] schema or schema name
    def schema_compatible?(schema)
      schema = Schema.resolve(schema)
      return false unless parties_compatible?(schema)
      return false if uetr && !schema.supports?(:uetr)
      return false if requested_time? && !schema.supports?(:date_choice)

      schema.iso2019? ? iso2019_schema_compatible?(schema) : iso2009_schema_compatible?(schema.name)
    end

    private

    def iso2009_schema_compatible?(schema_name)
      case schema_name
      when PAIN_001_001_03
        !service_level || sepa?
      when PAIN_001_002_03
        bic.present? && sepa? && !instant?
      when PAIN_001_003_03
        currency == 'EUR' && !instant?
      when PAIN_001_001_03_CH_02
        currency == 'CHF'
      end
    end

    def sepa?
      service_level == 'SEPA' && currency == 'EUR'
    end

    def iso2019_schema_compatible?(schema)
      # The DK subset only covers SEPA payments; the generic ISO profile also allows others.
      (sepa? || (schema.profile == :epc && !service_level)) &&
        iso2019_compatible?(schema, creditor_address) &&
        (debtor_account&.address.nil? || debtor_account.address.schema_compatible?(schema))
    end
  end
end
