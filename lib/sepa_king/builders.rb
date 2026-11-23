# frozen_string_literal: true

module SEPA
  # XML fragments shared by all messages. Every method receives the target
  # schema and asks it about the differences between ISO 20022 versions.
  module Builders
    private

    # <FinInstnId> of an agent: the BIC, or "NOTPROVIDED" when unknown.
    def build_financial_institution(builder, bic, schema, not_provided: true)
      builder.FinInstnId do
        if bic
          builder.__send__(schema.bic_tag, bic)
        elsif not_provided
          builder.Othr do
            builder.Id('NOTPROVIDED')
          end
        end
      end
    end

    def build_postal_address(builder, address, schema)
      builder.PstlAdr do
        if schema.iso2019?
          build_postal_address24(builder, address)
        else
          build_postal_address6(builder, address)
        end
      end
    end

    def build_postal_address24(builder, address)
      Address::POSTAL_ADDRESS_24.each do |tag, (attribute, _)|
        value = address.public_send(attribute)
        builder.__send__(tag, value) if value
      end
      address.address_lines.each { |line| builder.AdrLine(line) }
    end

    def build_postal_address6(builder, address)
      Address::POSTAL_ADDRESS_6.each do |tag|
        value = address.public_send(Address::POSTAL_ADDRESS_24.fetch(tag).first)
        builder.__send__(tag, value) if value
      end
      address.address_lines.each { |line| builder.AdrLine(line) }
    end

    # <Nm> plus optional <PstlAdr> of a party.
    def build_party(builder, name, address, schema)
      builder.Nm(name)
      build_postal_address(builder, address, schema) if address
    end

    def build_date(builder, tag, date, schema)
      if schema.supports?(:date_choice)
        builder.__send__(tag) do
          builder.Dt(date.iso8601)
        end
      else
        builder.__send__(tag, date.iso8601)
      end
    end
  end
end
