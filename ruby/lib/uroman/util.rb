# frozen_string_literal: true

require 'unicode/categories'
require 'unicode/name'
require 'unicode/numeric_value'

module Uroman
  module Util
    extend self

    # TODO: not used
    # def timer(method)
    #   proc do |*args|
    #     start_time = Time.now
    #     puts "Calling: #{method.name}(#{args})"
    #     puts "Start time: #{start_time.strftime('%A, %B %d, %Y at %H:%M')}"
    #     result = method.call(*args)
    #     end_time = Time.now
    #     duration = end_time - start_time
    #     puts "End time: #{end_time.strftime('%A, %B %d, %Y at %H:%M')}"
    #     puts "Duration: #{duration} seconds"
    #     result
    #   end
    # end

    # For a given slot, e.g. 'cost', get its value from a line such as '::s1 of course ::s2 ::cost 0.3' -> 0.3
    # The value can be an empty string, as for ::s2 in the example above.
    def slot_value_in_double_colon_del_list(line, slot, default = nil)
      match = line.match(/(?:.*\s)?::#{Regexp.escape(slot)}(|\s+\S.*?)(?:\s+::\S.*|\s*)$/)
      match ? match[1].strip : default
    end

    def has_value_in_double_colon_del_list(line, slot)
      !slot_value_in_double_colon_del_list(line, slot).nil?
    end

    def dequote_string(str)
      if str.is_a?(String)
        m = str.match(/\s*(['"“])(.*)(['"”])\s*$/)
        return m[2] if m && %w['' "" “”].include?(m[1] + m[3])
      end
      str
    end

    def last_chr(str)
      str[-1] || ''
    end

    # TODO: this can be rational, etc.
    # def ud_numeric(char: str) -> int | float | None:
    #     try:
    #         num_f = ud.numeric(char)
    #         return int(num_f) if num_f.is_integer() else num_f
    #     except (ValueError, TypeError):
    #         return None
    # Unicode::NumericValue.of("1") # => 1
    # Unicode::NumericValue.of("Ⅷ") # => 8
    # Unicode::NumericValue.of("⓳") # => 19
    # Unicode::NumericValue.of("¾") # => (3/4)
    # Unicode::NumericValue.of("༳") # => (-1/2)
    # Unicode::NumericValue.of("𑿀") # => (1/320)
    # Unicode::NumericValue.of("𖭡") # => 1000000000000
    # Unicode::NumericValue.of("五") # => 5
    # Unicode::NumericValue.of("𜳷") # => 7
    # Unicode::NumericValue.of("A") # => nil
    def ud_numeric(char)
      num_f = Unicode::NumericValue.of(char)
      return num_f.to_i if num_f.is_a?(Float) && num_f.to_i == num_f
      return num_f
    rescue
      nil
    end

    def robust_str_to_num(num_s, filename = nil, line_number = nil, silent = false)
      return nil unless num_s.is_a?(String)
      num_s.include?('.') ? Float(num_s) : Integer(num_s)
    rescue ArgumentError
      unless silent
        # TODO: add central logging
        warning = "In Uroman::Util.robust_str_to_num, cannot convert '#{num_s}' to a number"
        warning = "#{filename}:#{line_number}: #{warning}" if filename && line_number
        warn warning
      end
      return nil
    end

    def first_non_nil(*args)
      args.find { |arg| !arg.nil? }
    end

    # TODO: this is probably redundant
    # def any_not_none?(*args)
    #   args.any? { |arg| !arg.nil? }
    # end

    def add_non_nil_to_hash(hash, key, value)
      hash[key] = value unless value.nil?
    end

    def chr_name(char)
      return '' if char.empty?
      Unicode::Name.of(char) || ''
    end

    def decode_unicode_escapes(s)
      s.gsub(/\\(x[0-9a-fA-F]{2}|u[0-9a-fA-F]{4}|U[0-9a-fA-F]{8})/) do |match|
        hex = match[2..].to_i(16)
        if hex > 0x80
          [hex].pack("U") # Convert Unicode code point to a character
        else
          match # Keep the original escape sequence if ASCII
        end
      end + (s.end_with?("\n") ? "\n" : "")
    end

    # TODO: try this instead
    # def decode_unicode_escapes(s)
    #   return s unless s.match?(/\\[xuU][0-9A-Fa-f]{2}/)
    #
    #   result = +''
    #   rest = s
    #
    #   while (m = rest.match(/(.*?)(\\x[0-9a-fA-F]{2}|\\u[0-9a-fA-F]{4}|\\U[0-9a-fA-F]{8})(.*)$/))
    #     pre, core, rest = m.captures
    #     cp = core[2..].to_i(16)
    #
    #     # Escape only for non-ASCII, specifically not for \x22, \x25 (quote, apostrophe)
    #     if cp > 0x80
    #       result += pre + cp.chr(Encoding::UTF_8)
    #     else
    #       result += pre + core
    #     end
    #   end
    #
    #   result + rest + (s.end_with?("\n") ? "\n" : "")
    # end
  end
end 
