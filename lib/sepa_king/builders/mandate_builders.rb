# frozen_string_literal: true

module SEPA
  # XML for the mandate of a direct debit: <DrctDbtTx> with mandate id,
  # date of signature and amendment details, and the creditor scheme id.
  module MandateBuilders
    private

    def build_mandate_related_information(builder, transaction)
      builder.DrctDbtTx do
        builder.MndtRltdInf do
          builder.MndtId(transaction.mandate_id)
          builder.DtOfSgntr(transaction.mandate_date_of_signature.iso8601)
          build_amendment_informations(builder, transaction) if transaction.amendment_informations?
        end
      end
    end

    # <Id> of a creditor scheme identification (Gläubiger-ID)
    def build_creditor_scheme_identification(builder, creditor_identifier)
      builder.Id do
        builder.PrvtId do
          builder.Othr do
            builder.Id(creditor_identifier)
            builder.SchmeNm do
              builder.Prtry('SEPA')
            end
          end
        end
      end
    end

    def build_amendment_informations(builder, transaction)
      builder.AmdmntInd(true)
      builder.AmdmntInfDtls do
        builder.OrgnlMndtId(transaction.original_mandate_id) if transaction.original_mandate_id
        build_original_creditor_scheme(builder, transaction.original_creditor_account)
        if transaction.original_debtor_account
          builder.OrgnlDbtrAcct do
            builder.Id do
              builder.IBAN(transaction.original_debtor_account)
            end
          end
        elsif transaction.same_mandate_new_debtor_agent
          builder.OrgnlDbtrAgt do
            builder.FinInstnId do
              builder.Othr do
                builder.Id('SMNDA')
              end
            end
          end
        end
      end
    end

    def build_original_creditor_scheme(builder, original_creditor_account)
      return unless original_creditor_account

      builder.OrgnlCdtrSchmeId do
        builder.Nm(original_creditor_account.name) if original_creditor_account.name
        build_creditor_scheme_identification(builder, original_creditor_account.creditor_identifier) if original_creditor_account.creditor_identifier
      end
    end
  end
end
