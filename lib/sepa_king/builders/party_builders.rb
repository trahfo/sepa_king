# frozen_string_literal: true

module SEPA
  # XML for parties other than the account holders: <InitgPty>, <UltmtDbtr>,
  # <UltmtCdtr> with name, postal address and identification.
  module PartyBuilders
    private

    # The account holder, identified by the creditor identifier for direct debits.
    def build_default_initiating_party(builder, account)
      builder.Nm(account.name)
      return unless account.respond_to? :creditor_identifier

      builder.Id do
        builder.OrgId do
          builder.Othr do
            builder.Id(account.creditor_identifier)
          end
        end
      end
    end

    # Content of a party element (<InitgPty>, <UltmtDbtr>, <UltmtCdtr>).
    def build_party(builder, party, schema)
      builder.Nm(party.name) if party.name
      build_postal_address(builder, party.address, schema) if party.address
      build_identification(builder, party.identification, schema) if party.identification
    end

    def build_party_element(builder, tag, party, schema)
      return unless party

      builder.__send__(tag) do
        build_party(builder, party, schema)
      end
    end

    def build_identification(builder, identification, schema)
      builder.Id do
        if identification.organisation?
          builder.OrgId do
            builder.__send__(schema.iso2019? ? :AnyBIC : :BICOrBEI, identification.bic) if identification.bic
            builder.LEI(identification.lei) if identification.lei
            build_other_identification(builder, identification) if identification.id
          end
        else
          builder.PrvtId do
            build_other_identification(builder, identification)
          end
        end
      end
    end

    def build_other_identification(builder, identification)
      builder.Othr do
        builder.Id(identification.id)
        if identification.scheme_code || identification.scheme_proprietary
          builder.SchmeNm do
            if identification.scheme_code
              builder.Cd(identification.scheme_code)
            else
              builder.Prtry(identification.scheme_proprietary)
            end
          end
        end
        builder.Issr(identification.issuer) if identification.issuer
      end
    end
  end
end
