# frozen_string_literal: true

module SEPA
  class DirectDebit < Message
    self.account_class = CreditorAccount
    self.transaction_class = DirectDebitTransaction
    self.xml_main_tag = 'CstmrDrctDbtInitn'
    self.known_schemas = [PAIN_008_001_02, PAIN_008_003_02, PAIN_008_002_02, PAIN_008_001_08]

    validate do |record|
      if record.transactions.map(&:local_instrument).uniq.size > 1
        errors.add(:base, 'CORE, COR1 AND B2B must not be mixed in one message!')
      end
    end

    private

    # Find groups of transactions which share the same values of some attributes
    def transaction_group(transaction)
      { requested_date: transaction.requested_date,
        local_instrument: transaction.local_instrument,
        sequence_type: transaction.sequence_type,
        batch_booking: transaction.batch_booking,
        account: transaction.creditor_account || account }
    end

    def build_payment_informations(builder, schema)
      # Build a PmtInf block for every group of transactions
      grouped_transactions.each do |group, transactions|
        builder.PmtInf do
          build_payment_information_header(builder, group, transactions)
          build_creditor(builder, group[:account], schema)
          builder.ChrgBr('SLEV')
          builder.CdtrSchmeId do
            build_creditor_scheme_identification(builder, group[:account].creditor_identifier)
          end

          transactions.each do |transaction|
            build_transaction(builder, transaction, schema)
          end
        end
      end
    end

    def build_payment_information_header(builder, group, transactions)
      builder.PmtInfId(payment_information_identification(group))
      builder.PmtMtd('DD')
      builder.BtchBookg(group[:batch_booking])
      builder.NbOfTxs(transactions.length)
      builder.CtrlSum('%.2f' % amount_total(transactions))
      builder.PmtTpInf do
        builder.SvcLvl do
          builder.Cd('SEPA')
        end
        builder.LclInstrm do
          builder.Cd(group[:local_instrument])
        end
        builder.SeqTp(group[:sequence_type])
      end
      builder.ReqdColltnDt(group[:requested_date].iso8601)
    end

    def build_creditor(builder, account, schema)
      builder.Cdtr do
        build_party(builder, account.name, account.address, schema)
      end
      builder.CdtrAcct do
        builder.Id do
          builder.IBAN(account.iban)
        end
      end
      builder.CdtrAgt do
        build_financial_institution(builder, account.bic, schema)
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
        build_original_creditor_scheme(builder, transaction.original_creditor_account)
      end
    end

    def build_original_creditor_scheme(builder, original_creditor_account)
      return unless original_creditor_account

      builder.OrgnlCdtrSchmeId do
        builder.Nm(original_creditor_account.name) if original_creditor_account.name
        if original_creditor_account.creditor_identifier
          build_creditor_scheme_identification(builder, original_creditor_account.creditor_identifier)
        end
      end
    end

    def build_transaction(builder, transaction, schema)
      builder.DrctDbtTxInf do
        builder.PmtId do
          builder.InstrId(transaction.instruction) if transaction.instruction.present?
          builder.EndToEndId(transaction.reference)
        end
        builder.InstdAmt('%.2f' % transaction.amount, Ccy: transaction.currency)
        builder.DrctDbtTx do
          builder.MndtRltdInf do
            builder.MndtId(transaction.mandate_id)
            builder.DtOfSgntr(transaction.mandate_date_of_signature.iso8601)
            build_amendment_informations(builder, transaction) if transaction.amendment_informations?
          end
        end
        builder.DbtrAgt do
          build_financial_institution(builder, transaction.bic, schema)
        end
        builder.Dbtr do
          build_party(builder, transaction.name, transaction.debtor_address, schema)
        end
        builder.DbtrAcct do
          builder.Id do
            builder.IBAN(transaction.iban)
          end
        end
        if transaction.remittance_information
          builder.RmtInf do
            builder.Ustrd(transaction.remittance_information)
          end
        end
      end
    end
  end
end
