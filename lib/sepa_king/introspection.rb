# frozen_string_literal: true

module SEPA
  # Inspecting a message without building XML: validation with exceptions,
  # a per-batch summary and a plain Hash for logging or audit trails.
  module Introspection
    # @return [true]
    # @raise [SEPA::ValidationError] with all error messages if the message is invalid
    def validate!
      raise ValidationError, errors.full_messages unless valid?

      true
    end

    # One entry per payment information block (<PmtInf>).
    # @return [Array<Hash>] +:id+, +:requested_date+, +:count+ and +:amount+ per batch
    def batches_summary
      grouped_transactions.map do |group, transactions|
        { id: payment_information_identification(group), requested_date: group[:requested_date],
          count: transactions.size, amount: amount_total(transactions) }
      end
    end

    # Schema-independent representation, e.g. for logging or an audit trail.
    # @return [Hash]
    def to_h
      { message_identification: message_identification, creation_date_time: creation_date_time,
        count: transactions.size, amount: amount_total,
        account: Serialization.to_h(account), initiating_party: Serialization.to_h(initiating_party),
        batches: batches_summary.zip(grouped_transactions.values).map do |summary, transactions|
          summary.merge(transactions: transactions.map(&:to_h))
        end }
    end
  end
end
