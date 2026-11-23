# frozen_string_literal: true

require 'spec_helper'

# Byte-for-byte regression net: the XML that sepa_king produces must not
# change unless a golden file is updated on purpose:
#
#   GOLDEN_UPDATE=1 bundle exec rspec spec/golden_spec.rb
RSpec.describe 'Golden XML output' do
  golden_dir = File.expand_path('golden', __dir__)

  GoldenScenarios.all.each do |scenario, build|
    describe scenario do
      message = build.call
      message.known_schemas.each do |schema|
        next unless message.schema_compatible?(schema)

        it "matches spec/golden/#{scenario}.#{schema}.xml" do
          path = File.join(golden_dir, "#{scenario}.#{schema}.xml")
          xml = begin
            build.call.to_xml(schema)
          rescue SEPA::Error => e
            # Some schemas pass schema_compatible? but are rejected by the XSD
            # (e.g. structured addresses in pain.008.003.02). The error is part
            # of the recorded behaviour (the XSD parser's wording differs between
            # libxml2 and JRuby's Xerces, so only the summary is recorded).
            "ERROR: #{e.message[/\AIncompatible with schema [^:]+/]}\n"
          end

          File.write(path, xml) if ENV['GOLDEN_UPDATE'] || !File.exist?(path)

          expect(xml).to eq(File.read(path, encoding: 'UTF-8'))
          expect(xml).to validate_against("#{schema}.xsd") unless xml.start_with?('ERROR:')
        end
      end
    end
  end
end
