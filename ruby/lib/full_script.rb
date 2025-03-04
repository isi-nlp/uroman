#!/usr/bin/env ruby

=begin
Written by Ulf Hermjakob, USC/ISI  March-June 2024
uroman is a universal romanizer. It converts text in any script to the standard Latin alphabet.
This is a Ruby reimplementation of an earlier Perl script, with some improvements.
It has been tested on 250 languages, with 100 or more sentences each.
This script is still under development and large-scale testing. Feedback welcome.
It provides token-size caching (for faster runtimes).
Output formats include:
  (1) best romanization string
  (2) best romanization edges (best path; including start and end positions with respect to the original string)
  (3) best romanization with alternatives (as applicable for ambiguous romanization)
  (4) best romanization full lattice (all edges, including superseded sub-edges)
See below for sample calls in main().
=end

require 'optparse'
require 'json'
require 'time'
require 'date'
require 'set'
require 'pathname'
require 'unicode_utils'
require 'strscan'
# Assuming a gem 'unicode_utils' is available for Unicode character names

DEFAULT_ROM_MAX_CACHE_SIZE = 65536
PROFILE_FLAG = "--profile"

__version__ = '1.3.1.1'
__last_mod_date__ = 'June 27, 2024'
__description__ = "uroman is a universal romanizer. It converts text in any script to the standard Latin alphabet."

# UTILITIES

def timer(method_name)
  start_time = Time.now
  puts "Calling: #{method_name}"
  result = yield
  end_time = Time.now
  puts "Start time: #{start_time.strftime('%A, %B %d, %Y at %H:%M')}"
  puts "End time: #{end_time.strftime('%A, %B %d, %Y at %H:%M')}"
  duration = end_time - start_time
  puts "Duration: #{duration} seconds"
  result
end


