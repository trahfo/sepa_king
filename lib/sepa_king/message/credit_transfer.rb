# frozen_string_literal: true

module SEPA
  class CreditTransfer < Message
    self.account_class = DebtorAccount
    self.transaction_class = CreditTransferTransaction
    self.xml_main_tag = 'CstmrCdtTrfInitn'
    self.known_schemas = [PAIN_001_001_03, PAIN_001_001_03_CH_02, PAIN_001_003_03, PAIN_001_002_03, PAIN_001_001_09]

    private

    # Find groups of transactions which share the same values of some attributes
    def transaction_group(transaction)
      { requested_date: transaction.requested_date,
        batch_booking: transaction.batch_booking,
        service_level: transaction.service_level,
        category_purpose: transaction.category_purpose,
        local_instrument: transaction.local_instrument,
        instruction_priority: transaction.instruction_priority,
        charge_bearer: transaction.charge_bearer,
        account: transaction.debtor_account || account }
    end

    def build_payment_informations(builder, schema)
      # Build a PmtInf block for every group of transactions
      grouped_transactions.each do |group, transactions|
        # All transactions with the same requested_date are placed into the same PmtInf block
        builder.PmtInf do
          build_payment_information_header(builder, group, transactions, schema)
          build_debtor(builder, group[:account], schema)
          charge_bearer = group[:charge_bearer] || ('SLEV' if group[:service_level])
          builder.ChrgBr(charge_bearer) if charge_bearer

          transactions.each do |transaction|
            build_transaction(builder, transaction, schema)
          end
        end
      end
    end

    def build_payment_information_header(builder, group, transactions, schema)
      builder.PmtInfId(payment_information_identification(group))
      builder.PmtMtd('TRF')
      builder.BtchBookg(group[:batch_booking])
      builder.NbOfTxs(transactions.length)
      builder.CtrlSum('%.2f' % amount_total(transactions))
      build_payment_type_information(builder, group)
      build_date(builder, :ReqdExctnDt, group[:requested_date], schema)
    end

    def build_payment_type_information(builder, group)
      builder.PmtTpInf do
        builder.InstrPrty(group[:instruction_priority]) if group[:instruction_priority]
        if group[:service_level]
          builder.SvcLvl do
            builder.Cd(group[:service_level])
          end
        end
        if group[:local_instrument]
          builder.LclInstrm do
            builder.Cd(group[:local_instrument])
          end
        end
        if group[:category_purpose]
          builder.CtgyPurp do
            builder.Cd(group[:category_purpose])
          end
        end
      end
    end

    def build_debtor(builder, account, schema)
      builder.Dbtr do
        build_name_and_address(builder, account.name, account.address, schema)
      end
      builder.DbtrAcct do
        builder.Id do
          builder.IBAN(account.iban)
        end
      end
      builder.DbtrAgt do
        # The Swiss schema leaves FinInstnId empty instead of NOTPROVIDED
        build_financial_institution(builder, account.bic, schema,
                                    not_provided: schema.name != PAIN_001_001_03_CH_02)
      end
    end

    def build_transaction(builder, transaction, schema)
      builder.CdtTrfTxInf do
        build_payment_identification(builder, transaction)
        builder.Amt do
          builder.InstdAmt('%.2f' % transaction.amount, Ccy: transaction.currency)
        end
        build_party_element(builder, :UltmtDbtr, transaction.ultimate_debtor, schema)
        if transaction.bic
          builder.CdtrAgt do
            build_financial_institution(builder, transaction.bic, schema)
          end
        end
        builder.Cdtr do
          build_name_and_address(builder, transaction.name, transaction.creditor_address, schema)
        end
        builder.CdtrAcct do
          builder.Id do
            builder.IBAN(transaction.iban)
          end
        end
        build_party_element(builder, :UltmtCdtr, transaction.ultimate_creditor, schema)
        build_purpose(builder, transaction)
        build_remittance_information(builder, transaction)
      end
    end
  end
end
