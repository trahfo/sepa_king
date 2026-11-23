# frozen_string_literal: true

module SEPA
  # Describes one supported ISO 20022 message schema in one validation profile:
  # its XML namespace, the vendored XSD used for the final validation and the
  # capabilities builders and validations need to know about. Builders ask the
  # schema instead of comparing schema names.
  #
  # A schema name can have several profiles. The 2019 versions have
  #   :dk   (default) Technical Validation Subset of the Deutsche Kreditwirtschaft,
  #         structured addresses only
  #   :epc  generic ISO 20022 XSD plus the EPC rulebook rules in Ruby,
  #         structured or hybrid addresses, UETR
  class Schema
    # Capabilities a schema can have:
    #   :account_bic_required the initiating account needs a BIC
    #   :bicfi                agent BIC is written as <BICFI> (ISO 2019) instead of <BIC>
    #   :postal_address_24    party addresses use PostalAddress24 (ISO 2019)
    #   :structured_address   addresses must be structured (TwnNm + Ctry, no AdrLine)
    #   :hybrid_address       addresses must have TwnNm + Ctry, up to two AdrLine allowed
    #   :non_eea_address      the counterparty address is mandatory for non-EEA SEPA countries
    #   :date_choice          requested execution date is wrapped in <Dt> / <DtTm>
    #   :lei                  party identification may carry an LEI
    #   :uetr                 transactions may carry a UETR
    #   :uniform_local_instrument a message must not mix local instruments (e.g. SCT and SCT Inst)
    FEATURES = %i[
      account_bic_required bicfi postal_address_24 structured_address hybrid_address
      non_eea_address date_choice lei uetr uniform_local_instrument
    ].freeze

    attr_reader :name, :profile, :family, :namespace, :xsd_file, :features

    class << self
      def register(name, profile: :default, **)
        (registry[name] ||= {})[profile] = new(name, profile: profile, **)
      end

      # @param name [String] schema name, e.g. 'pain.008.001.08'
      # @param profile [Symbol, nil] validation profile, the schema's first one by default
      def [](name, profile = nil)
        profiles = registry.fetch(name) { raise ArgumentError, "Schema #{name} is unknown!" }
        return profiles.values.first if profile.nil?

        profiles.fetch(profile.to_sym) do
          raise ArgumentError, "Profile #{profile} is unknown for schema #{name} (known: #{profiles.keys.join(', ')})"
        end
      end

      # Accepts a Schema or a schema name.
      def resolve(schema_or_name, profile = nil)
        schema_or_name.is_a?(Schema) ? schema_or_name : self[schema_or_name, profile]
      end

      def registered?(name)
        registry.key?(name)
      end

      def profiles(name)
        self[name] # raises for unknown names
        registry[name].keys
      end

      def all
        registry.values.flat_map(&:values)
      end

      private

      def registry
        @registry ||= {}
      end
    end

    def initialize(name, family:, profile: :default, features: [], namespace: nil, xsd_file: nil,
                   schema_location: nil)
      unknown = features - FEATURES
      raise ArgumentError, "Unknown schema features: #{unknown.join(', ')}" if unknown.any?

      @name = name.freeze
      @profile = profile
      @family = family
      @features = features.freeze
      @namespace = (namespace || "urn:iso:std:iso:20022:tech:xsd:#{name}").freeze
      @xsd_file = (xsd_file || "#{name}.xsd").freeze
      @schema_location = (schema_location || "#{@namespace} #{name}.xsd").freeze
      @xsd_mutex = Mutex.new
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
      profile == :default ? name : "#{name} (#{profile})"
    end
  end
end
