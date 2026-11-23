# frozen_string_literal: true

module SEPA
  # XML fragments shared by all messages. Every method receives the target
  # schema and asks it about the differences between ISO 20022 versions.
  module Builders
    include PartyBuilders

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

    # <PmtId>: instruction id, end-to-end id and (credit transfers) UETR.
    def build_payment_identification(builder, transaction)
      builder.PmtId do
        builder.InstrId(transaction.instruction) if transaction.instruction.present?
        builder.EndToEndId(transaction.reference)
        builder.UETR(transaction.uetr) if transaction.respond_to?(:uetr) && transaction.uetr
      end
    end

    # <Nm> plus optional <PstlAdr> of an account holder.
    def build_name_and_address(builder, name, address, schema)
      builder.Nm(name)
      build_postal_address(builder, address, schema) if address
    end

    # <Dt> or <DtTm> for schemas with a date choice, the plain date otherwise.
    def build_date(builder, tag, date, schema)
      if schema.supports?(:date_choice)
        builder.__send__(tag) do
          if date.is_a?(Time) || date.is_a?(DateTime)
            builder.DtTm(date.iso8601)
          else
            builder.Dt(date.iso8601)
          end
        end
      else
        builder.__send__(tag, date.iso8601)
      end
    end

    def build_purpose(builder, transaction)
      return unless transaction.purpose_code

      builder.Purp do
        builder.Cd(transaction.purpose_code)
      end
    end

    # <RmtInf>: unstructured text or a structured ISO 11649 creditor reference.
    def build_remittance_information(builder, transaction)
      if transaction.remittance_information
        builder.RmtInf do
          builder.Ustrd(transaction.remittance_information)
        end
      elsif transaction.creditor_reference
        builder.RmtInf do
          builder.Strd do
            builder.CdtrRefInf do
              builder.Tp do
                builder.CdOrPrtry do
                  builder.Cd('SCOR')
                end
              end
              builder.Ref(transaction.creditor_reference)
            end
          end
        end
      end
    end
  end
end
