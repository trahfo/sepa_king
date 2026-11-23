# frozen_string_literal: true

module SEPA
  class DirectDebitTransaction < Transaction
    SEQUENCE_TYPES = %w[FRST OOFF RCUR FNAL].freeze
    LOCAL_INSTRUMENTS = %w[CORE COR1 B2B].freeze

    attr_accessor :mandate_id,
                  :mandate_date_of_signature,
                  :local_instrument,
                  :sequence_type,
                  :creditor_account,
                  :original_debtor_account,
                  :same_mandate_new_debtor_agent,
                  :original_creditor_account,
                  :original_mandate_id,
                  :category_purpose

    class_attribute :cor1_warned, instance_accessor: false, default: false

    validates_with MandateIdentifierValidator, field_name: :mandate_id, message: '%{value} is invalid'
    validates_with MandateIdentifierValidator, field_name: :original_mandate_id, message: '%{value} is invalid',
                                               if: :original_mandate_id
    validates_presence_of :mandate_date_of_signature
    validates_inclusion_of :local_instrument, in: LOCAL_INSTRUMENTS
    validates_inclusion_of :sequence_type, in: SEQUENCE_TYPES
    validates_length_of :category_purpose, within: 1..4, allow_nil: true
    validate { |t| t.validate_requested_date_after(Date.today.next) }

    validate do |t|
      errors.add(:creditor_account, 'is not correct') if creditor_account && !creditor_account.valid?

      if t.mandate_date_of_signature.is_a?(Date)
        errors.add(:mandate_date_of_signature, 'is in the future') if t.mandate_date_of_signature > Date.today
      else
        errors.add(:mandate_date_of_signature, 'is not a Date')
      end
    end

    def initialize(attributes = {})
      super
      self.local_instrument ||= 'CORE'
      self.sequence_type ||= 'OOFF'
      warn_cor1 if local_instrument == 'COR1'
    end

    def amendment_informations?
      original_mandate_id || original_debtor_account || same_mandate_new_debtor_agent || original_creditor_account
    end

    # @param schema [Schema, String] schema or schema name
    def schema_compatible?(schema)
      schema = Schema.resolve(schema)
      return false unless parties_compatible?(schema)

      case schema.name
      when PAIN_008_002_02
        bic.present? && core_or_b2b? && currency == 'EUR'
      when PAIN_008_003_02
        currency == 'EUR'
      when PAIN_008_001_02
        true
      when PAIN_008_001_08
        iso2019_schema_compatible?(schema)
      end
    end

    private

    def core_or_b2b?
      %w[CORE B2B].include?(local_instrument)
    end

    def iso2019_schema_compatible?(schema)
      core_or_b2b? && currency == 'EUR' && iso2019_compatible?(schema, debtor_address) &&
        (creditor_account&.address.nil? || creditor_account.address.schema_compatible?(schema))
    end

    # COR1 was merged into CORE by the EPC in November 2017.
    def warn_cor1
      return if self.class.cor1_warned

      warn '[sepa_king] local_instrument COR1 is obsolete since November 2017 (merged into CORE) and ' \
           'not accepted by the 2019 schemas.', category: :deprecated
      self.class.cor1_warned = true
    end
  end
end
