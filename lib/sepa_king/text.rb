# frozen_string_literal: true

module SEPA
  # Conversion of free text into the character set allowed in SEPA messages,
  # following the EPC "Best practices on the SEPA requirements for character
  # set" (EPC217-08): characters outside the set are transliterated where
  # possible (é → e, Ø → O, Æ → AE) and dropped otherwise.
  module Text
    # Characters kept unchanged, per character set.
    ALLOWED = {
      dk_extended: %r{[a-zA-Z0-9ÄÖÜäöüß&*$%\ ':?,\-(+.)/]},
      epc_basic: %r{[a-zA-Z0-9\ ':?,\-(+.)/]}
    }.freeze

    # Replacements applied before anything else, in both character sets.
    PREFIX_REPLACEMENTS = { '€' => 'E', '@' => '(at)', '_' => '-' }.freeze

    # Punctuation the EPC basic set maps instead of dropping.
    EPC_PUNCTUATION = {
      '&' => '+', '[' => '(', ']' => ')', '{' => '(', '}' => ')', '\\' => '/', '`' => "'", ';' => ',',
      '"' => "'", '*' => '.', '$' => '', '%' => ''
    }.freeze

    # Letters that do not decompose into a base letter plus accents.
    LETTERS = {
      'Æ' => 'AE', 'æ' => 'ae', 'Œ' => 'OE', 'œ' => 'oe', 'Ø' => 'O', 'ø' => 'o', 'Ł' => 'L', 'ł' => 'l',
      'Đ' => 'D', 'đ' => 'd', 'Ð' => 'D', 'ð' => 'd', 'Þ' => 'TH', 'þ' => 'th', 'ı' => 'i', 'ß' => 'ss',
      'Ä' => 'A', 'ä' => 'a', 'Ö' => 'O', 'ö' => 'o', 'Ü' => 'U', 'ü' => 'u'
    }.freeze

    module_function

    # @param value [#to_s, nil]
    # @param charset [Symbol] :dk_extended or :epc_basic (default: SEPA.configuration.charset)
    # @param strict [Boolean] raise CharacterError instead of dropping characters
    # @return [String, nil] the converted text, stripped; nil for nil
    # @raise [CharacterError] in strict mode for characters that cannot be converted
    def convert(value, charset: SEPA.configuration.charset, strict: SEPA.configuration.strict_charset)
      return unless value

      allowed = ALLOWED.fetch(charset)
      text = value.to_s.gsub(/[€@_]/, PREFIX_REPLACEMENTS).gsub(/\n+/, ' ')
      text.each_char.map { |char| convert_char(char, allowed, charset, strict) }.join.strip
    end

    # Cuts a text to +length+ characters without splitting a character.
    # @param value [String, nil]
    # @param length [Integer]
    # @return [String, nil]
    def truncate(value, length)
      return unless value

      value.grapheme_clusters.first(length).join
    end

    def convert_char(char, allowed, charset, strict)
      return char if char.match?(allowed)

      replacement = replacement_for(char, charset)
      return replacement if replacement&.each_char&.all? { |c| c.match?(allowed) }
      raise CharacterError, "Character '#{char}' is not allowed in SEPA messages" if strict

      ''
    end

    def replacement_for(char, charset)
      (EPC_PUNCTUATION[char] if charset == :epc_basic) || LETTERS[char] || decompose(char)
    end

    # é → e, Ç → C: drops the combining accents of a decomposed letter.
    def decompose(char)
      base = char.unicode_normalize(:nfkd).gsub(/\p{Mn}/, '')
      base unless base.empty? || base == char
    end
    private_class_method :convert_char, :replacement_for, :decompose
  end
end