def slot_value_in_double_colon_del_list(line, slot, default=nil)
  # Construct a regex similar to the Python version: capture optional value after ::slot
  m = line.match(/(?:.*\s)?::#{Regexp.escape(slot)}((?:\s+\S.*)?)(?:\s+::\S.*|\s*)$/)
  m ? m[1].strip : default
end


def has_value_in_double_colon_del_list(line, slot)
  value = slot_value_in_double_colon_del_list(line, slot)
  value.is_a?(String)
end


def dequote_string(s)
  return s unless s.is_a?(String)
  m = s.match(/\s*(['"“])(.*)(['"”])\s*$/)
  if m && ["''", '""', """"].include?(m[1] + m[3])
    return m[2]
  end
  s
end


def last_chr(s)
  s.empty? ? '' : s[-1]
end


def ud_numeric(char)
  begin
    num_f = Float(char) rescue nil
    if num_f && num_f.to_i == num_f
      num_f.to_i
    else
      num_f
    end
  rescue
    nil
  end
end


def robust_str_to_num(num_s, filename=nil, line_number=nil, silent=false)
  return nil if num_s.nil? || num_s == ""
  begin
    if num_s.include?('/')
      parts = num_s.split('/')
      Float(parts[0]) / Float(parts[1])
    elsif num_s.include?('.')
      Float(num_s)
    else
      Integer(num_s)
    end
  rescue
    unless silent
      STDERR.puts "Cannot convert \"#{num_s}\" to a number" + (line_number ? " line: #{line_number}" : "") + (filename ? " file: #{filename}" : "")
    end
    nil
  end
end


def first_non_none(*args)
  args.find { |x| !x.nil? }
end


def any_not_none(*args)
  args.any? { |x| !x.nil? }
end


def add_non_none_to_dict(d, key, value)
  d[key] = value unless value.nil?
end


def fraction_char2fraction(fraction_char, fraction_value=nil, uroman=nil)
  return nil if fraction_char.nil?
  return fraction_value if fraction_value
  return nil unless uroman
  value = uroman.num_value(fraction_char)
  value.is_a?(Numeric) ? Rational(value).to_f : nil
end


def chr_name(char)
  return '' if char.nil? || char.empty?
  begin
    Unicode::Utils.char_name(char)
  rescue
    ''
  end
end


def args_get(key, args=nil)
  args && args[key] ? args[key] : nil
end

class DictClass
  def initialize(**kw_args)
    @dict = kw_args
  end

  def [](key, default=nil)
    @dict.fetch(key.to_sym, default)
  end

  def to_s
    @dict.to_s
  end

  def method_missing(name, *args, &block)
    key = name.to_sym
    if @dict.key?(key)
      @dict[key]
    else
      super
    end
  end

  def respond_to_missing?(name, include_private=false)
    @dict.key?(name.to_sym) || super
  end
end

class RomRule < DictClass
  attr_accessor :s, :t, :prov, :lcodes, :t_alts, :num, :use_only_at_start_of_word,
                :dont_use_at_start_of_word, :use_only_at_end_of_word, :dont_use_at_end_of_word,
                :use_only_for_whole_word, :t_at_end_of_syllable, :n_restr, :is_minus_sign,
                :is_plus_sign, :is_decimal_point, :fraction_connector, :percentage_marker,
                :int_frac_connector, :is_large_power

  def initialize(**kw_args)
    @s = kw_args[:s]
    @t = kw_args[:t]
    @prov = kw_args[:prov]
    @lcodes = kw_args[:lcodes] || []
    @t_alts = kw_args[:t_alts] || []
    @num = kw_args[:num]
    @use_only_at_start_of_word = kw_args[:use_only_at_start_of_word]
    @dont_use_at_start_of_word = kw_args[:dont_use_at_start_of_word]
    @use_only_at_end_of_word = kw_args[:use_only_at_end_of_word]
    @dont_use_at_end_of_word = kw_args[:dont_use_at_end_of_word]
    @use_only_for_whole_word = kw_args[:use_only_for_whole_word]
    @t_at_end_of_syllable = kw_args[:t_at_end_of_syllable]
    @n_restr = kw_args[:n_restr] || 0
    @is_minus_sign = kw_args[:is_minus_sign]
    @is_plus_sign = kw_args[:is_plus_sign]
    @is_decimal_point = kw_args[:is_decimal_point]
    @fraction_connector = kw_args[:fraction_connector]
    @percentage_marker = kw_args[:percentage_marker]
    @int_frac_connector = kw_args[:int_frac_connector]
    @is_large_power = kw_args[:is_large_power]
  end

  def [](key, default=nil)
    instance_variable_get("@#{key}") || default
  end

  def inspect
    "#<RomRule s='#{@s}' t='#{@t}' prov='#{@prov}' lcodes=#{@lcodes.inspect} t_alts=#{@t_alts.inspect}>"
  end

  def to_s
    inspect
  end
end

class Script < DictClass
  def initialize(**args)
    super(**args)
  end

  def char_ranges
    @dict[:char_ranges]
  end
end

module RomFormat
  STR = 'str'
  EDGES = 'edges'
  ALTS = 'alts'
  LATTICE = 'lattice'

  def self.str
    STR
  end

  def self.to_s(format)
    format.downcase
  end
end

class Uroman
  attr_accessor :stats, :rom_cache, :rom_rules, :scripts, :ud_props, :num_props, :s_prefixes, :load_log

  def initialize(data_dir=nil, **args)
    @rom_cache = {}
    @rom_cache_order = []
    @rom_max_cache_size = DEFAULT_ROM_MAX_CACHE_SIZE
    @rom_rules = Hash.new { |h, k| h[k] = [] }
    @scripts = {}
    @dict_bool = Hash.new(false)
    @dict_str = Hash.new('')
    @dict_int = Hash.new(0)
    @dict_num = Hash.new(nil)
    @num_props = {}
    @dict_set = Hash.new { |h, k| h[k] = Set.new }
    @fraction_connectors = {}
    @minus_signs = {}
    @plus_signs = {}
    @float2fraction = {}
    @rom_cache_size = 0
    @rom_max_cache_size = args[:cache_size] || 0
    @cache_p = (@rom_max_cache_size != 0)
    @hangul_rom = {}
    @stats = Hash.new(0)
    @abugida_cache = {}
    @rebuild_ud_props = args[:rebuild_ud_props] || false
    @rebuild_num_props = args[:rebuild_num_props] || false
    @load_log = args[:load_log] || false
    @n_error_messages_output = 0
    @n_non_utf8_characters = 0
    @data_dir = data_dir || self.class.default_data_dir(**args)
    @cjk = nil
    @hangul = nil
    @ud_props = {}
    @s_prefixes = Set.new

    load_resource_files(@data_dir, **args)
  end

  def self.default_data_dir(**args)
    script_dir = File.dirname(File.expand_path(__FILE__))
    data_dir = File.join(script_dir, 'data')
    puts "Default data directory: #{data_dir}"
    data_dir
  end

  def reset_cache(cache_size = DEFAULT_ROM_MAX_CACHE_SIZE)
    @rom_cache.clear
    @rom_cache_order.clear
    @rom_max_cache_size = cache_size
  end

  def second_rom_filter(c, rom, name)
    rom = rom.dup
    if c == ' '
      rom = ' ' if rom == '_'
    elsif c == "\t"
      rom = "\t"
    end
    [rom, '']
  end

  def load_rom_file(filename, provenance, file_format: nil, load_log: true)
    return unless File.exist?(filename)
    puts "Loading romanization rules from #{filename}" if load_log
    n_entries = 0

    File.foreach(filename).with_index(1) do |line, line_num|
      next if line.start_with?("#") || line.strip.empty?
      line = line.sub(/\s{2,}#.*$/, '')

      parts = line.split('::').map(&:strip)
      next if parts.empty?

      # Create a hash of the parts
      rule_parts = {}
      parts.each do |part|
        key_value = part.split(/\s+/, 2)
        next if key_value.length < 2
        rule_parts[key_value[0]] = key_value[1]
      end

      if file_format == 'u2r'
        t_at_end_of_syllable = nil
        u = dequote_string(rule_parts['u'])
        begin
          cp = u.to_i(16)
          s = [cp].pack('U*')
        rescue
          puts "Failed to convert unicode point at line #{line_num}: #{u}" if load_log
          next
        end
        t = dequote_string(rule_parts['r'])
        name = rule_parts['name']
        @dict_str["name", s] = name if name
        pic = rule_parts['pic']
        @dict_str["pic", s] = pic if pic
        tone_mark = rule_parts['tone-mark']
        @dict_str["tone-mark", s] = tone_mark if tone_mark
        syllable_info = rule_parts['syllable-info']
        @dict_str["syllable-info", s] = syllable_info if syllable_info
      else
        s = dequote_string(rule_parts['s'])
        t = dequote_string(rule_parts['t'])
        t_at_end_of_syllable = dequote_string(rule_parts['t-end-of-syllable'])
      end

      if s && t
        puts "  Loading rule: '#{s}' (#{s.ord.to_s(16)}) -> '#{t}'" if load_log && n_entries < 10
        register_s_prefix(s)
        n_entries += 1

        lcode_s = rule_parts['lcode']
        lcodes = lcode_s ? lcode_s.split(/[,;]\s*/) : []

        use_only_at_start_of_word = rule_parts.key?('use-only-at-start-of-word')
        dont_use_at_start_of_word = rule_parts.key?('dont-use-at-start-of-word')
        use_only_at_end_of_word = rule_parts.key?('use-only-at-end-of-word')
        dont_use_at_end_of_word = rule_parts.key?('dont-use-at-end-of-word')
        use_only_for_whole_word = rule_parts.key?('use-only-for-whole-word')

        t_alts = rule_parts['t-alt'] ? rule_parts['t-alt'].split(/[,;]\s*/).map { |s| dequote_string(s) } : []

        new_rom_rule = RomRule.new(
          s: s,
          t: t,
          prov: provenance,
          lcodes: lcodes,
          t_alts: t_alts,
          use_only_at_start_of_word: use_only_at_start_of_word,
          dont_use_at_start_of_word: dont_use_at_start_of_word,
          use_only_at_end_of_word: use_only_at_end_of_word,
          dont_use_at_end_of_word: dont_use_at_end_of_word,
          use_only_for_whole_word: use_only_for_whole_word,
          t_at_end_of_syllable: t_at_end_of_syllable
        )

        @rom_rules[s] ||= []
        @rom_rules[s] << new_rom_rule
      end
    end

    puts "Loaded #{n_entries} rules from #{filename}" if load_log
  end

  def load_script_file(filename, load_log: true)
    return unless File.exist?(filename)

    # Add default scripts if not already loaded
    add_default_scripts unless @scripts_loaded
    @scripts_loaded = true

    # Rest of the original load_script_file implementation
    puts "Loading scripts from #{filename}" if load_log
    File.foreach(filename).with_index do |line, line_num|
      next if line.start_with?("#") || line.strip.empty?
      parts = line.split('::')
      next if parts.size < 2
      script_name = parts[0].strip
      char_range = parts[1].strip
      @scripts[script_name] ||= Script.new(name: script_name, char_ranges: [])
      @scripts[script_name].char_ranges << char_range
    end
  end

  def extract_script_name(script_name_plus, full_char_name=nil)
    return nil if script_name_plus.nil?
    script_name_plus.split(/[;:]/).first
  end

  def load_unicode_data_props(filename, load_log: true)
    return unless File.exist?(filename)
    File.foreach(filename).with_index do |line, line_num|
      next if line.start_with?("#")
      fields = line.chomp.split(';')
      next if fields.size < 14
      char = [fields[0].to_i(16)].pack('U*')
      name = fields[1]
      category = fields[2]
      @ud_props[char] = {
        name: name,
        category: category,
        numeric_value: robust_str_to_num(fields[6]),
        combining_class: fields[3].to_i
      }
    end
  end

  def load_num_props(filename, load_log: true)
    return unless File.exist?(filename)
    File.foreach(filename).with_index do |line, line_num|
      next if line.start_with?("#") || line.strip.empty?
      parts = line.split(';')
      next if parts.size < 2
      char = parts[0].strip
      num_value = robust_str_to_num(parts[1].strip)
      @num_props[char] = num_value
    end
  end

  def de_accent_pinyin(s)
    s.gsub(/[āáǎà]/, 'a')
     .gsub(/[ēéěè]/, 'e')
     .gsub(/[īíǐì]/, 'i')
     .gsub(/[ōóǒò]/, 'o')
     .gsub(/[ūúǔù]/, 'u')
     .gsub(/[ǖǘǚǜ]/, 'ü')
  end

  def register_s_prefix(s)
    (1..s.length).each { |prefix_len| @s_prefixes.add(s[0, prefix_len]) }
  end

  def load_chinese_pinyin_file(filename, load_log: true)
    return unless File.exist?(filename)
    puts "Loading Chinese Pinyin file: #{filename}" if load_log

    File.foreach(filename) do |line|
      line.chomp!
      next if line.empty? || line.start_with?('#')  # Skip comments

      char, pinyin = line.split(/\t/)
      next unless char && pinyin

      # Register the rule with both 'zh' and 'cmn' language codes
      @rom_rules[char] ||= []
      @rom_rules[char] << RomRule.new(
        s: char,
        t: pinyin,
        prov: File.basename(filename),
        lcodes: ['zh', 'cmn']  # Add both zh and cmn language codes
      )

      register_s_prefix(char)
    end
  end

  def add_char_to_rebuild_unicode_data_dict(d, script_name, prop_class, char)
    key = "#{script_name}::#{prop_class}"
    d[key] ||= Set.new
    d[key] << char
  end

  def rebuild_unicode_data_props(out_filename, cjk: nil, hangul: nil)
    File.open(out_filename, 'w') do |f|
      @ud_props.each do |char, props|
        f.puts "#{char};#{props[:name]};#{props[:category]};#{props[:combining_class]};#{props[:numeric_value]}"
      end
    end
  end

  def rebuild_num_props(out_filename, err_filename)
    File.open(out_filename, 'w') do |out_f|
      File.open(err_filename, 'w') do |err_f|
        @num_props.each do |char, value|
          if value
            out_f.puts "#{char};#{value}"
          else
            err_f.puts "#{char};INVALID"
          end
        end
      end
    end
  end

  def load_resource_files(data_dir, **args)
    data_dir = Pathname.new(data_dir)
    puts "Loading resources from #{data_dir}"

    script_filename = data_dir.join('Scripts.txt')
    puts "Looking for scripts file at #{script_filename}"
    load_script_file(script_filename, load_log: @load_log) if File.exist?(script_filename)

    auto_rom_filename = data_dir.join('romanization-auto-table.txt')
    puts "Looking for auto-romanization file at #{auto_rom_filename}"
    if File.exist?(auto_rom_filename)
      load_rom_file(auto_rom_filename, 'romanization-auto-table.txt', file_format: 'rom', load_log: @load_log)
    end

    rom_filename = data_dir.join('romanization-table.txt')
    puts "Looking for romanization table at #{rom_filename}"
    if File.exist?(rom_filename)
      load_rom_file(rom_filename, 'romanization-table.txt', file_format: 'rom', load_log: @load_log)
    end

    ud_props_filename = data_dir.join('UnicodeDataProps.txt')
    puts "Looking for Unicode data properties at #{ud_props_filename}"
    if @rebuild_ud_props || !File.exist?(ud_props_filename)
      ud_orig_filename = data_dir.join('UnicodeData.txt')
      if File.exist?(ud_orig_filename)
        load_unicode_data_props(ud_orig_filename, load_log: @load_log)
        rebuild_unicode_data_props(ud_props_filename)
      end
    else
      load_unicode_data_props(ud_props_filename, load_log: @load_log)
    end

    num_props_filename = data_dir.join('NumProps.jsonl')
    puts "Looking for numeric properties at #{num_props_filename}"
    if @rebuild_num_props || !File.exist?(num_props_filename)
      num_orig_filename = data_dir.join('num-chars.txt')
      if File.exist?(num_orig_filename)
        load_num_props(num_orig_filename, load_log: @load_log)
        rebuild_num_props(num_props_filename, num_props_filename.sub_ext('.err.txt'))
      end
    else
      load_num_props(num_props_filename, load_log: @load_log)
    end

    cjk_rom_filename = data_dir.join('Chinese_to_Pinyin.txt')
    puts "Looking for CJK romanization at #{cjk_rom_filename}"
    if File.exist?(cjk_rom_filename)
      load_chinese_pinyin_file(cjk_rom_filename, load_log: @load_log)
    end

    lang_spec_rom_filename = data_dir.join('romanization-table-arabic-block.txt')
    puts "Looking for language-specific romanization at #{lang_spec_rom_filename}"
    if File.exist?(lang_spec_rom_filename)
      load_rom_file(lang_spec_rom_filename, 'romanization-table-arabic-block.txt', file_format: 'lang-spec', load_log: @load_log)
    end
  end



  def unicode_hangul_romanization(s, pass_through_p: false)
    return s if pass_through_p
    s.unicode_normalize(:nfd).gsub(/[
\u1160-\u11FF]/, '')
  end

  def char_is_nonspacing_mark?(s)
    return false if s.empty?
    c = s[0]
    @ud_props.dig(c, :category) == 'Mn'
  end

  def char_is_format_char(s)
    return false if s.empty?
    c = s[0]
    @ud_props.dig(c, :category) == 'Cf'
  end

  def char_is_space_separator(s)
    return false if s.empty?
    c = s[0]
    @ud_props.dig(c, :category) == 'Zs'
  end

  def chr_name(char)
    @ud_props.dig(char, :name) || ''
  end

  def num_value(s)
    @num_props[s] || robust_str_to_num(s)
  end

  def rom_rule_value(s, key)
    @rom_rules[s]&.first&.send(key)
  end

  def unicode_float2fraction(num, precision = 0.000001)
    int_part = num.to_i
    frac_part = num - int_part
    return [int_part, 1] if frac_part < precision

    a = 1
    b = 1
    (1..1000).each do |i|
      c = (frac_part * i).round
      if (c.to_f / i - frac_part).abs < precision
        return [int_part * i + c, i]
      end
    end
    nil
  end

  def chr_script_name(char)
    return nil if char.nil? || char.empty?
    char_code = char.unpack('U*').first

    @scripts.each do |script_name, script|
      script.char_ranges.each do |range|
        begin
          if range.include?('-')
            start_hex, end_hex = range.split('-')
            start_code = start_hex.to_i(16)
            end_code = end_hex.to_i(16)
          else
            start_code = end_code = range.to_i(16)
          end

          if char_code.between?(start_code, end_code)
            puts "  Matched #{script_name} range #{range} for char #{char.inspect} (hex: #{char_code.to_s(16)})" if @load_log
            return script_name
          end
        rescue => e
          puts "Error processing range #{range} for script #{script_name}: #{e}" if @load_log
        end
      end
    end

    puts "  No script found for char #{char.inspect} (hex: #{char_code.to_s(16)})" if @load_log
    nil
  end

  def test_output_of_selected_scripts_and_rom_rules
    puts "\nGreek rules sample:"
    letter_upper = "Α"
    letter_lower = "α"
    puts "Rules for #{letter_upper}:"
    if @rom_rules[letter_upper] && !@rom_rules[letter_upper].empty?
      @rom_rules[letter_upper].each_with_index do |rule, idx|
        puts "  Rule #{idx+1}: #{rule.inspect}"
      end
    else
      puts "  No rules for uppercase #{letter_upper}"
    end
    puts "Rules for #{letter_lower}:"
    if @rom_rules[letter_lower] && !@rom_rules[letter_lower].empty?
      @rom_rules[letter_lower].each_with_index do |rule, idx|
        puts "  Rule #{idx+1}: #{rule.inspect}"
      end
    else
      puts "  No rules for lowercase #{letter_lower}"
    end
    puts "\n@rom_rules keys sample (first 10):"
    @rom_rules.first(10).each do |key, rules|
      rules_str = rules.map(&:inspect).join(", ")
      puts "#{key.inspect} => #{rules_str}"
    end
    puts

    puts "Testing selected scripts and romanization rules:"
    test_str = "Α α, Β β, Γ γ"
    result = romanize_string(test_str)
    puts "Input: #{test_str}"
    puts "Result: #{result}"
    puts "Expected: A a, B b, G g"
    raise "Greek demo failed: got '#{result}', expected 'A a, B b, G g'" unless result == "A a, B b, G g"

    test_str = "А а, Б б, В в"
    result = romanize_string(test_str)
    puts "Input: #{test_str}"
    puts "Result: #{result}"
    puts "Expected: A a, B b, V v"

    test_str = "א ב ג"
    result = romanize_string(test_str)
    puts "Input: #{test_str}"
    puts "Result: #{result}"
    puts "Expected: ' b g"

    test_str = "ا ب ت"
    result = romanize_string(test_str)
    puts "Input: #{test_str}"
    puts "Result: #{result}"
    puts "Expected: ā b t"
  end

  def test_romanization
    puts "\nRunning romanization validation tests:"

    input = "Hello World"
    expected = "Hello World"
    actual = romanize_string(input)
    raise "Basic Latin test failed" unless actual == expected

    input = "Α α, Β β, Γ γ"
    expected = "A a, B b, G g"
    actual = romanize_string(input)
    raise "Greek test failed" unless actual == expected

    input = "Year 2024"
    expected = "Year 2024"
    actual = romanize_string(input)
    raise "Number test failed" unless actual == expected

    input = "Греческий 123 → Greek"
    expected = "GHriechieskii 123 → Greek"
    actual = romanize_string(input)
    raise "Mixed script test failed" unless actual == expected

    input = ""
    expected = ""
    actual = romanize_string(input)
    raise "Empty string test failed" unless actual == expected

    input = "@#%^&*"
    expected = "@#%^&*"
    actual = romanize_string(input)
    raise "Special chars test failed" unless actual == expected

    input = "你好"
    expected = "nǐhǎo"
    actual = romanize_string(input)
    raise "CJK test failed" unless actual == expected

    puts "All tests passed!"
  end

  def romanize_file(input_filename: nil, output_filename: nil, lcode: nil, direct_input: nil, **args)
    input_text = if direct_input && !direct_input.empty?
                   direct_input.join("\n")
                 elsif input_filename
                   File.read(input_filename)
                 elsif !STDIN.tty?
                   STDIN.read
                 else
                   ARGV.join(" ")
                 end
    result = romanize_string(input_text, lcode: lcode, **args)
    if output_filename
      File.write(output_filename, result)
    else
      puts result
    end
  end

  def apply_any_offset_to_cached_rom_result(cached_rom_result, offset: 0)
    if cached_rom_result.is_a?(Array)
      cached_rom_result.map { |e| Edge.new(e.start + offset, e.end + offset, e.s, e.annotation) }
    else
      cached_rom_result
    end
  end

  def decode_unicode_escapes(s)
    s.gsub(/\\u([\da-fA-F]{4})/) { |m| [Regexp.last_match(1).to_i(16)].pack('U*') }
  end

  def romanize_string_core(s, lcode, rom_format, offset: 0, **args)
    s = decode_unicode_escapes(s)
    lattice = Lattice.new(s, self, lcode)
    lattice.add_romanization(**args)

    case rom_format
    when RomFormat::STR
      result = lattice.edges.map { |e| e.s }.join
      puts "Debug - Input: #{s.inspect}, Result: #{result.inspect}" if @load_log
      result
    when RomFormat::EDGES
      lattice.edges
    else
      lattice.edges
    end
  end

  def romanize_string(s, lcode: nil, rom_format: RomFormat::STR, **args)
    return '' if s.nil? || s.empty?
    cache_key = [s, lcode, rom_format].hash
    return @rom_cache[cache_key] if @rom_cache.key?(cache_key)

    result = romanize_string_core(s, lcode, rom_format, **args)
    update_cache(cache_key, result)
    result
  end

  def add_default_scripts
    # Add essential scripts if not already loaded
    @scripts['Greek'] ||= Script.new(name: 'Greek', char_ranges: ['0370-03FF', '1F00-1FFF'])
    @scripts['Cyrillic'] ||= Script.new(name: 'Cyrillic', char_ranges: ['0400-04FF'])
    @scripts['Hebrew'] ||= Script.new(name: 'Hebrew', char_ranges: ['0590-05FF'])
    @scripts['Arabic'] ||= Script.new(name: 'Arabic', char_ranges: ['0600-06FF'])
    @scripts['Latin'] ||= Script.new(name: 'Latin', char_ranges: ['0000-007F', '0080-00FF', '0100-017F'])
    @scripts['Han'] ||= Script.new(name: 'Han', char_ranges: ['4E00-9FFF', '3000-303F'])  # CJK Unified Ideographs
    @scripts['Hiragana'] ||= Script.new(name: 'Hiragana', char_ranges: ['3040-309F'])     # Japanese Hiragana
    @scripts['Katakana'] ||= Script.new(name: 'Katakana', char_ranges: ['30A0-30FF'])     # Japanese Katakana
    @scripts['Hangul'] ||= Script.new(name: 'Hangul', char_ranges: ['AC00-D7AF', '1100-11FF', '3130-318F', 'A960-A97F', 'D7B0-D7FF'])  # Korean Hangul
    @scripts_loaded = true
    self
  end

  private

  def update_cache(key, result)
    if @rom_cache.size >= @rom_max_cache_size
      oldest_key = @rom_cache_order.shift
      @rom_cache.delete(oldest_key)
    end
    @rom_cache[key] = result
    @rom_cache_order << key
  end
end

class Edge
  attr_accessor :start, :end, :s, :annotation

  def initialize(start, end_, s, annotation=nil)
    @start = start
    @end = end_
    @s = s
    @annotation = annotation
  end

  def to_s
    "[#{@start}-#{@end}] #{@s}#{@annotation ? " (#{@annotation})" : ''}"
  end

  def self.json_str(rom_result)
    if rom_result.is_a?(String)
      rom_result
    else
      rom_result.map { |e| {start: e.start, end: e.end, text: e.s, annotation: e.annotation} }.to_json
    end
  end
end

class NumEdge < Edge
  attr_accessor :value, :fraction, :n_decimals, :num_base, :base_multiplier, :script, :e_type, :orig_txt

  def initialize(start, end_, s, uroman=nil, active: false)
    super(start, end_, s)
    @uroman = uroman
    @active = active
    @value = nil
    @fraction = nil
    @n_decimals = 0
    @num_base = 10
    @base_multiplier = 1
    @script = nil
    @e_type = 'num'
    @orig_txt = s.dup
    update
  end

  def update(value: nil, value_s: nil, fraction: nil, n_decimals: nil, num_base: nil, base_multiplier: nil, script: nil, e_type: nil, orig_txt: nil)
    @value = value || (value_s && @uroman.robust_str_to_num(value_s))
    @fraction = fraction ? Rational(fraction).to_f : nil
    @n_decimals = n_decimals if n_decimals
    @num_base = num_base if num_base
    @base_multiplier = base_multiplier if base_multiplier
    @script = script if script
    @e_type = e_type if e_type
    @orig_txt = orig_txt if orig_txt
    @s
  end

  def to_s
    super + " [value=#{@value}#{@fraction ? " fraction=#{@fraction}" : ''}]"
  end
end

class Lattice
  attr_accessor :edges, :s, :uroman, :lcode, :scripts_present

  def initialize(s, uroman, lcode=nil)
    @s = s
    @uroman = uroman
    @lcode = lcode
    @edges = []
    @scripts_present = Set.new
  end

  def check_for_scripts
    @s.each_char do |c|
      script_name = @uroman.chr_script_name(c)
      @scripts_present.add(script_name) if script_name
    end
  end

  def add_edge(edge)
    @edges << edge
  end

  def add_romanization(**args)
    check_for_scripts
    processed_indices = add_script_specific_rules(**args)
    number_indices = add_numbers(@uroman, **args)
    add_rom_fall_back_singles(processed_indices + number_indices, **args)
    @edges = filter_edges_by_priority
  end

  def add_script_specific_rules(**args)
    processed = Set.new
    @s.each_char.with_index do |c, i|
      script = @uroman.chr_script_name(c)
      if @uroman.load_log
        puts "Processing char: #{c.inspect} (hex: #{c.unpack('U*').first.to_s(16)})"
        puts "  Script: #{script.inspect}"
      end
      next unless script

      # Try using the rule for the character
      rom_rules = @uroman.rom_rules[c]

      if @uroman.load_log
        puts "  Direct rules for #{c.inspect}: #{rom_rules.inspect}"
      end

      # If no direct match, try lowercase version
      if !rom_rules || rom_rules.empty?
        c_lower = c.downcase
        rom_rules = @uroman.rom_rules[c_lower]
        if @uroman.load_log
          puts "  Lowercase rules for #{c_lower.inspect}: #{rom_rules.inspect}"
        end
      end

      next unless rom_rules && !rom_rules.empty?

      # Find the best matching rule
      best_rule = rom_rules.find { |r| @lcode && r.lcodes.include?(@lcode.to_s) } ||
        rom_rules.find { |r| r.prov && r.prov.include?(script) } ||
        rom_rules.first

      if @uroman.load_log
        puts "  Best rule: #{best_rule.inspect}"
      end

      if best_rule
        rom = best_rule.t || c
        # If the original char is uppercase, but we had to use the downcase rule, upcase the output
        rom = rom.upcase if c == c.upcase && c != c.downcase && !@uroman.rom_rules[c]

        # Check word position constraints
        at_start = is_at_start_of_word(i)
        at_end = is_at_end_of_word(i + c.length)

        next if best_rule.use_only_at_start_of_word && !at_start
        next if best_rule.dont_use_at_start_of_word && at_start
        next if best_rule.use_only_at_end_of_word && !at_end
        next if best_rule.dont_use_at_end_of_word && at_end
        next if best_rule.use_only_for_whole_word && !(at_start && at_end)

        if @uroman.load_log
          puts "  Adding edge: #{rom.inspect} (#{i}-#{i + c.length})"
        end

        @edges << Edge.new(i, i + c.length, rom, "script-#{script}")
        processed.add(i)
      end
    end
    processed
  end

  def add_numbers(uroman, **args)
    scanner = StringScanner.new(@s)
    current_pos = 0
    processed_indices = Set.new

    while !scanner.eos?
      if scanner.scan(/\d+/)
        num_str = scanner.matched
        start_pos = current_pos
        end_pos = current_pos + num_str.length

        # Add number edge
        edge = NumEdge.new(start_pos, end_pos, num_str, uroman)
        @edges << edge

        # Mark all number positions as processed
        (start_pos...end_pos).each { |i| processed_indices.add(i) }

        current_pos = end_pos
      else
        scanner.getch
        current_pos += 1
      end
    end

    processed_indices  # Return the processed number indices
  end

  def add_rom_fall_back_singles(processed_indices, **args)
    @s.each_char.with_index do |c, i|
      next if processed_indices.include?(i)
      @edges << Edge.new(i, i+1, c, 'fallback')
    end
  end

  def is_at_start_of_word(position)
    return true if position == 0
    prev_char = @s[position-1]
    !(prev_char.match?(/\p{L}/) || prev_char.match?(/\p{M}/))
  end

  def is_at_end_of_word(position)
    return true if position >= @s.length
    next_char = @s[position]
    !(next_char.match?(/\p{L}/) || next_char.match?(/\p{M}/))
  end

  private

  def filter_edges_by_priority
    edge_groups = @edges.group_by { |e| e.start }
    edge_groups.sort.flat_map do |pos, edges|
      script_edges = edges.select { |e| e.annotation && e.annotation.start_with?('script-') }
      num_edges = edges.select { |e| e.is_a?(NumEdge) }
      fallback_edges = edges - script_edges - num_edges
      script_edges.any? ? script_edges : num_edges.any? ? num_edges : fallback_edges
    end
  end
end

# Main function equivalent

def main
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: ruby uroman.rb [options]"
    opts.on("-i", "--input FILE", "Input file") { |f| options[:input_file] = f }
    opts.on("-o", "--output FILE", "Output file") { |f| options[:output_file] = f }
    opts.on("-l", "--lcode CODE", "Language code") { |c| options[:lcode] = c }
    opts.on("-v", "--verbose", "Verbose output") { options[:verbose] = true }
    opts.on("--rebuild-ud-props", "Rebuild Unicode data properties") { options[:rebuild_ud_props] = true }
    opts.on("--rebuild-num-props", "Rebuild numeric properties") { options[:rebuild_num_props] = true }
    opts.on("--test", "Run tests") { options[:test] = true }
  end.parse!

  uroman = Uroman.new(nil,
                      rebuild_ud_props: options[:rebuild_ud_props],
                      rebuild_num_props: options[:rebuild_num_props],
                      load_log: options[:verbose] || options[:test])

  if options[:test]
    uroman.test_output_of_selected_scripts_and_rom_rules
    uroman.test_romanization
    exit
  end

  input_text = if options[:input_file]
                 File.read(options[:input_file])
               else
                 ARGV.join(' ')
               end

  result = uroman.romanize_string(input_text, lcode: options[:lcode])

  if options[:output_file]
    File.write(options[:output_file], result)
  else
    puts result
  end
end

main if __FILE__ == $0
