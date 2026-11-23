# frozen_string_literal: true

require 'active_support/core_ext/date/calculations'
require 'active_support/core_ext/time/zones'

RSpec.describe 'Dates in the application time zone' do
  around do |example|
    zone = Time.zone
    Time.zone = 'Pacific/Kiritimati' # UTC+14: already tomorrow almost everywhere
    example.run
  ensure
    Time.zone = zone
  end

  it 'uses Date.current as today' do
    expect(SEPA.today).to eq(Time.zone.today)
  end

  it "accepts a mandate signed today in the application's time zone" do
    transaction = SEPA::DirectDebitTransaction.new(
      direct_debt_transaction(mandate_date_of_signature: Time.zone.today, requested_date: Time.zone.today + 2)
    )
    expect(transaction.errors_on(:mandate_date_of_signature)).to be_empty
  end

  it 'falls back to Date.today without ActiveSupport time zones' do
    allow(Date).to receive(:respond_to?).and_call_original
    allow(Date).to receive(:respond_to?).with(:current).and_return(false)
    expect(SEPA.today).to eq(Date.today)
  end
end
