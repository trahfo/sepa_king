# frozen_string_literal: true

module SEPA
  # A postal address with all elements of ISO 20022 PostalAddress24.
  #
  # The 2009 schemas (pain.001.001.03, pain.008.001.02 …) only render the
  # elements they know (PostalAddress6). The 2019 schemas render the full set
  # and, following the EPC rulebooks from November 2026, require a structured
  # address: at least +town_name+ and +country_code+, without address lines.
  class Address
    include ActiveModel::Validations
    extend Converter

    # Element name => [attribute, maximum length], in schema order.
    POSTAL_ADDRESS_24 = {
      Dept: [:department, 70],
      SubDept: [:sub_department, 70],
      StrtNm: [:street_name, 70],
      BldgNb: [:building_number, 16],
      BldgNm: [:building_name, 35],
      Flr: [:floor, 70],
      PstBx: [:post_box, 16],
      Room: [:room, 70],
      PstCd: [:post_code, 16],
      TwnNm: [:town_name, 35],
      TwnLctnNm: [:town_location_name, 35],
      DstrctNm: [:district_name, 35],
      CtrySubDvsn: [:country_sub_division, 35],
      Ctry: [:country_code, 2]
    }.freeze

    # Elements of the 2009 PostalAddress6 written by this gem, in schema order.
    POSTAL_ADDRESS_6 = %i[Dept SubDept StrtNm BldgNb PstCd TwnNm CtrySubDvsn Ctry].freeze

    # Attributes written as <AdrLine>.
    ADDRESS_LINES = %i[address_line1 address_line2].freeze

    # All attributes of an address.
    ATTRIBUTES = (POSTAL_ADDRESS_24.values.map(&:first) + ADDRESS_LINES).freeze

    # @!attribute [rw] department
    #   @return [String, nil] <Dept>, max. 70 characters
    # @!attribute [rw] sub_department
    #   @return [String, nil] <SubDept>, max. 70 characters
    # @!attribute [rw] street_name
    #   @return [String, nil] <StrtNm>, max. 70 characters
    # @!attribute [rw] building_number
    #   @return [String, nil] <BldgNb>, max. 16 characters
    # @!attribute [rw] building_name
    #   @return [String, nil] <BldgNm>, max. 35 characters
    # @!attribute [rw] floor
    #   @return [String, nil] <Flr>, max. 70 characters
    # @!attribute [rw] post_box
    #   @return [String, nil] <PstBx>, max. 16 characters
    # @!attribute [rw] room
    #   @return [String, nil] <Room>, max. 70 characters
    # @!attribute [rw] post_code
    #   @return [String, nil] <PstCd>, max. 16 characters
    # @!attribute [rw] town_name
    #   @return [String, nil] <TwnNm>, max. 35 characters
    # @!attribute [rw] town_location_name
    #   @return [String, nil] <TwnLctnNm>, max. 35 characters
    # @!attribute [rw] district_name
    #   @return [String, nil] <DstrctNm>, max. 35 characters
    # @!attribute [rw] country_sub_division
    #   @return [String, nil] <CtrySubDvsn>, max. 35 characters
    # @!attribute [rw] country_code
    #   @return [String, nil] <Ctry>, max. 2 characters
    # @!attribute [rw] address_line1
    #   @return [String, nil] <AdrLine>, max. 70 characters
    # @!attribute [rw] address_line2
    #   @return [String, nil] <AdrLine>, max. 70 characters
    attr_accessor(*ATTRIBUTES)

    convert(*ATTRIBUTES, to: :text)

    POSTAL_ADDRESS_24.each_value do |attribute, maximum|
      next if attribute == :country_code

      validates_length_of attribute, maximum: maximum
    end
    validates_length_of :country_code, is: 2, allow_nil: true
    validates_length_of :address_line1, maximum: 70
    validates_length_of :address_line2, maximum: 70

    def initialize(attributes = {})
      attributes.each do |name, value|
        public_send("#{name}=", value)
      end
    end

    # Builds an address from another address or a Hash of attributes.
    def self.coerce(value)
      case value
      when nil, Address then value
      when Hash then new(value)
      else raise ArgumentError, "#{value.inspect} is not an address"
      end
    end

    # @return [Array<String>] the given address lines
    def address_lines
      ADDRESS_LINES.filter_map { |attribute| public_send(attribute) }
    end

    # Town and country present, no free-text address lines.
    def structured?
      town_name.present? && country_code.present? && address_lines.empty?
    end

    # Town and country present, at most two address lines (EPC "hybrid" address).
    def hybrid?
      town_name.present? && country_code.present?
    end

    # The 2019 schemas only accept structured (DK profile) or structured and
    # hybrid (EPC profile) addresses.
    def schema_compatible?(schema)
      if schema.supports?(:structured_address)
        structured?
      elsif schema.supports?(:hybrid_address)
        hybrid?
      else
        true
      end
    end
  end
end
