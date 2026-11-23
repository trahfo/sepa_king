# frozen_string_literal: true

module SEPA
  # Turns the gem's value objects (transactions, accounts, addresses, parties)
  # into plain hashes for logging and audit trails.
  module Serialization
    # Instance variables that are not data.
    INTERNAL = %i[errors validation_context context_for_validation].freeze

    module_function

    # @param object [Object]
    # @return [Hash, Object] a Hash for SEPA objects, the value itself otherwise
    def to_h(object)
      return object unless object.class.name.to_s.start_with?('SEPA::')

      object.instance_variables.to_h do |ivar|
        [ivar.to_s.delete_prefix('@').to_sym, to_h(object.instance_variable_get(ivar))]
      end.compact.except(*INTERNAL)
    end
  end
end
