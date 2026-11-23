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

    ADDRESS_LINES = %i[address_line1 address_line2].freeze

    ATTRIBUTES = (POSTAL_ADDRESS_24.values.map(&:first) + ADDRESS_LINES).freeze

    attr_accessor(*ATTRIBUTES)

    convert(*ATTRIBUTES, to: :text)

    POSTAL_ADDRESS_24.each_value do |attribute, maximum|
      next if attribute == :country_code

      validates_length_of attribute, maximum: maximum
    end
    validates_length_of :country_code, is: 2
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

    def address_lines
      ADDRESS_LINES.filter_map { |attribute| public_send(attribute) }
    end

    # Town and country present, no free-text address lines.
    def structured?
      town_name.present? && country_code.present? && address_lines.empty?
    end

    # The 2019 schemas only accept structured addresses.
    def schema_compatible?(schema)
      !schema.supports?(:structured_address) || structured?
    end
  end
end
