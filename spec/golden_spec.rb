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
      message.known_schemas.product(%i[default]).flat_map { |name, _| SEPA::Schema.profiles(name).map { |p| [name, p] } }
             .each_with_index do |(schema, profile), _|
        next unless message.schema_compatible?(schema, profile: profile)

        first_profile = SEPA::Schema.profiles(schema).first == profile
        file = first_profile ? "#{scenario}.#{schema}.xml" : "#{scenario}.#{schema}.#{profile}.xml"

        it "matches spec/golden/#{file}" do
          path = File.join(golden_dir, file)
          xml = begin
            build.call.to_xml(schema, profile: profile)
          rescue SEPA::Error => e
            # Some schemas pass schema_compatible? but are rejected by the XSD
            # (e.g. structured addresses in pain.008.003.02). The error is part
            # of the recorded behaviour (the XSD parser's wording differs between
            # libxml2 and JRuby's Xerces, so only the summary is recorded).
            "ERROR: #{e.message[/\AIncompatible with schema [^:]+/]}\n"
          end

          File.write(path, xml) if ENV['GOLDEN_UPDATE'] || !File.exist?(path)

          expect(xml).to eq(File.read(path, encoding: 'UTF-8'))
          expect(xml).to validate_against(SEPA::Schema[schema, profile].xsd_file) unless xml.start_with?('ERROR:')
        end
      end
    end
  end
end
