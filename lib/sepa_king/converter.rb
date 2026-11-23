# frozen_string_literal: true

module SEPA
  # Declares attribute writers that normalise their input, e.g.
  # +convert :name, to: :text+ (see SEPA::Text) or +to: :decimal+.
  module Converter
    # @param attributes [Array<Symbol>] attribute names
    # @param options [Hash] +:to+ => +:text+ or +:decimal+
    def convert(*attributes, options)
      include InstanceMethods

      method_name = "convert_#{options[:to]}"
      unless InstanceMethods.method_defined?(method_name)
        raise ArgumentError, "Converter '#{options[:to]}' does not exist!"
      end

      attributes.each do |attribute|
        define_method "#{attribute}=" do |value|
          instance_variable_set("@#{attribute}", send(method_name, value))
        end
      end
    end

    # The conversion functions used by the generated writers.
    module InstanceMethods
      # @see SEPA::Text.convert
      def convert_text(value)
        Text.convert(value)
      end

      # @param value [Numeric, String, nil]
      # @return [BigDecimal, nil] the positive amount rounded to two decimals, nil otherwise
      def convert_decimal(value)
        return unless value

        value = BigDecimal(value.to_s, exception: false)

        return unless value&.finite? && value.positive?

        value.round(2)
      end
    end
  end
end
