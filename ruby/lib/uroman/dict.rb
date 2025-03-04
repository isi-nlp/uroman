# frozen_string_literal: true

module Uroman
  # Base class for simple dictionary-like objects
  class Dict
    def initialize(**kwargs)
      @data = {}
      kwargs.each do |key, value|
        next if value.nil? || value == [] || value == false

        @data[key.to_s.tr('_', '-')] = value
      end
    end

    def [](key)
      @data[key.to_s]
    end

    def inspect
      @data.inspect
    end

    def empty?
      @data.empty?
    end

    def to_h
      @data
    end
  end

  # Romanization rule with source and target strings
  # key: source string
  # typical attributes: s (source), t (target), prov (provenance), lcodes (language codes)
  # t_alts=t_alts (target alternatives), use_only_at_start_of_word, dont_use_at_start_of_word,
  # use_only_at_end_of_word, dont_use_at_end_of_word, use_only_for_whole_word
  class RomRule < Dict
  end

  # Script metadata
  # key: lower case script_name
  # typical attributes: script_name, direction, abugida_default_vowels, alt_script_names, languages
  class Script < Dict
  end
end
