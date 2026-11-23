# frozen_string_literal: true

module SEPA
  # Describes one supported ISO 20022 message schema: its XML namespace, the
  # vendored XSD used for the final validation and the capabilities builders
  # need to know about. Builders ask the schema instead of comparing names.
  class Schema
    # Capabilities a schema can have:
    #   :bicfi               agent BIC is written as <BICFI> (ISO 2019) instead of <BIC>
    #   :postal_address_24   party addresses use PostalAddress24 (ISO 2019)
    #   :structured_address  only structured addresses (TwnNm + Ctry, no AdrLine) are allowed
    #   :date_choice         requested execution date is wrapped in <Dt> (pain.001.001.09)
    #   :account_bic_required the initiating account needs a BIC
    FEATURES = %i[bicfi postal_address_24 structured_address date_choice account_bic_required].freeze

    attr_reader :name, :family, :namespace, :xsd_file, :features

    class << self
      def register(name, **)
        registry[name] = new(name, **)
      end

      def [](name)
        registry.fetch(name) { raise ArgumentError, "Schema #{name} is unknown!" }
      end

      def registered?(name)
        registry.key?(name)
      end

      def all
        registry.values
      end

      private

      def registry
        @registry ||= {}
      end
    end

    def initialize(name, family:, features: [], namespace: nil, xsd_file: nil, schema_location: nil)
      unknown = features - FEATURES
      raise ArgumentError, "Unknown schema features: #{unknown.join(', ')}" if unknown.any?

      @name = name
      @family = family
      @features = features.freeze
      @namespace = namespace || "urn:iso:std:iso:20022:tech:xsd:#{name}"
      @xsd_file = xsd_file || "#{name}.xsd"
      @schema_location = schema_location || "#{@namespace} #{@xsd_file}"
      @xsd_mutex = Mutex.new
      freeze_ivars
    end

    def supports?(feature)
      features.include?(feature)
    end

    def iso2019?
      supports?(:postal_address_24)
    end

    def bic_tag
      supports?(:bicfi) ? :BICFI : :BIC
    end

    # Attributes of the <Document> root element.
    def document_attributes
      {
        xmlns: namespace,
        'xmlns:xsi': 'http://www.w3.org/2001/XMLSchema-instance',
        'xsi:schemaLocation': @schema_location
      }
    end

    # Parsed XSD, loaded once per schema (thread-safe).
    def xsd
      @xsd_mutex.synchronize do
        @xsd ||= Nokogiri::XML::Schema(File.read(File.expand_path("../schema/#{xsd_file}", __dir__)))
      end
    end

    # @return [Array<String>] XSD validation errors for the given document
    def validate(document)
      xsd.validate(document).map(&:message)
    end

    def to_s
      name
    end

    private

    def freeze_ivars
      @name.freeze
      @namespace.freeze
      @xsd_file.freeze
      @schema_location.freeze
    end
  end
end
