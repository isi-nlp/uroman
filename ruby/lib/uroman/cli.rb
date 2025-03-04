# frozen_string_literal: true

require 'optparse'
require 'pathname'
require 'json'
require 'pp'

require_relative '../uroman'

module Uroman
  class Cli
    def initialize
      @options = {
        rom_format: 'str',
        load_log: 0,
        test: 0,
        stats: 0,
        cache_size: 10000, # Default cache size
        max_lines: nil,
        verbose: 0,
        rebuild_ud_props: 0,
        rebuild_num_props: 0,
        ablation: '',
        silent: 0,
        decode_unicode: 0
      }
      parse_arguments
    end

    def parse_arguments
      OptionParser.new do |opts|
        opts.banner = "Usage: uroman [options] [direct_input]"

        opts.on('--data_dir DIR', String, 'Uroman resource dir') { |v| @options[:data_dir] = Pathname.new(v) }
        opts.on('-i', '--input_filename FILE', String, 'Input file (default: stdin)') { |v| @options[:input_filename] = v }
        opts.on('-o', '--output_filename FILE', String, 'Output file (default: stdout)') { |v| @options[:output_filename] = v }
        opts.on('-l', '--lcode CODE', String, 'ISO 639-3 language code') { |v| @options[:lcode] = v }
        opts.on('-f', '--rom_format FORMAT', String, 'Output format of romanization') { |v| @options[:rom_format] = v }
        opts.on('--max_lines N', Integer, 'Limit uroman to first n lines') { |v| @options[:max_lines] = v }
        opts.on('--load_log', 'Report load stats') { @options[:load_log] += 1 }
        opts.on('--test', 'Perform/display tests') { @options[:test] += 1 }
        opts.on('-d', '--decode_unicode', 'Decode Unicode escape notation') { @options[:decode_unicode] += 1 }
        opts.on('-v', '--verbose', 'Increase verbosity') { @options[:verbose] += 1 }
        opts.on('--rebuild_ud_props', 'Rebuild UnicodeDataProps files') { @options[:rebuild_ud_props] += 1 }
        opts.on('--rebuild_num_props', 'Rebuild NumProps file') { @options[:rebuild_num_props] += 1 }
        opts.on('-c', '--cache_size N', Integer, 'Cache size for speed') { |v| @options[:cache_size] = v }
        opts.on('--silent', 'Suppress progress output') { @options[:silent] += 1 }
        opts.on('-a', '--ablation STRING', String, 'Development mode options') { |v| @options[:ablation] = v }
        opts.on('--stats', 'Enable statistics mode') { @options[:stats] += 1 }
        # opts.on('--ignore_args', 'For usage illustration only') { @options[:ignore_args] = true }
        opts.on('--version', 'Show version information') do
          puts "uroman #{Uroman::VERSION}   last modified: #{Uroman::LAST_MOD_DATE}"
          exit
        end
      end.parse!

      @direct_input = ARGV
    end

    def run
      if @options[:ignore_args]
        test_sample_calls
      else
        process_inputs
      end
    end

    def test_sample_calls
      uroman = Uroman::Data.new(@options[:data_dir])
      samples = ['Игорь', 'ちょっとまってください', 'ka‍n‍ne', 'महात्मा गांधी']
      samples.each do |s|
        puts "#{s} => #{uroman.romanize_string(s)}"
      end
    end

    def process_inputs
      uroman = Uroman::Data.new(@options[:data_dir], **@options)

      if @direct_input.any?
        @direct_input.each do |s|
          result = uroman.romanize_string(s.strip, lcode: @options[:lcode], **@options)
          puts JSON.generate(result)
        end
      end

      if @options[:input_filename] || @options[:output_filename]
        uroman.romanize_file(@options[:input_filename], @options[:output_filename], lcode: @options[:lcode], **@options)
      end

      if @options[:test]
        uroman.test_output_of_selected_scripts_and_rom_rules
        uroman.test_romanization
      end
    end
  end
end
