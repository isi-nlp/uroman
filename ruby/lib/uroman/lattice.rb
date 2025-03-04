# frozen_string_literal: true

require 'unicode/categories'

require_relative 'edge'
require_relative 'num_edge'
require_relative 'util'

module Uroman
  # Lattice for a specific romanization instance. Has edges.
  class Lattice
    attr_reader :s,
                :lcode,
                :lattice,
                :max_vertex,
                :data,
                :props,
                :simple_top_rom_cache,
                :contains_script

    def initialize(s, data, lcode = nil)
      @s = s
      @lcode = lcode
      @lattice = Hash.new { |h, k| h[k] = Set.new }
      @max_vertex = s.length
      @data = data
      @props = {}
      @simple_top_rom_cache = {}
      @contains_script = Hash.new(false)
      check_for_scripts
    end

    def check_for_scripts
      @s.each_char do |c|
        script_name = data.chr_script_name(c)
        @contains_script[script_name] = true
        if /[\u2800-\u28FF]/.match?(@s)
          @contains_script['Braille'] = true
        end
      end
    end

    def add_edge(edge)
      @lattice[[edge.start, edge.finish]] << edge
      @lattice[[edge.start, 'right']] << edge.finish
      @lattice[[edge.finish, 'left']] << edge.start
    end

    def to_s
      edges = []
      (0...@max_vertex).each do |start|
        @lattice[[start, 'right']].each do |finish|
          @lattice[[start, finish]].each do |edge|
            edges << "[#{start}-#{finish}] #{edge.txt} (#{edge.type})"
          end
        end
      end
      edges.join(' ')
    end

    def self.char_is_nonspacing_mark?(s)
      s.length == 1 && Unicode::Categories.of(s).include?('Mn')
    end

    def self.char_is_format_char?(s)
      s.length == 1 && Unicode::Categories.of(s).include?('Cf')
    end

    def self.char_is_space_separator?(s)
      s.length == 1 && Unicode::Categories.of(s).include?('Zs')
    end

    def self.char_is_braille?(c)
      (0x2800..0x28FF).cover?(c.ord)
    end

    def char_is_subjoined_letter?(c)
      data.chr_name(c).include?('SUBJOINED LETTER')
    end

    def char_is_regular_letter?(c)
      char_name = data.chr_name(c)
      char_name.include?('LETTER') && !char_name.include?('SUBJOINED')
    end

    def char_is_letter?(c)
      data.chr_name(c).include?('LETTER')
    end

    def char_is_vowel_sign?(c)
      data.dict_bool[['is-vowel-sign', c]] || false
    end

    def char_is_letter_or_vowel_sign?(c)
      char_is_letter?(c) || char_is_vowel_sign?(c)
    end

    def is_at_start_of_word?(position)
      first_char = @s[position]
      first_char_is_braille = self.class.char_is_braille?(first_char)
      finish = position

      return !@props[['preceded_by_alpha', finish]] if @props.key?(['preceded_by_alpha', finish])

      if finish > 0 && @s[finish - 1].match?(/[[:alpha:]]/)
        @props[['preceded_by_alpha', position]] = true
        return false
      end

      @lattice[[finish, 'left']].each do |start|
        @lattice[[start, finish]].each do |edge|
          prev_letter = edge.txt.empty? ? nil : edge.txt[-1]
          if prev_letter&.match?(/[[:alpha:]]/) || (first_char_is_braille && prev_letter == "'")
            @props[['preceded_by_alpha', position]] = true
            return false
          end
        end
      end

      @props[['preceded_by_alpha', position]] = false
      true
    end

    def is_at_end_of_word?(position)
      return !@props[['followed_by_alpha', position]] if @props.key?(['followed_by_alpha', position])

      start = position
      if start < @max_vertex && @s[start].match?(/[[:alpha:]]/)
        @props[['followed_by_alpha', position]] = true
        return false
      end

      while (start + 1 < @max_vertex) && self.class.char_is_nonspacing_mark?(@s[start]) && data.chr_name(@s[start]).include?('NUKTA')
        start += 1
      end

      (start + 1..@max_vertex).each do |finish|
        segment = @s[start...finish]
        break unless data.dict_bool[['s-prefix', segment]]

        data.rom_rules[segment].each do |rom_rule|
          rom = rom_rule['t']
          if !rom_rule['use-only-at-start-of-word'] && rom.match?(/[[:alpha:]]/)
            @props[['followed_by_alpha', position]] = true
            return false
          end
        end
      end

      @props[['followed_by_alpha', position]] = false
      true
    end

    def is_at_end_of_syllable?(position)
      prev_char = position >= 2 ? @s[position - 2] : nil
      next_char = position < @max_vertex ? @s[position] : nil

      if data.dict_str[['tone-mark', next_char]]
        adj_position = position + 1
        next_char = adj_position < @max_vertex ? @s[adj_position] : nil
      else
        adj_position = position
      end

      next_char2 = adj_position + 1 < @max_vertex ? @s[adj_position + 1] : nil

      return [false, 'start-of-string'] if prev_char.nil?
      return [false, 'start-of-token'] unless prev_char.match?(/\p{L}|\p{M}$/)

      if data.dict_str[['syllable-info', prev_char]] == 'written-pre-consonant-spoken-post-consonant'
        return [false, 'pre-post-vowel-on-left']
      end

      if data.dict_str[['syllable-info', next_char]] == 'written-pre-consonant-spoken-post-consonant'
        return [true, 'pre-post-vowel-on-right']
      end

      return [true, 'end-of-string'] if adj_position >= @max_vertex
      return [true, 'end-of-token'] unless next_char.match?(/\p{L}|\p{M}/)

      if position > 0
        left_edge = best_left_neighbor_edge(position - 1)
        return [false, 'consonant-to-the-left'] if left_edge && left_edge.txt.match?(/[bcdfghjklmnpqrstvxz]$/)
      end

      next_char_rom = Util.first_non_nil(
        simple_top_romanization_candidate_for_span(adj_position, adj_position + 2, simple_search: true),
        simple_top_romanization_candidate_for_span(adj_position, adj_position + 1, simple_search: true),
        '?'
      )

      return [true, "not-followed-by-vowel #{next_char_rom}"] unless next_char_rom.downcase.match?(/[aeiou]/)

      if next_char == "\u0E2D" && !next_char2.nil?
        next_char2_rom = Util.first_non_nil(
          simple_top_romanization_candidate_for_span(adj_position + 1, adj_position + 2, simple_search: true),
          '?'
        )
        return [true, 'o-ang-followed-by-vowel'] if next_char2_rom.downcase.match?(/[aeiou]/)
      end

      [false, 'not-at-syllable-end-by-default']
    end

    def romanization_by_first_rule(s)
      data.rom_rules[s]&.dig(0, 't')
    end

    # This method contains a number of special romanization heuristics that typically modify
    # an existing or preliminary edge based on context.
    def expand_rom_with_special_chars(rom, start, finish, **args)
      orig_start = start
      annot = nil
      return [rom, start, finish, nil] if rom.empty?

      prev_char = start >= 1 ? @s[start - 1] : ''
      first_char = @s[start]
      last_char = @s[finish - 1]
      next_char = finish < @s.length ? @s[finish] : ''

      # \u2820 is the Braille character indicating that the next letter is upper case
      if prev_char == "\u2820" && rom.match?(/[a-z]/)
        return [rom[0].upcase + rom[1..], start - 1, finish, 'rom exp']
      end

      # Normalize multi-upper case THessalonike -> Thessalonike, but don't change THESSALONIKE
      if start + 1 == finish && rom == rom.upcase && next_char.match?(/[a-z]/)
        ablation = args.fetch(:ablation, '')
        rom = rom.capitalize unless ablation.include?('nocap')
      end

      # Japanese small tsu (and Gurmukhi addak) used as consonant doubler:
      if prev_char && "っッ\u0A71".include?(prev_char) &&
        data.chr_script_name(prev_char) == data.chr_script_name(prev_char) &&
        (m_double_consonant = rom.match(/(ch|[bcdfghjklmnpqrstwz])/))
        rom = if 'っッ'.include?(prev_char) # for Japanese, per Hepburn, use 'tch'
                m_double_consonant[1].gsub('ch', 't') + rom
              else
                m_double_consonant[1].gsub('ch', 'c') + rom
              end
        start -= 1
        first_char = @s[start]
        prev_char = start >= 1 ? @s[start - 1] : ''
      end

      # Thai
      if data.chr_script_name(first_char) == 'Thai'
        if start + 1 == finish && rom.match?(/[bcdfghjklmnpqrstvwxyz]+$/)
          if data.dict_str[['syllable-info', prev_char]] == 'written-pre-consonant-spoken-post-consonant'
            [1].each do |vowel_prefix_len|
              next unless vowel_prefix_len <= start
              [3, 2, 1].each do |vowel_suffix_len|
                next unless finish + vowel_suffix_len <= @s.length
                pattern = "#{@s[start - vowel_prefix_len, vowel_prefix_len]}–#{@s[finish, vowel_suffix_len]}"
                next unless (rule = data.rom_rules[pattern])
                vowel_rom = rule[0]['t']
                return [rom + vowel_rom, start - vowel_prefix_len, finish + vowel_suffix_len, 'rom exp']
              end
            end
          end
        end

        if data.chr_script_name(prev_char) == 'Thai' &&
          data.dict_str[['syllable-info', prev_char]] == 'written-pre-consonant-spoken-post-consonant' &&
          rom.match?(/[bcdfghjklmnpqrstvwxyz]/) &&
          (vowel_rom = romanization_by_first_rule(prev_char))
          return [rom + vowel_rom, start - 1, finish, 'rom exp']
        end

        if first_char == "\u0E2D" && (finish - start == 1)
          prev_script = data.chr_script_name(prev_char)
          next_script = data.chr_script_name(next_char)
          prev_rom = find_rom_edge_path_backwards(0, start, 1, return_str: true)
          next_rom = romanization_by_first_rule(next_char)
          unless (prev_script == 'Thai' && next_script == 'Thai' &&
            prev_rom.match?(/[bcdfghjklmnpqrstvwxz]+$/) &&
            next_rom.match?(/[bcdfghjklmnpqrstvwxz]+$/))
            return ['', start, finish, 'rom del']
          end
        end
      end

      # Coptic: consonant + grace-accent = e + consonant
      if next_char == "\u0300" && data.chr_script_name(last_char) == 'Coptic' &&
        !simple_top_romanization_candidate_for_span(orig_start, finish + 1)
        rom = 'e' + rom
        finish += 1
        annot = 'rom exp'
      end

      # Japanese small y: ki + small ya = kya etc.
      if next_char && 'ゃゅょャュョ'.include?(next_char) &&
        data.chr_script_name(last_char) == data.chr_script_name(next_char) &&
        rom.match?(/([bcdfghjklmnpqrstvwxyz]i$)/) &&
        (y_rom = romanization_by_first_rule(next_char)) &&
        !simple_top_romanization_candidate_for_span(orig_start, finish + 1) &&
        !simple_top_romanization_candidate_for_span(start, finish + 1)
        rom = rom[0..-2] + y_rom
        finish += 1
        annot = 'rom exp'
      end

      # Japanese vowel lengthener (U+30FC)
      last_rom_char = rom[-1]
      if next_char == 'ー' && %w[Hiragana Katakana].include?(data.chr_script_name(last_char)) &&
        'aeiou'.include?(last_rom_char)
        return [rom + last_rom_char, start, finish + 1, 'rom exp']
      end

      # Virama (in Indian languages)
      return [rom, start, finish + 1, 'rom exp'] if data.dict_bool[['is-virama', next_char]]

      rom = rom[1..] if rom.start_with?(' ') && (start == 0 || prev_char == ' ')
      rom = rom[0..-2] if rom.end_with?(' ') && (finish == @s.length + 1 || next_char == ' ')

      [rom, start, finish, annot]
    end

    def prep_braille(**_kwargs)
      return unless @contains_script['Braille']

      dots6 = "\u2820" # Characters in the following word are uppercase
      all_caps = false

      @s.each_char.with_index do |c, i|
        if i >= 1 && @s[i - 1] == dots6 && c == dots6
          all_caps = true
        elsif all_caps
          if c == "\u2800" # Braille space
            all_caps = false
          else
            @props[['is-upper', i]] = true
          end
        end
      end
    end

    def pick_tibetan_vowel_edge(**args)
      return nil unless @contains_script['Tibetan']

      verbose = args.fetch(:verbose, false)
      tibetan_syllable = []
      tibetan_letter_positions = []

      (0...@max_vertex).each do |start|
        c = s[start]
        if data.chr_script_name(c) == 'Tibetan' && char_is_letter_or_vowel_sign?(c)
          tibetan_letter_positions << start
        else
          unless tibetan_letter_positions.empty?
            tibetan_syllable << tibetan_letter_positions
            tibetan_letter_positions = []
          end
        end
      end
      tibetan_syllable << tibetan_letter_positions unless tibetan_letter_positions.empty?

      tibetan_syllable.each do |tibetan_letter_positions|
        vowel_pos = nil
        orig_txt = ''
        roms = []
        subjoined_letter_positions = []
        first_letter_position = tibetan_letter_positions.first

        tibetan_letter_positions.each do |i|
          c = s[i]
          orig_txt += c
          rom = Util.first_non_nil(simple_top_romanization_candidate_for_span(i, i + 1), '?')
          @props[["edge-vowel", i]] = nil

          if char_is_vowel_sign?(c) || (rom && rom.match?(/[aeiou]+$/))
            vowel_pos = i
            @props[["edge-vowel", i]] = true
            @props[["edge-delete", i - 1]] = true if roms == ["'"]
          elsif char_is_subjoined_letter?(c)
            subjoined_letter_positions << i
            if i > first_letter_position
              if c == "\u0FB0"
                vowel_pos = i - 1
                @props[["edge-vowel", i - 1]] = true
              else
                @props[["edge-vowel", i - 1]] = false
              end
            end
            rom = rom.sub(/([bcdfghjklmnpqrstvwxyz].*)a$/, '\1')
          elsif c == "\u0F60"
            @props[["edge-vowel", i]] = false
            if i > first_letter_position
              vowel_pos = i - 1
              @props[["edge-vowel", i - 1]] = true
              @props[["edge-delete", i]] = true if i == tibetan_letter_positions.last
            end
            rom = roms.any? { |r| r.match(/[aeiou]/) } ? "'" : "a'"
          else
            rom = rom.sub(/([bcdfghjklmnpqrstvwxyz].*)a$/, '\1')
          end
          roms << rom
        end

        if vowel_pos
          tibetan_letter_positions.each do |i|
            @props[['edge-vowel', i]] ||= false
          end
        else
          best_cost = Float::INFINITY
          best_vowel_pos = best_pre = best_post = nil
          n_letters = tibetan_letter_positions.length

          tibetan_letter_positions.each do |i|
            rel_pos = i - first_letter_position
            pre = roms[0..rel_pos].join('')
            post = roms[(rel_pos + 1)..].join('')

            cost = if @props[['edge-vowel', i]] == false
                     20
                   elsif n_letters == 1
                     0
                   elsif n_letters == 2
                     i.zero? ? 0 : 0.1
                   else
                     good_suffix = post.match?(/(?:|[bcdfghjklmnpqrstvwxz]|bh|bs|ch|cs|dd|ddh|dh|dz|dzh|gh|gr|gs|kh|khs|kss|n|nn|nt|ms|ng|ngs|ns|ph|rm|sh|ss|th|ts|tsh|tt|tth|zh|zhs)'?$/)
                     good_prefix = pre.match?(/'?(?:.|bd|br|brg|brgy|bs|bsh|bst|bt|bts|by|bz|bzh|ch|db|dby|dk|dm|dp|dpy|dr|gl|gn|gr|gs|gt|gy|gzh|kh|khr|khy|kr|ky|ld|lh|lt|mkh|mny|mth|mtsh|ny|ph|phr|phy|rgy|rk|el|rn|rny|rt|rts|sk|skr|sky|sl|sm|sn|sny|sp|spy|sr|st|th|ts|tsh)$/)
                     subjoined_suffix = tibetan_letter_positions[(rel_pos + 2)..]&.all? { |x| subjoined_letter_positions.include?(x) }

                     if good_suffix && good_prefix
                       pre.length * 0.1
                     elsif good_suffix
                       pre.length
                     elsif subjoined_suffix && good_prefix
                       pre.length * 0.3
                     elsif subjoined_suffix
                       pre.length * 0.5
                     else
                       Float::INFINITY
                     end
                   end

            if cost < best_cost
              best_cost, best_vowel_pos, best_pre, best_post = cost, i, pre, post
            end
          end

          if best_vowel_pos
            tibetan_letter_positions.each do |i|
              @props[["edge-vowel", i]] ||= (i == best_vowel_pos)
            end
          end

          if verbose
            best_cost = best_cost.is_a?(Integer) ? best_cost : best_cost.round(2)
            STDERR.puts "Tib. best cost: \"#{best_pre}a#{best_post}\"  o:#{orig_txt}  c:#{best_cost} p:#{best_vowel_pos} #{tibetan_letter_positions}"
          end
        end
      end
    end

    # Adds an abugida vowel (e.g. "a") where needed. Important for many languages in South Asia.
    def add_default_abugida_vowel(rom, start, finish, annotation: '')
      first_s_char = s[start]
      last_s_char = s[finish - 1]
      script_name = data.chr_script_name(first_s_char)
      script = data.scripts[script_name.downcase]

      return rom unless (abugida_default_vowels = script['abugida-default-vowels'])

      key = [script, rom]
      if data.abugida_cache.key?(key)
        base_rom, base_rom_plus_vowel, mod_rom = data.abugida_cache[key]
        rom = mod_rom
      else
        vowels_regex1 = abugida_default_vowels.join('|')
        vowels_regex2 = abugida_default_vowels.map { |v| "#{v}+" }.join('|')

        if (m = rom.match(/([cfghkmnqrstxy]?y)(#{vowels_regex2})-?$/))
          base_rom, base_rom_plus_vowel = m[1], m[1] + m[2]
        elsif (m = rom.match(/([bcdfghjklmnpqrstvwxyz]+)(#{vowels_regex1})-?$/))
          base_rom, base_rom_plus_vowel = m[1], m[1] + m[2]
          rom = rom[0..-2] if rom.end_with?('-') && (start + 1 == finish) && rom[0].match?(/[A-Za-z]/)
        else
          base_rom = rom
          base_rom_plus_vowel = base_rom + abugida_default_vowels[0]
        end

        unless base_rom.match?(/[bcdfghjklmnpqrstvwxyz]+$/) || (script_name == 'Tibetan' && base_rom == "'")
          base_rom, base_rom_plus_vowel = nil, nil
        end

        data.abugida_cache[key] = [base_rom, base_rom_plus_vowel, rom]
      end

      return rom if base_rom.nil? || annotation.include?('tail')

      prev_s_char = start >= 1 ? s[start - 1] : ''
      next_s_char = finish < s.length ? s[finish] : ''
      next2_s_char = finish + 1 < s.length ? s[finish + 1] : ''

      case script_name
      when 'Tibetan'
        return '' if self.props[[:'edge-delete', start]]
        return base_rom_plus_vowel if self.props[[:'edge-vowel', start]]
        return base_rom
      end

      return base_rom if next_s_char.match?(/[យ]/) && ("bcdfghklmnpqrstvwz".include?(base_rom) || base_rom == 'ng')
      return base_rom if data.dict_bool[['is-vowel-sign', next_s_char]]
      return base_rom if data.dict_bool[['is-medial-consonant-sign', next_s_char]]
      return base_rom if char_is_subjoined_letter?(next_s_char)
      return base_rom if self.class.char_is_nonspacing_mark?(next_s_char) && data.dict_bool[['is-vowel-sign', next2_s_char]]
      return base_rom if data.dict_bool[['is-virama', next_s_char]]
      return base_rom if self.class.char_is_nonspacing_mark?(next_s_char) && data.dict_bool[['is-virama', next2_s_char]]
      return base_rom_plus_vowel if data.dict_bool[['is-virama', prev_s_char]]
      return base_rom_plus_vowel if is_at_start_of_word?(start) && !rom.match?(/r[aeiou]/)

      if is_at_end_of_word?(finish)
        return rom if script_name == 'Devanagari' && self.lcode != 'san'
        return rom if %w[asm ben guj kas pan].include?(self.lcode)
        return base_rom_plus_vowel
      end

      return base_rom_plus_vowel if data.chr_script_name(prev_s_char) != script_name
      return base_rom if data.chr_name(last_s_char).include?('VOCALIC')
      return base_rom_plus_vowel if data.chr_script_name(next_s_char) == script_name
      rom
    rescue StandardError
      rom
    end

    def cand_is_valid(rom_rule, start, finish, rom)
      return false if rom.nil?
      return false if rom_rule['dont-use-at-start-of-word'] && is_at_start_of_word?(start)
      return false if rom_rule['use-only-at-start-of-word'] && !is_at_start_of_word?(start)
      return false if rom_rule['dont-use-at-end-of-word'] && is_at_end_of_word?(finish)
      return false if rom_rule['use-only-at-end-of-word'] && !is_at_end_of_word?(finish)
      return false if rom_rule['use-only-for-whole-word'] &&
        !(is_at_start_of_word?(start) && is_at_end_of_word?(finish))
      return false if rom_rule['lcodes']&.any? && !rom_rule['lcodes'].include?(lcode)

      true
    end

    def simple_sorted_romanization_candidates_for_span(start, finish)
      substring = s[start...finish]
      return [] unless data.dict_bool[['s-prefix', substring]]

      rom_rule_candidates = []
      data.rom_rules[substring].each do |rom_rule|
        rom = rom_rule['t']
        if cand_is_valid(rom_rule, start, finish, rom)
          rom_rule_candidates << [(rom_rule['n-restr'] || 0), rom]
        end
      end

      rom_rule_candidates.sort_by! { |x| -x[0] }
      rom_rule_candidates.map(&:last)
    end

    def simple_top_romanization_candidate_for_span(start, finish, simple_search = false)
      return nil if start.negative? || finish > max_vertex

      span_range = [start, finish]
      return simple_top_rom_cache[span_range] if simple_top_rom_cache.key?(span_range)

      best_cand = nil
      best_n_restr = nil
      best_rom_rule = nil

      data.rom_rules[s[start...finish]].each do |rom_rule|
        if cand_is_valid(rom_rule, start, finish, rom_rule['t'])
          n_restr = rom_rule['n-restr'] || 0
          if best_n_restr.nil? || n_restr > best_n_restr
            best_cand = rom_rule['t']
            best_n_restr = n_restr
            best_rom_rule = rom_rule
          end
        end
      end

      return best_cand if simple_search

      if best_rom_rule && (t_at_end_of_syllable = best_rom_rule['t-at-end-of-syllable'])
        end_of_syllable, _rationale = is_at_end_of_syllable?(finish)
        best_cand = t_at_end_of_syllable if end_of_syllable
      end

      simple_top_rom_cache[span_range] = best_cand
      best_cand
    end

    def decomp_rom(char_position)
      char = @s[char_position]
      rom = nil
      if (ud_decomp_s = char.unicode_normalize(:nfd))
        format_comps = []
        other_comps = []
        decomp_s = ''

        ud_decomp_s.split.each do |ud_decomp_elem|
          if ud_decomp_elem.start_with?('<')
            format_comps << ud_decomp_elem
          else
            begin
              norm_char = ud_decomp_elem.to_i(16).chr(Encoding::UTF_8)
              decomp_s += norm_char
            rescue ArgumentError
              other_comps << ud_decomp_elem
            end
          end
        end

        if format_comps.any? && !%w[<super> <sub> <noBreak> <compat>].include?(format_comps.first) &&
          other_comps.empty? && !decomp_s.empty?
          rom = data.romanize_string(decomp_s, @lcode)
        end

        if rom && Util.ud_numeric(char)
          rom.gsub!('⁄', '/')
          rom = " #{rom}" if char_position >= 1 && Util.ud_numeric(@s[char_position - 1])
          rom += ' ' if char_position + 1 < @s.length && Util.ud_numeric(@s[char_position + 1])
        end
      end
      rom
    end

    # Adds a romanization edge to the romanization lattice.
    def add_romanization(**args)
      (0...@max_vertex).each do |start|
        ((start + 1)..@max_vertex).each do |finish|
          break unless data.dict_bool[['s-prefix', @s[start...finish]]]

          if (rom = simple_top_romanization_candidate_for_span(start, finish))
            if @contains_script['Braille'] && start + 1 == finish
              rom.upcase! if @props[['is-upper', start]]
            end

            edge_annotation = 'rom'
            if rom.match(/^\+(m|ng|n|h|r)/)
              rom = rom[1..]
              edge_annotation = 'rom tail'
            end

            new_rom = add_default_abugida_vowel(rom, start, finish, annotation: edge_annotation)
            if new_rom.start_with?(rom)
              suffix = new_rom[rom.length..]
              edge_annotation += " c:#{rom} s:#{suffix}" if suffix&.match?(/[aeiou]+$/)
            end

            rom, start2, finish2, exp_edge_annotation = expand_rom_with_special_chars(rom, start, finish, annotation: edge_annotation, recursive: args[:recursive], **args)
            edge_annotation = exp_edge_annotation || edge_annotation
            add_edge(Edge.new(start2, finish2, rom, edge_annotation))
          end
        end

        next unless start < @s.length

        char = @s[start]
        cp = char.ord

        if (0xAC00..0xD7A3).cover?(cp)
          if (rom = data.unicode_hangul_romanization(char))
            add_edge(Edge.new(start, start + 1, rom, 'rom'))
          end
        end

        if (rom_decomp = decomp_rom(start))
          add_edge(Edge.new(start, start + 1, rom_decomp, 'rom decomp'))
        end
      end
    end

    def self.update_edge_list(edges, new_edge, old_edges)
      new_edge_not_yet_added = true
      result = []

      edges.each do |edge|
        if old_edges.include?(edge)
          edge.active = false
          if new_edge_not_yet_added
            result << new_edge
            new_edge_not_yet_added = false
          end
        else
          result << edge
        end
      end

      result << new_edge if new_edge_not_yet_added
      result
    end

    def self.edge_is_digit?(edge)
      edge.is_a?(NumEdge) && edge.value.is_a?(Integer) && edge.type == 'digit' && (0..9).cover?(edge.value) && (edge.finish - edge.start == 1)
    end

    def self.is_gap_null_edge(edge)
      edge.is_a?(NumEdge) && ['零', '〇'].include?(edge.orig_txt)
    end

    def self.braille_digit(char)
      position = "\u281A\u2801\u2803\u2809\u2819\u2811\u280B\u281B\u2813\u280A".index(char)
      position ? position.to_s : nil
    end

    def add_braille_number(start, finish, txt, **_kwargs)
      new_edge = NumEdge.new(start, finish, txt, data)
      new_edge.type = 'number'
      add_edge(new_edge)
    end

    def add_braille_numbers(**_kwargs)
      if @contains_script['Braille']
        s = @s
        num_s, start = '', nil
        s.each_char.with_index do |char, i|
          if char == "\u283C" # number mark
            start = i if start.nil?
          elsif start && (digit_s = braille_digit(char))
            num_s += digit_s
          elsif start && char == "\u2832" # period
            num_s += '.'
          elsif start && char == "\u2802" # comma
            num_s += ','
          elsif start.is_a?(Integer) && !num_s.empty?
            add_braille_number(start, i, num_s)
            num_s, start = '', nil
          end
        end
        add_braille_number(start, s.length, num_s) if start && !num_s.empty?
      end
    end

    # Adds a numerical romanization edge to the romanization lattice, currently just for digits.
    def add_numbers(data, verbose: false, **_kwargs)
      s = @s
      num_edges = []

      # Iterate through each character in the string to find numerical properties
      s.each_char.with_index do |char, start|
        if data.num_props[char]
          new_edge = NumEdge.new(start, start + 1, char, data)
          num_edges << new_edge
          puts "NumEdge #{new_edge}" if verbose
          add_edge(new_edge)
        end
      end

      # D1 sequence of digits 1234
      num_edges.each do |edge|
        next unless self.class.edge_is_digit?(edge) && edge.active

        n_decimal_points = 0
        n_decimals = nil
        new_value_s = edge.value.to_s
        sub_edges = [edge]
        prev_edge = edge

        # Process consecutive digit edges
        loop do
          right_edge = best_right_neighbor_edge(prev_edge.finish)

          if self.class.edge_is_digit?(right_edge)
            sub_edges << right_edge
            new_value_s += right_edge.value.to_s
            n_decimals += 1 if n_decimals
            prev_edge = right_edge
          elsif prev_edge.finish < s.length && s[prev_edge.finish] == '.' && n_decimal_points.zero?
            right_edge2 = best_right_neighbor_edge(prev_edge.finish + 1)

            if right_edge2 && self.class.edge_is_digit?(right_edge2)
              right_edge ||= Edge.new(prev_edge.finish, prev_edge.finish + 1, s[prev_edge.finish], 'decimal period')
              add_edge(right_edge)
              sub_edges.concat([right_edge, right_edge2])
              new_value_s += ".#{right_edge2.value}"
              n_decimal_points += 1
              n_decimals = 1
              prev_edge = right_edge2
            else
              break
            end
          else
            break
          end
        end

        # If a sequence of digits is found, create a new edge
        if sub_edges.length >= 2
          new_value = new_value_s.include?('.') ? new_value_s.to_f : new_value_s.to_i
          new_edge = NumEdge.new(sub_edges.first.start, sub_edges.last.finish, new_value.to_s, data, active: true)
          new_edge.update(value: new_value, value_s: new_value_s, n_decimals: n_decimals, num_base: 1, e_type: 'D1', script: sub_edges.last.script)
          add_edge(new_edge)
          num_edges = update_edge_list(num_edges, new_edge, sub_edges)
          puts "#{new_edge.type} #{new_edge}" if verbose
        end
      end

      # G1: Combine single digits into numerical values (e.g., 2 * 100 = 200)
      num_edges.each do |edge|
        next unless edge.is_a?(NumEdge) && edge.active && edge.num_base == 1 && edge.value.is_a?(Integer) && edge.value >= 1

        right_edge = best_right_neighbor_edge(edge.finish, skip_num_edge: false)

        if right_edge.is_a?(NumEdge) && right_edge.active && right_edge.value.is_a?(Integer) && right_edge.num_base > 1 && !right_edge.is_large_power
          new_value = edge.value * right_edge.value
          new_edge = NumEdge.new(edge.start, right_edge.finish, new_value.to_s, data, active: true)
          new_edge.update(value: new_value, num_base: right_edge.num_base, e_type: 'G1', orig_txt: edge.orig_txt + right_edge.orig_txt, script: right_edge.script)
          add_edge(new_edge)
          num_edges = update_edge_list(num_edges, new_edge, [edge, right_edge])
          puts "#{new_edge.type} #{new_edge}" if verbose
        end
      end

      # G2: Combine numerical groups (e.g., 200 + 30 + 4 = 234)
      num_edges.each do |edge|
        next unless edge.is_a?(NumEdge) && edge.active && edge.value.is_a?(Integer) && !edge.is_large_power

        sub_edges = [edge]
        prev_edge = edge
        prev_non_edge = edge

        # Combine consecutive number groups
        loop do
          right_edge = best_right_neighbor_edge(prev_edge.finish, skip_num_edge: false)
          break unless right_edge.is_a?(NumEdge) && right_edge.active && right_edge.value.is_a?(Integer) && !right_edge.is_large_power

          if is_gap_null_edge(prev_non_edge) || (prev_non_edge.num_base > right_edge.value && prev_non_edge.num_base > right_edge.num_base)
            sub_edges << right_edge
            prev_edge = right_edge
            prev_non_edge = right_edge unless is_gap_null_edge(right_edge)
          else
            break
          end
        end

        # Create a new edge for the combined number group
        if sub_edges.length >= 2
          new_value = sub_edges.sum(&:value)
          new_edge = NumEdge.new(sub_edges.first.start, sub_edges.last.finish, new_value.to_s, data, active: true)
          new_edge.update(value: new_value, num_base: sub_edges.last.num_base, e_type: 'G2', orig_txt: sub_edges.map(&:orig_txt).join, script: sub_edges.last.script)
          add_edge(new_edge)
          num_edges = update_edge_list(num_edges, new_edge, sub_edges)
          new_edge.type = 'G2'
          puts "#{new_edge.type} #{new_edge}" if verbose
        end
      end

      # G3: Multiply G2 blocks with large powers (e.g., 234 * 1000 = 234000)
      num_edges.each do |edge|
        next unless edge.is_a?(NumEdge) && edge.active && !edge.is_large_power

        right_edge = best_right_neighbor_edge(edge.finish, skip_num_edge: false)

        if right_edge.is_a?(NumEdge) && right_edge.active && right_edge.value.is_a?(Integer) && right_edge.num_base > 1
          new_value = (edge.value * right_edge.value).round(5)
          new_value = new_value.to_i if new_value.to_i == new_value

          new_edge = NumEdge.new(edge.start, right_edge.finish, new_value.to_s, data, active: true)
          new_edge.update(value: new_value, num_base: right_edge.num_base, e_type: 'G3', orig_txt: edge.orig_txt + right_edge.orig_txt, script: right_edge.script)
          add_edge(new_edge)
          num_edges = update_edge_list(num_edges, new_edge, [edge, right_edge])
          puts "#{new_edge.type} #{new_edge}" if verbose
        end
      end
    end

    # For characters in the original string not covered by romanizations and numbers,
    # add a fallback edge based on type, romanization of single char, or original char.
    def add_rom_fall_back_singles(**_kwargs)
      (0...@max_vertex).each do |start|
        finish = start + 1
        orig_char = @s[start]
        unless @lattice[[start, finish]]
          rom, edge_annotation = orig_char, 'orig'
          if self.class.char_is_nonspacing_mark?(rom)
            rom, edge_annotation = '', 'Mn'
          elsif self.class.char_is_format_char?(rom) # e.g. zero-width non-joiner, zero-width joiner
            rom, edge_annotation = '', 'Cf'
          elsif Unicode::Category.of(orig_char) == 'Co'
            rom, edge_annotation = '', 'Co'
          elsif rom == ' '
            edge_annotation = 'orig'
          elsif (rom2 = simple_top_romanization_candidate_for_span(start, finish))
            rom = rom2
            rom = rom[1..] if rom.match?(/^\+(m|ng|n|h|r)/)
            edge_annotation = 'rom single'
          end
          add_edge(Edge.new(start, finish, rom, edge_annotation))
        end
      end
    end

    def self.add_new_edge(old_edges, start, finish, new_rom, new_type, position, old_edge_dict)
      key = [start, finish, new_rom]
      unless old_edge_dict[key]
        new_edge = Edge.new(start, finish, new_rom, new_type)
        if position.nil?
          old_edges << new_edge
        else
          old_edges.insert(position + 1, new_edge)
        end
        old_edge_dict[key] = new_edge
      end
    end

    def add_alternatives(old_edges)
      old_edge_dict = {}
      old_edges.each { |old_edge| old_edge_dict[[old_edge.start, old_edge.finish, old_edge.txt]] = old_edge }

      old_edges.each_with_index do |old_edge, position|
        next if old_edge.type.start_with?('rom-alt')

        start, finish = old_edge.start, old_edge.finish
        orig_s = @s[start...finish]
        old_rom = old_edge.txt

        if (m = old_edge.type.match(/\bc:([a-z]+)\s+s:([a-z]+)\b/))
          old_rom_core, old_rom_suffix = m.captures
        else
          old_rom_core, old_rom_suffix = nil, nil
        end

        data.rom_rules[orig_s].each do |rom_rule|
          rom_t = rom_rule['t']
          next unless cand_is_valid(rom_rule, start, finish, rom_t)

          rom_alts = rom_rule['t-alts']
          rom_end_of_syllable = rom_rule['t-at-end-of-syllable']

          if (rom_t == old_rom || rom_t == old_rom_core) && rom_alts
            rom_alts.each do |rom_alt|
              rom_alt += old_rom_suffix if old_rom_suffix && rom_t == old_rom_core
              self.class.add_new_edge(old_edges, start, finish, rom_alt, 'rom-alt', position, old_edge_dict)
            end
          end

          if rom_t == old_rom && rom_end_of_syllable
            self.class.add_new_edge(old_edges, start, finish, rom_t, 'rom-alt2', position, old_edge_dict)
          end

          if rom_end_of_syllable == old_rom
            self.class.add_new_edge(old_edges, start, finish, rom_t, 'rom-alt3', position, old_edge_dict)
          end
        end
      end
    end

    def all_edges(start, finish)
      result = []
      (start...finish).each do |start2|
        @lattice[[start2, 'right']].sort.reverse_each do |finish2|
          if finish2 <= finish
            result.concat(@lattice[[start2, finish2]])
          else
            break
          end
        end
      end
      result
    end

    def best_edge_in_span(start, finish, skip_num_edge: false)
      edges = @lattice[[start, finish]]
      decomp_edge = nil
      other_edge = nil
      rom_edge = nil

      edges.each do |edge|
        if edge.is_a?(NumEdge)
          return edge if edge.active && !skip_num_edge
        end

        if edge.type.start_with?('rom decomp')
          decomp_edge ||= edge # plan C
        elsif edge.type.match?(/(?:rom|num)/)
          rom_edge ||= edge # plan B
        else
          other_edge ||= edge # plan D
        end
      end
      rom_edge || decomp_edge || other_edge
    end

    def best_right_neighbor_edge(start, skip_num_edge: false)
      @lattice[[start, 'right']].sort.reverse_each do |finish|
        if (best_edge = best_edge_in_span(start, finish, skip_num_edge: skip_num_edge))
          return best_edge
        end
      end
      nil
    end

    def best_left_neighbor_edge(finish, skip_num_edge: false)
      @lattice[[finish, 'left']].sort.each do |start|
        if (best_edge = best_edge_in_span(start, finish, skip_num_edge: skip_num_edge))
          return best_edge
        end
      end
      nil
    end

    # Finds the best romanization edge path through the romanization lattice,
    # including non-romanized pieces such as ASCII and non-ASCII punctuation.
    def best_rom_edge_path(start, finish, skip_num_edge: false)
      result = []
      start2 = start

      while start2 < finish
        if (best_edge = best_right_neighbor_edge(start2, skip_num_edge: skip_num_edge))
          result << best_edge
          start2 = best_edge.finish
        else
          start2 += 1 # should not happen
        end
      end
      result
    end

    # Finds a partial best path on the left from a start position to provide left contexts for
    # romanization rules. Can return a string or a list of edges. Is typically used for a short context,
    # as specified by min_char.
    def find_rom_edge_path_backwards(start, finish, min_char = nil, return_str: false, skip_num_edge: false)
      result_edges = []
      rom = ''
      finish2 = finish

      while start < finish2
        old_finish2 = finish2
        if (new_edge = best_left_neighbor_edge(finish2, skip_num_edge: skip_num_edge))
          result_edges.unshift(new_edge)
          rom = new_edge.txt + rom
          finish2 = new_edge.start
        end

        break if min_char && rom.length >= min_char

        finish2 -= 1 if old_finish2 >= finish2
      end

      return_str ? rom : result_edges
    end

    def self.edge_path_to_surf(edges)
      edges.map(&:txt).join
    end
  end
end
