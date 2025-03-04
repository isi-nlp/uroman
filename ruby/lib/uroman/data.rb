# frozen_string_literal: true

require 'set'
require 'json'
require 'unicode/categories'

require_relative 'util'
require_relative 'dict'
require_relative 'lattice'

module Uroman
  # This class loads and maintains uroman data independent of any specific text corpus.
  # Typically, only a single instance will be used. (In contrast to multiple lattice instances, one per text.)
  # Methods include some testing. And finally methods to romanize a string (romanize_string) or an entire file
  # (romanize_file).
  class Data
    DEFAULT_ROM_MAX_CACHE_SIZE = 65536

    ROM_FORMAT_STR = 'str'
    ROM_FORMAT_EDGES = 'edges'
    ROM_FORMAT_ALTS = 'alts'
    ROM_FORMAT_LATTICE = 'lattice'

    HANGUL_LEADS = %w[g gg n d dd r m b bb s ss - j jj c k t p h].freeze
    HANGUL_VOWELS = %w[a ae ya yae eo e yeo ye o wa wai oe yo u weo we wi yu eu yi i].freeze
    HANGUL_TAILS = %w[- g gg gs n nj nh d l lg lm lb ls lt lp lh m b bs s ss ng j c k t p h].freeze
    # TODO: check this Jamo tables
    # initials = %w[g kk n d tt r m b pp s ss _ j jj ch k t p h]
    # medials = %w[a ae ya yae eo e yeo ye o wa wae oe yo u wo we wi yu eu yi i]
    # finals = [''] + %w[g k kk k n n j t l l m p p l s s ng j ch ch k t p h]

    attr_accessor :data_dir,
                  :rom_rules,
                  :scripts,
                  :dict_bool,
                  :dict_str,
                  :dict_int,
                  :dict_num,
                  :num_props,
                  :dict_set,
                  :fraction_connectors,
                  :minus_signs,
                  :plus_signs,
                  :float2fraction,
                  :rom_cache,
                  :rom_cache_size,
                  :rom_max_cache_size,
                  :cache_p,
                  :hangul_rom,
                  :stats,
                  :abugida_cache,
                  :n_error_messages_output,
                  :n_non_utf8_characters

    def initialize(data_dir = nil, **kwargs)
      @data_dir = data_dir || self.class.default_data_dir(**kwargs)
      @rom_rules = Hash.new { |h, k| h[k] = [] }
      @scripts = Hash.new { |h, k| h[k] = Script.new }
      @dict_bool = Hash.new(false)
      @dict_str = Hash.new { |h, k| h[k] = +'' }
      @dict_int = Hash.new(0)
      @dict_num = Hash.new(nil) # values are int (most common), float, or string ("1/2")
      @num_props = Hash.new { |h, k| h[k] = {} }
      @dict_set = Hash.new { |h, k| h[k] = Set.new }
      @fraction_connectors = {}
      @minus_signs = {}
      @plus_signs = {}
      @float2fraction = {}
      GC.disable
      @rom_cache = {}
      @rom_cache_size = 0
      @rom_max_cache_size = kwargs[:cache_size] || 0
      @cache_p = (@rom_max_cache_size != 0)
      @hangul_rom = {}
      @stats = Hash.new(0)
      @abugida_cache = {}
      load_resource_files(@data_dir, **kwargs.slice(:load_log, :rebuild_ud_props, :rebuild_num_props))
      GC.enable
      @n_error_messages_output = 0
      @n_non_utf8_characters = 0
    end

    def self.default_data_dir(**kwargs)
      root_dir = File.expand_path(File.dirname(__FILE__))
      data_dir = File.expand_path('data', root_dir)
      mini_test_dir = File.expand_path('mini-test', root_dir)
      if kwargs[:verbose]
        warn "data_dir: #{data_dir}"
        warn "mini_test_dir: #{mini_test_dir}"
      end
      data_dir
    end

    def reset_cache(cache_size = DEFAULT_ROM_MAX_CACHE_SIZE)
      @rom_cache = {}
      @rom_cache_size = 0
      @rom_max_cache_size = cache_size
      @cache_p = (cache_size != 0)
    end

    def second_rom_filter(c, rom, name = nil)
      return [c, name] if rom.nil? || !rom.include?(" ")
      name ||= chr_name(c)
      if name.include?('MYANMAR VOWEL SIGN KAYAH')
        return [$1, name] if rom.match(/kayah\s+(\S+)\s*$/)
      elsif name.include?('MENDE KIKAKUI SYLLABLE')
        return [$1, name] if rom.match(/m\d+\s+(\S+)\s*$/)
      elsif rom.match(/\S\s+\S/)
        return [c, name]
      end
      [nil, name]
    end

    def load_rom_file(filename, provenance, file_format = nil, load_log = true)
      n_entries = 0
      unless File.exist?(filename)
        warn "Cannot open file #{filename}"
        return
      end

      File.foreach(filename).with_index(1) do |line, line_number|
        next if line.start_with?('#') || line.strip.empty?
        line.gsub!(/\s{2,}#.*$/, '')

        if file_format == 'u2r'
          u = dequote_string(Util.slot_value_in_double_colon_del_list(line, 'u'))
          begin
            cp = Integer(u, 16)
            s = cp.chr(Encoding::UTF_8)
          rescue ArgumentError
            next
          end
          t = dequote_string(Util.slot_value_in_double_colon_del_list(line, 'r'))
        else
          s = dequote_string(Util.slot_value_in_double_colon_del_list(line, 's'))
          t = dequote_string(Util.slot_value_in_double_colon_del_list(line, 't'))
        end

        if (num_s = Util.slot_value_in_double_colon_del_list(line, 'num'))
          num = robust_str_to_num(num_s)
          @dict_num[s] = num.nil? ? num_s : num
        end

        if Util.slot_value_in_double_colon_del_list(line, 'is-minus-sign')
          @minus_signs[s] = true
        end
        if Util.slot_value_in_double_colon_del_list(line, 'is-plus-sign')
          @plus_signs[s] = true
        end

        lcode_s = Util.slot_value_in_double_colon_del_list(line, 'lcode')
        lcodes = lcode_s ? lcode_s.split(/[;,]\s*/) : []

        new_rom_rule = RomRule.new(s: s, t: t, prov: provenance, lcodes: lcodes)
        @rom_rules[s] << new_rom_rule
        n_entries += 1
      end

      warn "Loaded #{n_entries} from #{filename}" if load_log
    end

    def load_script_file(filename, load_log = true)
      n_entries = 0
      max_n_script_name_components = 0
      return unless File.exist?(filename)

      File.foreach(filename).with_index(1) do |line, line_number|
        next if line.start_with?('#') || line.strip.empty?
        line.gsub!(/\s{2,}#.*$/, '')

        if (script_name = Util.slot_value_in_double_colon_del_list(line, 'script-name'))
          lc_script_name = script_name.downcase
          if @scripts[lc_script_name]
            warn "** Ignoring duplicate script \"#{script_name}\" in line #{line_number} of #{filename}"
          else
            n_entries += 1
            direction = Util.slot_value_in_double_colon_del_list(line, 'direction')
            abugida_default_vowel_s = Util.slot_value_in_double_colon_del_list(line, 'abugida-default-vowel')
            abugida_default_vowels = abugida_default_vowel_s ? abugida_default_vowel_s.split(/[;,]\s*/) : []
            alt_script_name_s = Util.slot_value_in_double_colon_del_list(line, 'alt-script-name')
            alt_script_names = alt_script_name_s ? alt_script_name_s.split(/[;,]\s*/) : []
            language_s = Util.slot_value_in_double_colon_del_list(line, 'language')
            languages = language_s ? language_s.split(/[;,]\s*/) : []

            new_script = Script.new(script_name: script_name, alt_script_names: alt_script_names, languages: languages,
                                    direction: direction, abugida_default_vowels: abugida_default_vowels)
            @scripts[lc_script_name] = new_script

            languages.each { |language| @dict_set[['scripts', language]] << script_name }
            alt_script_names.each do |alt_script_name|
              lc_alt_script_name = alt_script_name.downcase
              if @scripts[lc_alt_script_name]
                warn "** Ignoring duplicate alternative script name \"#{script_name}\" in line #{line_number} of #{filename}"
              else
                @scripts[lc_alt_script_name] = new_script
              end
            end
          end

          n_script_name_components = script_name.split.size
          max_n_script_name_components = [max_n_script_name_components, n_script_name_components].max
        end
      end

      @dict_int['max_n_script_name_components'] = max_n_script_name_components if max_n_script_name_components > 0
      warn "Loaded #{n_entries} script descriptions from #{filename} (max_n_scripts_name_components: #{max_n_script_name_components})" if load_log
    end

    def extract_script_name(script_name_plus, full_char_name = nil)
      return nil if full_char_name && script_name_plus == full_char_name

      while script_name_plus
        key = script_name_plus.downcase
        if @scripts.key?(key)
          script = @scripts[key]
          return script['script-name'] if script && script['script-name']
        end
        script_name_plus = script_name_plus.sub(/\s*\S*\s*$/, '')
      end
      nil
    end

    def load_unicode_data_props(filename, load_log = true)
      n_script = n_script_char = n_script_vowel_sign = n_script_medial_consonant_sign = n_script_virama = 0

      begin
        file = File.open(filename, 'r:utf-8')
      rescue Errno::ENOENT
        STDERR.puts "Cannot open file #{filename}"
        return
      end

      file.each_line.with_index(1) do |line, line_number|
        next if line.start_with?('#') || line.strip.empty?

        line.gsub!(/\s{2,}#.*/, '')
        if (script_name = Util.slot_value_in_double_colon_del_list(line, 'script-name'))
          n_script += 1
          ['char', 'numeral'].each do |key|
            Util.slot_value_in_double_colon_del_list(line, key, []).each do |char|
              @dict_str[['script', char]] = script_name
              n_script_char += 1
            end
          end
          {
            'vowel-sign' => :n_script_vowel_sign,
            'medial-consonant-sign' => :n_script_medial_consonant_sign,
            'sign-virama' => :n_script_virama
          }.each do |key, var|
            Util.slot_value_in_double_colon_del_list(line, key, []).each do |char|
              @dict_bool[["is-#{key}", char]] = true
              instance_variable_set(var, instance_variable_get(var) + 1)
            end
          end
        end
      end

      if load_log
        STDERR.puts "Loaded from #{filename} mappings of #{n_script_char} characters to #{n_script} script(s)" \
                      + ", with a total of #{n_script_vowel_sign} vowel signs, #{n_script_medial_consonant_sign} medial consonant signs and #{n_script_virama} viramas." if n_script_vowel_sign.positive? || n_script_virama.positive? || n_script_medial_consonant_sign.positive?
      end
    end

    def load_num_props(filename, load_log = true)
      n_entries = 0
      begin
        file = File.open(filename, 'r:utf-8')
      rescue Errno::ENOENT
        STDERR.puts "Cannot open file #{filename}"
        return
      end

      file.each_line.with_index(1) do |line, line_number|
        next if line.start_with?('#') || line.strip.empty?
        d = JSON.parse(line) rescue nil
        if d.is_a?(Hash) && d.key?('txt')
          @num_props[d['txt']] = d
          n_entries += 1
          @dict_bool[['is-large-power', d['txt']]] = true if d['is-large-power']
        else
          STDERR.puts "Invalid JSON format in line #{line_number} in file #{filename}: #{line.strip}"
        end
      end
      STDERR.puts "Loaded #{n_entries} entries from #{filename}" if load_log
    end

    def self.de_accent_pinyin(s)
      result = ''
      s.each_char do |char|
        decomposed = UnicodeUtils.nfd(char).gsub(/[^\p{L}]/, '')
        result << (decomposed.empty? ? char : decomposed)
      end
      result.gsub('ü', 'u')
    end

    def register_s_prefix(s)
      (1..s.length).each { |prefix_len| @dict_bool[['s-prefix', s[0, prefix_len]]] = true }
    end

    def load_chinese_pinyin_file(filename, load_log = true)
      n_entries = 0
      begin
        file = File.open(filename, 'r:utf-8')
      rescue Errno::ENOENT
        STDERR.puts "Cannot open file #{filename}"
        return
      end

      file.each_line.with_index(1) do |line, line_number|
        next if line.start_with?('#') || line.strip.empty?
        begin
          chinese, pinyin = line.strip.split
          rom = self.class.de_accent_pinyin(pinyin)
          @rom_rules[chinese] << { s: chinese, t: rom, prov: 'rom pinyin', lcodes: [] }
          register_s_prefix(chinese)
          n_entries += 1
        rescue StandardError
          STDERR.puts "Cannot process line #{line_number} in file #{filename}: #{line}"
        end
      end
      STDERR.puts "Loaded #{n_entries} script descriptions from #{filename}" if load_log
    end

    def self.add_char_to_rebuild_unicode_data_dict(d, script_name, prop_class, char)
      d['script-names'] ||= Set.new
      d['script-names'].add(script_name)
      key = [script_name, prop_class]
      d[key] ||= []
      d[key] << char
    end

    def rebuild_unicode_data_props(out_filename, cjk: nil, hangul: nil)
      d = { 'script-names' => Set.new }
      vowel_s = ''
      n_script_refs = 0
      codepoint = -1
      prop_classes = Set.new(['char'])

      while codepoint < 0xF0000
        codepoint += 1
        c = codepoint.chr(Encoding::UTF_8)
        char_name = chr_name(c)
        next unless char_name

        [['VOWEL SIGN'],
         ['MEDIAL CONSONANT SIGN', 'CONSONANT SIGN MEDIAL', 'CONSONANT SIGN SHAN MEDIAL', 'CONSONANT SIGN MON MEDIAL'],
         ['SIGN VIRAMA', 'SIGN ASAT', 'AL-LAKUNA', 'SIGN COENG', 'SIGN PAMAAEH', 'CHARACTER PHINTHU'],
         ['NUMERAL', 'NUMBER', 'DIGIT', 'FRACTION']].each do |prop_list|
          prop_class = prop_list.first.downcase.gsub(' ', '-')
          prop_classes.add(prop_class)
          script_name_cand = char_name.gsub(/\s+#{prop_list.first}\b.*/, '')
          script_name = extract_script_name(script_name_cand, char_name)
          next unless script_name

          self.class.add_char_to_rebuild_unicode_data_dict(d, script_name, prop_class, c)
        end

        script_name_cand = char_name.gsub(/\s+(CONSONANT|LETTER|LIGATURE|SIGN|SYLLABLE|SYLLABICS|VOWEL|IDEOGRAPH|HIEROGLYPH|POINT|ACCENT|CHARACTER|TIPPI|ADDAK|IRI|URA|SYMBOL GENITIVE|SYMBOL COMPLETED|SYMBOL LOCATIVE|SYMBOL AFOREMENTIONED|AU LENGTH MARK)\b.*/, '')
        script_name = extract_script_name(script_name_cand, char_name)
        if script_name
          self.class.add_char_to_rebuild_unicode_data_dict(d, script_name, 'char', c)
          n_script_refs += 1
        end

        rom = romanize_string(c)
        vowel_s += c if rom.match?(/^[aeiou]*[aeiouy]$/i)
      end

      prop_classes = prop_classes.to_a.sort
      out_filenames = [out_filename, cjk, hangul].compact
      cjk2 = cjk || out_filename
      hangul2 = hangul || out_filename

      out_filenames.each do |out_file|
        begin
          File.open(out_file, 'w:utf-8') do |f_out|
            d['script-names'].sort.each do |script_name|
              next if script_name == 'CJK' && out_file != cjk2
              next if script_name == 'Hangul' && out_file != hangul2
              next if script_name != 'CJK' && script_name != 'Hangul' && out_file != out_filename

              prop_components = ["::script-name #{script_name}"]
              prop_classes.each do |prop_class|
                key = [script_name, prop_class]
                next unless d[key]

                chars = d[key].join
                prop_components << "::n-#{prop_class} #{chars.length}" if prop_class == 'char'
                prop_components << "::#{prop_class} #{chars}"
              end

              f_out.puts prop_components.join(' ')
            end
            f_out.puts "::vowels #{vowel_s}" if out_file == out_filename && !vowel_s.empty?
          end
        rescue StandardError => e
          warn "Cannot write to file #{out_file}: #{e.message}"
        end
      end
      warn "Rebuilt #{out_filenames} with #{n_script_refs} characters for #{d['script-names'].length} scripts."
    end

    def rebuild_num_props(out_filename, err_filename)
      n_out, n_err = 0, 0
      codepoint = -1

      File.open(out_filename, 'w:utf-8') do |f_out|
        File.open(err_filename, 'w:utf-8') do |f_err|
          while codepoint < 0xF0000
            codepoint += 1
            char = codepoint.chr(Encoding::UTF_8)
            num = Util.first_non_nil(Util.ud_numeric(char), num_value(char))
            next if num.nil?

            result_dict = {}
            orig_txt = char
            value = nil
            fraction = nil
            num_base = nil
            base_multiplier = nil
            script = nil
            is_large_power = dict_bool[['is-large-power', char]]

            script_name = chr_script_name(char)
            script = script_name || (char =~ /[0-9]/ ? 'ascii-digit' : nil)
            name = chr_name(char)
            exclude_from_number_processing = false

            ['SUPERSCRIPT', 'SUBSCRIPT', 'CIRCLED', 'PARENTHESIZED', 'SEGMENTED', 'MATHEMATICAL', 'ROMAN NUMERAL', 'FULL STOP', 'COMMA'].each do |scrypt_type|
              if name.include?(scrypt_type)
                script = "*#{scrypt_type.downcase.gsub(' ', '-')}"
                exclude_from_number_processing = true
                break
              end
            end

            if exclude_from_number_processing
              next
            elsif name.include?('VULGAR FRACTION')
              script = 'vulgar-fraction'
            end

            num_type = if num.is_a?(Integer)
                         value = num
                         if (0..9).include?(num)
                           num_base = 1
                           base_multiplier = num
                           name.include?('DIGIT') ? 'digit' : 'digit-like'
                         elsif (m = num.to_s.match(/([0-9]+?)(0*)$/))
                           base_multiplier = m[1].to_i
                           num_base = "1#{m[2]}".to_i
                           base_multiplier == 1 ? 'base' : 'multi'
                         else
                           'other-int'
                         end
                       elsif name.include?('FRACTION') && (fraction = fraction_char2fraction(char, num))
                         'fraction'
                       else
                         'other-num'
                       end

            rom = "#{value}#{fraction ? " #{fraction.numerator}/#{fraction.denominator}" : ''}".strip
            Util.add_non_nil_to_hash(result_dict, 'txt', orig_txt)
            Util.add_non_nil_to_hash(result_dict, 'rom', rom)
            Util.add_non_nil_to_hash(result_dict, 'value', value)
            Util.add_non_nil_to_hash(result_dict, 'fraction', fraction ? [fraction.numerator, fraction.denominator] : nil)
            Util.add_non_nil_to_hash(result_dict, 'type', num_type)
            result_dict['is-large-power'] = true if is_large_power
            Util.add_non_nil_to_hash(result_dict, 'base', num_base)
            Util.add_non_nil_to_hash(result_dict, 'mult', base_multiplier)
            Util.add_non_nil_to_hash(result_dict, 'script', script)

            if num_type.start_with?('other')
              Util.add_non_nil_to_hash(result_dict, 'name', name)
              f_err.puts result_dict.to_json
              n_err += 1
            else
              Util.add_non_nil_to_hash(result_dict, 'name', name) unless script
              f_out.puts result_dict.to_json
              n_out += 1
            end
          end
        end
      end
      warn "Processed #{codepoint} codepoints,\n  wrote #{n_out} lines to #{out_filename}\n    and #{n_err} lines to #{err_filename}"
    end

    def load_resource_files(data_dir, load_log: false, rebuild_ud_props: false, rebuild_num_props: false)
      unless data_dir.is_a?(Pathname)
        warn "Error: data_dir is of #{data_dir.class}, not a Pathname. Cannot load any resource files."
        return
      end

      load_rom_file(File.join(data_dir, 'romanization-auto-table.txt'), 'ud', file_format: 'rom', load_log: load_log)
      load_rom_file(File.join(data_dir, 'UnicodeDataOverwrite.txt'), 'ow', file_format: 'u2r', load_log: load_log)
      load_rom_file(File.join(data_dir, 'romanization-table.txt'), 'man', file_format: 'rom', load_log: load_log)
      load_chinese_pinyin_file(File.join(data_dir, 'Chinese_to_Pinyin.txt'), load_log: load_log)
      load_script_file(File.join(data_dir, 'Scripts.txt'), load_log: load_log)
      load_num_props(File.join(data_dir, 'NumProps.jsonl'), load_log: load_log)

      %w[UnicodeDataProps.txt UnicodeDataPropsCJK.txt UnicodeDataPropsHangul.txt].each do |base_file|
        load_unicode_data_props(File.join(data_dir, base_file), load_log: load_log)
      end

      if rebuild_ud_props
        rebuild_unicode_data_props(File.join(data_dir, 'UnicodeDataProps.txt'),
                                   cjk: File.join(data_dir, 'UnicodeDataPropsCJK.txt'),
                                   hangul: File.join(data_dir, 'UnicodeDataPropsHangul.txt'))
      end

      if rebuild_num_props
        rebuild_num_props(File.join(data_dir, 'NumProps.jsonl'),
                          File.join(data_dir, 'NumPropsRejects.jsonl'))
      end
    end

    def unicode_hangul_romanization(s, pass_through_p: false)
      return @hangul_rom[s] if @hangul_rom.key?(s)

      result = +''
      s.each_char do |c|
        cp = c.ord
        if (0xAC00..0xD7A3).include?(cp)
          code = cp - 0xAC00
          lead_index = code / (28 * 21)
          vowel_index = (code / 28) % 21
          tail_index = code % 28
          rom = "#{HANGUL_LEADS[lead_index]}#{HANGUL_VOWELS[vowel_index]}#{HANGUL_TAILS[tail_index]}".gsub('-', '')
          @hangul_rom[c] = rom
          result += rom
        elsif pass_through_p
          result += c
        end
      end
      result
    end

    def chr_name(char)
      Unicode::Name.of(char)
    rescue StandardError
      @dict_str[['name', char]] || ""
    end

    def num_value(s)
      return nil unless @rom_rules.key?(s)

      @rom_rules[s].each do |rom_rule|
        return rom_rule['num'] if rom_rule['num']
      end
      nil
    end

    def rom_rule_value(s, key)
      return nil unless @rom_rules.key?(s)

      @rom_rules[s].each do |rom_rule|
        return rom_rule[key] if rom_rule.key?(key)
      end
      nil
    end

    def unicode_float2fraction(num, precision: 0.000001)
      return @float2fraction[num] if @float2fraction.key?(num)

      (1..11).each do |numerator|
        [2, 3, 4, 5, 6, 8, 12, 16, 20, 32, 40, 64, 80, 160, 320].each do |denominator|
          if (numerator.to_f / denominator - num).abs < precision
            result = [numerator, denominator]
            @float2fraction[num] = result
            return result
          end
        end
      end
      nil
    end

    # For letters, diacritics, numerals etc.
    def chr_script_name(char)
      @dict_str[['script', char]]
    end

    # Low level test function that checks and displays romanization information.
    def test_output_of_selected_scripts_and_rom_rules
      output = ""
      { "Oriya" => scripts["oriya"], "Chinese" => scripts["chinese"] }.each do |s, d|
        output += "SCRIPT #{s} #{d}\n"
      end

      %w[ƿ β и μπ ⠹ 亿 ちょ и 𓍧 正 分之 ऽ ศ ด์ ढ़ ड़].each do |s|
        d = rom_rules[s]
        output += "DICT #{s} #{d}\n"
      end

      %w[ƿ β न ु].each do |s|
        output += "SCRIPT-NAME #{s} #{chr_script_name(s)}\n"
      end

      %W[万 \uF8F7 \u{13368} \u{1308B} \u0E48 \u0E40].each do |s|
        name = chr_name(s)
        num = dict_num[s]
        pic = dict_str[["pic", s]]
        tone_mark = dict_str[["tone-mark", s]]
        syllable_info = dict_str[["syllable-info", s]]
        is_large_power = dict_bool[["is-large-power", s]]
        output += "PROPS #{s}"
        output += "  name: #{name}" if name
        output += "  num: #{num} (#{num.class})" if num
        output += "  pic: #{pic}" if pic
        output += "  tone-mark: #{tone_mark}" if tone_mark
        output += "  syllable-info: #{syllable_info}" if syllable_info
        output += "  is-large-power: #{is_large_power}" if is_large_power
        output += "\n"
      end

      mayan12 = "\u{1D2EC}"
      egyptian600 = "𓍧"
      runic90 = "𐍁"
      klingon2 = "\uF8F2"

      "9九万萬百፲፱፻፸¾0²₂AⅫ⑫൵#{runic90}#{mayan12}#{egyptian600}#{klingon2}".each_char.with_index do |c, offset|
        output += "NUM-EDGE: #{NumEdge.new(offset, offset + 1, c, self)}\n"
      end

      %W[\u00bc \u0968].each do |s|
        output += "NUM-PROPS: #{num_props[s]}\n"
      end
      puts output
    end

    def test_romanization(**kwargs)
      tests = [['ألاسكا', nil], ['यह एक अच्छा अनुवाद है.', 'hin'],
               ['ちょっとまってください', 'kor'], ['Μπανγκαλόρ', 'ell'],
               ['Зеленський', 'ukr'], ['കേരളം', 'mal']]
      tests.each do |test|
        s, lcode = test
        rom = romanize_string(s, lcode: lcode, **kwargs)
        warn "ROM #{s} -> #{rom}"
      end

      n_alerts = 0
      codepoint = -1
      while codepoint < 0xF0000
        codepoint += 1
        c = codepoint.chr(Encoding::UTF_8) rescue next
        rom = romanize_string(c)
        if rom.match?(/\s/) && rom.match?(/\S/)
          name = chr_name(c)
          warn "U+#{codepoint.to_s(16).upcase} #{c} #{name}  #{rom}"
          n_alerts += 1
        end
      end
      warn "#{n_alerts} alerts for roms with spaces"
    end

    def romanize_file(input_filename: nil, output_filename: nil, lcode: nil, direct_input: nil, **kwargs)
      f_in = case input_filename
             when nil then direct_input || $stdin
             when String then File.open(input_filename, 'r', encoding: 'utf-8') rescue (warn "Error: Cannot open #{input_filename}"; return)
             else warn "Error: Wrong type for input_filename"; return
             end

      f_out = case output_filename
              when nil then $stdout
              when String then File.open(output_filename, 'w', encoding: 'utf-8') rescue (warn "Error: Cannot write to #{output_filename}"; return)
              else warn "Error: Wrong type for output_filename"; return
              end

      f_in.each_with_index do |line, line_number|
        if contains_surrogate_chars?(line)
          warn "Encoding error at line #{line_number + 1}"  # Handling surrogate errors
        end
        f_out.puts romanize_string(line.strip, lcode, **kwargs)
        break if kwargs[:max_lines] && line_number >= kwargs[:max_lines]
      end
    ensure
      f_in&.close if input_filename
      f_out&.close if output_filename
    end

    def self.apply_any_offset_to_cached_rom_result(cached_rom_result, offset = 0)
      return cached_rom_result if cached_rom_result.is_a?(String)
      return cached_rom_result if offset == 0

      cached_rom_result.map do |edge|
        Edge.new(edge.start + offset, edge.finish + offset, edge.txt, edge.type)
      end
    end

    def self.decode_unicode_escapes(s)
      if s.match(/\\[xuU][0-9A-Fa-f]{2}/)
        result = ""
        rest = s
        while rest =~ /(.*?)(\\x[0-9a-fA-F]{2}|\\u[0-9a-fA-F]{4}|\\U[0-9a-fA-F]{8})(.*)$/
          pre, core, rest = $1, $2, $3
          cp = core[2..].to_i(16)

          if cp > 0x80
            result += pre + cp.chr(Encoding::UTF_8)
          else
            result += pre + core
          end
        end
        result + rest + (s.end_with?("\n") ? "\n" : "")
      else
        s
      end
    end

    def romanize_string_core(s, lcode = nil, rom_format = ROM_FORMAT_STR, offset = 0, **kwargs)
      if @cache_p
        cached_rom = @rom_cache[[s, lcode, rom_format]]
        return self.class.apply_any_offset_to_cached_rom_result(cached_rom, offset) if cached_rom
      end

      lat = Lattice.new(s, self, lcode)
      lat.pick_tibetan_vowel_edge(**kwargs)
      lat.prep_braille(**kwargs)
      lat.add_romanization(**kwargs)
      lat.add_numbers(self, **kwargs)
      lat.add_braille_numbers(**kwargs)
      lat.add_rom_fall_back_singles(**kwargs)

      if rom_format == ROM_FORMAT_LATTICE
        all_edges = lat.all_edges(0, s.length)
        lat.add_alternatives(all_edges)
        if @rom_cache_size < @rom_max_cache_size
          @rom_cache[[s, lcode, rom_format]] = all_edges
          @rom_cache_size += 1
        end
        self.class.apply_any_offset_to_cached_rom_result(all_edges, offset)
      else
        best_edges = lat.best_rom_edge_path(0, s.length)
        if [ROM_FORMAT_EDGES, ROM_FORMAT_ALTS].include?(rom_format)
          lat.add_alternatives(best_edges) if rom_format == ROM_FORMAT_ALTS
          if @rom_cache_size < @rom_max_cache_size
            @rom_cache[[s, lcode, rom_format]] = best_edges
            @rom_cache_size += 1
          end
          self.class.apply_any_offset_to_cached_rom_result(best_edges, offset)
        else
          rom = Lattice.edge_path_to_surf(best_edges)
          if @rom_cache_size < @rom_max_cache_size
            @rom_cache[[s, lcode, rom_format]] = rom
            @rom_cache_size += 1
          end
          rom
        end
      end
    end

    def romanize_string(s, lcode = nil, rom_format = ROM_FORMAT_STR, **kwargs)
      lcode ||= kwargs[:lcode]
      s = self.class.decode_unicode_escapes(s) if kwargs[:decode_unicode]
      return romanize_string_core(s, lcode, rom_format, 0, **kwargs) unless @cache_p

      rest = s
      offset = 0
      result = rom_format == ROM_FORMAT_STR ? "" : []

      while rest =~ /(.*?)([.,; ]*[ 。་][.,; ]*)(.*)$/
        pre, delimiter, rest = $1, $2, $3
        result += romanize_string_core(pre, lcode, rom_format, offset, **kwargs)
        offset += pre.length
        result += romanize_string_core(delimiter, lcode, rom_format, offset, **kwargs)
        offset += delimiter.length
      end
      result += romanize_string_core(rest, lcode, rom_format, offset, **kwargs)
      result
    end

    private

    def contains_surrogate_chars?(str)
      str.each_codepoint.any? { |cp| cp >= 0xD800 && cp <= 0xDFFF }
    end
  end
end
