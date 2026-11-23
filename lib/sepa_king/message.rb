# frozen_string_literal: true

module SEPA
  # Base class of SEPA::DirectDebit and SEPA::CreditTransfer: an account
  # holder plus transactions grouped into payment information blocks.
  class Message
    include ActiveModel::Validations
    include Builders
    include Introspection
    include DocumentBuilders

    attr_reader :account, :grouped_transactions, :initiating_party

    validates_presence_of :transactions
    validate do |record|
      record.errors.add(:account, record.account.errors.full_messages) unless record.account.valid?
      if initiating_party && !initiating_party.valid?
        record.errors.add(:initiating_party, initiating_party.errors.full_messages.join(', '))
      end
    end

    class_attribute :account_class, :transaction_class, :xml_main_tag, :known_schemas
    class_attribute :default_schema_warned, instance_accessor: false, default: false

    # @param account_options [Hash] attributes of the account holder (creditor
    #   of a direct debit, debtor of a credit transfer). The optional key
    #   +:initiating_party+ (Party, Hash or name) sets a different initiating
    #   party, e.g. a service provider submitting on behalf of the account holder.
    def initialize(account_options = {})
      @grouped_transactions = {}
      account_options = account_options.dup
      @initiating_party = Party.coerce(account_options.delete(:initiating_party))
      @account = account_class.new(account_options)
    end

    def add_transaction(options)
      transaction = transaction_class.new(options)
      raise ArgumentError, transaction.errors.full_messages.join("\n") unless transaction.valid?

      @grouped_transactions[transaction_group(transaction)] ||= []
      @grouped_transactions[transaction_group(transaction)] << transaction
    end

    # @return [Array<Transaction>] all transactions of the message
    def transactions
      grouped_transactions.values.flatten
    end

    # Builds the XML document.
    #
    # @param schema_name [String] one of +known_schemas+. Defaults to the first
    #   known schema (the ISO 2009 version); this default will change to the
    #   ISO 2019 version in 1.0, so pass the schema explicitly.
    # @param profile [Symbol, nil] validation profile of the schema, e.g. :dk
    #   (default) or :epc for the 2019 versions; see SEPA::Schema
    # @param pretty [Boolean] indented output (default) or compact XML without
    #   whitespace between elements
    # @param validate [Boolean] check the document against the XSD (default).
    #   Only switch this off for benchmarks; an invalid file is rejected by the bank.
    # @return [String] xml
    # @raise [SEPA::Error] if the message is invalid, incompatible with the
    #   schema or rejected by the XSD
    def to_xml(schema_name = nil, profile: nil, pretty: true, validate: true)
      schema_name ||= default_schema_name
      validate!
      schema = resolve_schema(schema_name, profile)
      raise SEPA::Error, "Incompatible with schema #{schema}!" unless schema_compatible?(schema_name, profile: profile)

      document = build_document(schema)
      validate_final_document!(document, schema) if validate
      pretty ? document.to_xml : document.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
    end

    # @param selected_transactions [Array<Transaction>]
    # @return [BigDecimal] sum of the amounts
    def amount_total(selected_transactions = transactions)
      selected_transactions.inject(0) { |sum, t| sum + t.amount }
    end

    def schema_compatible?(schema_name, profile: nil)
      schema = resolve_schema(schema_name, profile)
      return false unless parties_compatible?(schema)
      return false if schema.supports?(:uniform_local_instrument) && local_instruments.size > 1

      transactions.all? { |t| t.schema_compatible?(schema) }
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

    # @return [Array<String>] the ids of all payment information blocks
    def batches
      grouped_transactions.keys.collect { |group| payment_information_identification(group) }
    end

    private

    def resolve_schema(schema_name, profile)
      raise ArgumentError, "Schema #{schema_name} is unknown!" unless known_schemas.include?(schema_name)

      Schema[schema_name, profile]
    end

    # Account holder and initiating party
    def parties_compatible?(schema)
      return false if schema.supports?(:account_bic_required) && account.bic.blank?

      [account.address, initiating_party].compact.all? { |value| value.schema_compatible?(schema) }
    end

    def local_instruments
      transactions.map(&:local_instrument).uniq
    end

    def default_schema_name
      unless self.class.default_schema_warned
        warn "[sepa_king] #{self.class.name}#to_xml without a schema uses #{known_schemas.first}. " \
             'The default will change to the ISO 2019 schema in sepa_king 1.0; pass the schema explicitly.',
             category: :deprecated
        self.class.default_schema_warned = true
      end
      known_schemas.first
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
