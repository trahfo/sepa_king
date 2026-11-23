# frozen_string_literal: true

module SEPA
  # The <Document> skeleton and the group header shared by all messages.
  module DocumentBuilders
    private

    def build_document(schema)
      Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |builder|
        builder.Document(schema.document_attributes) do
          builder.__send__(xml_main_tag) do
            build_group_header(builder, schema)
            build_payment_informations(builder, schema)
          end
        end
      end.doc
    end

    def build_group_header(builder, schema)
      builder.GrpHdr do
        builder.MsgId(message_identification)
        builder.CreDtTm(creation_date_time)
        builder.NbOfTxs(transactions.length)
        builder.CtrlSum('%.2f' % amount_total)
        builder.InitgPty do
          if initiating_party
            build_party(builder, initiating_party, schema)
          else
            build_default_initiating_party(builder, account)
          end
        end
      end
    end
  end
end
