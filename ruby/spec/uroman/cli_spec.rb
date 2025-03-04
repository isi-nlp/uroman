# frozen_string_literal: true

require_relative '../spec_helper'
require 'uroman/cli'
require 'stringio'

RSpec.describe Uroman::Cli do
  let(:cli) { Uroman::Cli.new }

  describe '#parse_arguments' do
    it 'parses language code' do
      ARGV.replace(['-l', 'rus'])
      cli = Uroman::Cli.new
      expect(cli.instance_variable_get('@options')[:lcode]).to eq('rus')
    end

    it 'parses input filename' do
      ARGV.replace(['-i', 'input.txt'])
      cli = Uroman::Cli.new
      expect(cli.instance_variable_get('@options')[:input_filename]).to eq('input.txt')
    end

    it 'parses output filename' do
      ARGV.replace(['-o', 'output.txt'])
      cli = Uroman::Cli.new
      expect(cli.instance_variable_get('@options')[:output_filename]).to eq('output.txt')
    end

    it 'parses romanization format' do
      ARGV.replace(['-f', 'edges'])
      cli = Uroman::Cli.new
      expect(cli.instance_variable_get('@options')[:rom_format]).to eq('edges')
    end

    it 'parses verbosity flag' do
      ARGV.replace(['-v'])
      cli = Uroman::Cli.new
      expect(cli.instance_variable_get('@options')[:verbose]).to eq(1)
    end

    it 'parses direct input' do
      ARGV.replace(['Игорь'])
      cli = Uroman::Cli.new
      expect(cli.instance_variable_get('@direct_input')).to eq(['Игорь'])
    end
  end

  describe '#run' do
    before do
      # Redirect stdout for testing
      @original_stdout = $stdout
      $stdout = StringIO.new
    end

    after do
      # Restore stdout
      $stdout = @original_stdout
    end

    it 'processes direct input' do
      ARGV.replace(['Игорь'])
      cli = Uroman::Cli.new
      
      # Mock romanize_string to return a fixed value
      allow_any_instance_of(Uroman::Data).to receive(:romanize_string).and_return('Igor')
      
      # We need to mock JSON.generate to avoid errors in the test
      allow(JSON).to receive(:generate).and_return('"Igor"')
      
      expect { cli.run }.not_to raise_error
      expect($stdout.string).to include('"Igor"')
    end

    it 'runs test_sample_calls for --ignore_args' do
      ARGV.replace(['--ignore_args'])
      cli = Uroman::Cli.new
      
      # Mock test_sample_calls to avoid actual processing
      expect(cli).to receive(:test_sample_calls)
      
      cli.run
    end
  end

  describe '#test_sample_calls' do
    before do
      # Redirect stdout for testing
      @original_stdout = $stdout
      $stdout = StringIO.new
    end

    after do
      # Restore stdout
      $stdout = @original_stdout
    end

    it 'demonstrates romanization of sample strings' do
      # Mock romanize_string to return predictable values
      allow_any_instance_of(Uroman::Data).to receive(:romanize_string).and_return('romanized')
      
      ARGV.replace([])
      cli = Uroman::Cli.new
      cli.test_sample_calls
      
      expect($stdout.string).to include('Игорь => romanized')
      expect($stdout.string).to include('ちょっとまってください => romanized')
    end
  end
end