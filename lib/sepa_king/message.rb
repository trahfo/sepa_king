# frozen_string_literal: true

module SEPA
  class Message
    include ActiveModel::Validations
    include Builders

    attr_reader :account, :grouped_transactions

    validates_presence_of :transactions
    validate do |record|
      record.errors.add(:account, record.account.errors.full_messages) unless record.account.valid?
    end

    class_attribute :account_class, :transaction_class, :xml_main_tag, :known_schemas
    class_attribute :default_schema_warned, instance_accessor: false, default: false

    def initialize(account_options = {})
      @grouped_transactions = {}
      @account = account_class.new(account_options)
    end

    def add_transaction(options)
      transaction = transaction_class.new(options)
      raise ArgumentError, transaction.errors.full_messages.join("\n") unless transaction.valid?

      @grouped_transactions[transaction_group(transaction)] ||= []
      @grouped_transactions[transaction_group(transaction)] << transaction
    end

    def transactions
      grouped_transactions.values.flatten
    end

    # @param schema_name [String] one of +known_schemas+. Defaults to the first
    #   known schema (the ISO 2009 version); this default will change to the
    #   ISO 2019 version in 1.0, so pass the schema explicitly.
    # @return [String] xml
    def to_xml(schema_name = nil)
      schema_name ||= default_schema_name
      raise SEPA::Error, errors.full_messages.join("\n") unless valid?
      raise SEPA::Error, "Incompatible with schema #{schema_name}!" unless schema_compatible?(schema_name)

      schema = Schema[schema_name]
      builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |builder|
        builder.Document(schema.document_attributes) do
          builder.__send__(xml_main_tag) do
            build_group_header(builder)
            build_payment_informations(builder, schema)
          end
        end
      end

      validate_final_document!(builder.doc, schema)
      builder.to_xml
    end

    def amount_total(selected_transactions = transactions)
      selected_transactions.inject(0) { |sum, t| sum + t.amount }
    end

    def schema_compatible?(schema_name)
      raise ArgumentError, "Schema #{schema_name} is unknown!" unless known_schemas.include?(schema_name)

      schema = Schema[schema_name]
      return false if schema.supports?(:account_bic_required) && account.bic.blank?
      return false unless account.address.nil? || account.address.schema_compatible?(schema)

      transactions.all? { |t| t.schema_compatible?(schema_name) }
    end

    # Set unique identifer for the message
    def message_identification=(value)
      raise ArgumentError, 'message_identification must be a string!' unless value.is_a?(String)

      regex = %r{\A([A-Za-z0-9]|[+|?/\-:().,'\ ]){1,35}\z}
      raise ArgumentError, "message_identification does not match #{regex}!" unless value.match?(regex)

      @message_identification = value
    end

    # Get unique identifer for the message (with fallback to a random string)
    def message_identification
      @message_identification ||= "SEPA-KING/#{SecureRandom.hex(11)}"
    end

    # Set creation date time for the message
    # p.s. Rabobank in the Netherlands only accepts the more restricted format [0-9]{4}[-][0-9]{2,2}[-][0-9]{2,2}[T][0-9]{2,2}[:][0-9]{2,2}[:][0-9]{2,2}
    def creation_date_time=(value)
      raise ArgumentError, 'creation_date_time must be a string!' unless value.is_a?(String)

      regex = /[0-9]{4}-[0-9]{2,2}-[0-9]{2,2}(?:\s|T)[0-9]{2,2}:[0-9]{2,2}:[0-9]{2,2}/
      raise ArgumentError, "creation_date_time does not match #{regex}!" unless value.match?(regex)

      @creation_date_time = value
    end

    # Get creation date time for the message (with fallback to Time.now.iso8601)
    def creation_date_time
      @creation_date_time ||= Time.now.iso8601
    end

    # Returns the id of the batch to which the given transaction belongs
    # Identified based upon the reference of the transaction
    def batch_id(transaction_reference)
      grouped_transactions.each do |group, transactions|
        if transactions.any? { |transaction| transaction.reference == transaction_reference }
          return payment_information_identification(group)
        end
      end
    end

    def batches
      grouped_transactions.keys.collect { |group| payment_information_identification(group) }
    end

    private

    def default_schema_name
      unless self.class.default_schema_warned
        warn "[sepa_king] #{self.class.name}#to_xml without a schema uses #{known_schemas.first}. " \
             'The default will change to the ISO 2019 schema in sepa_king 1.0; pass the schema explicitly.',
             category: :deprecated
        self.class.default_schema_warned = true
      end
      known_schemas.first
    end

    def build_group_header(builder)
      builder.GrpHdr do
        builder.MsgId(message_identification)
        builder.CreDtTm(creation_date_time)
        builder.NbOfTxs(transactions.length)
        builder.CtrlSum('%.2f' % amount_total)
        builder.InitgPty do
          builder.Nm(account.name)
          if account.respond_to? :creditor_identifier
            builder.Id do
              builder.OrgId do
                builder.Othr do
                  builder.Id(account.creditor_identifier)
                end
              end
            end
          end
        end
      end
    end

    # Unique and consecutive identifier (used for the <PmntInf> blocks)
    def payment_information_identification(group)
      "#{message_identification}/#{grouped_transactions.keys.index(group) + 1}"
    end

    # Returns a key to determine the group to which the transaction belongs
    def transaction_group(transaction)
      transaction
    end

    def validate_final_document!(document, schema)
      errors = schema.validate(document)
      raise SEPA::Error, "Incompatible with schema #{schema}: #{errors.join(', ')}" if errors.any?
    end
  end
end
