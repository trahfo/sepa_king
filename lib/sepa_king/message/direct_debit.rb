# frozen_string_literal: true

module SEPA
  # SEPA Direct Debit Initiation (pain.008, "Lastschrift").
  class DirectDebit < Message
    include MandateBuilders

    self.account_class = CreditorAccount
    self.transaction_class = DirectDebitTransaction
    self.xml_main_tag = 'CstmrDrctDbtInitn'
    self.known_schemas = [PAIN_008_001_02, PAIN_008_003_02, PAIN_008_002_02, PAIN_008_001_08]

    validate do |record|
      if record.transactions.map(&:local_instrument).uniq.size > 1
        errors.add(:base, :sepa_mixed_local_instruments)
      end
    end

    private

    # Find groups of transactions which share the same values of some attributes
    def transaction_group(transaction)
      { requested_date: transaction.requested_date,
        local_instrument: transaction.local_instrument,
        sequence_type: transaction.sequence_type,
        batch_booking: transaction.batch_booking,
        account: transaction.creditor_account || account,
        category_purpose: transaction.category_purpose }
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
        if group[:category_purpose]
          builder.CtgyPurp do
            builder.Cd(group[:category_purpose])
          end
        end
      end
      builder.ReqdColltnDt(group[:requested_date].iso8601)
    end

    def build_creditor(builder, account, schema)
      builder.Cdtr do
        build_name_and_address(builder, account.name, account.address, schema)
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

    def build_transaction(builder, transaction, schema)
      builder.DrctDbtTxInf do
        build_payment_identification(builder, transaction)
        builder.InstdAmt('%.2f' % transaction.amount, Ccy: transaction.currency)
        build_mandate_related_information(builder, transaction)
        build_party_element(builder, :UltmtCdtr, transaction.ultimate_creditor, schema)
        build_debtor(builder, transaction, schema)
        build_party_element(builder, :UltmtDbtr, transaction.ultimate_debtor, schema)
        build_purpose(builder, transaction)
        build_remittance_information(builder, transaction)
      end
    end

    def build_debtor(builder, transaction, schema)
      builder.DbtrAgt do
        build_financial_institution(builder, transaction.bic, schema)
      end
      builder.Dbtr do
        build_name_and_address(builder, transaction.name, transaction.debtor_address, schema)
      end
      builder.DbtrAcct do
        builder.Id do
          builder.IBAN(transaction.iban)
        end
      end
    end
  end
end
