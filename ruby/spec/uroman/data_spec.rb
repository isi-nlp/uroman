# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe Uroman::Data do
  let(:data) { Uroman::Data.new }

  describe '#romanize_string' do
    it 'romanizes strings from different scripts' do
      examples = [
        ['Νεπάλ', 'Nepal'],
        ['नेपाल', 'nepaal'],
        ['نیپال', 'nypal'],
        ['三万一', '31000'],
        ['三万一千', '30001']
      ]

      examples.each do |input, expected_output|
        expect(data.romanize_string(input)).to eq(expected_output)
      end
    end

    it 'uses language code when provided' do
      input = 'Игорь'
      # These tests verify that the output changes with different language codes
      ru_romanized = data.romanize_string(input, lcode: 'rus')
      uk_romanized = data.romanize_string(input, lcode: 'ukr')
      default_romanized = data.romanize_string(input)

      expect(ru_romanized).to eq('Igor')
      expect(uk_romanized).to eq('Ihor')
      expect(default_romanized).to eq('Igor')
      expect(ru_romanized).not_to eq(uk_romanized)
    end

    it 'handles Thai script correctly' do
      thai_text = 'สวัสดี'
      expect(data.romanize_string(thai_text)).to eq('sawasdee')
    end

    it 'romanizes Arabic text' do
      arabic_text = 'ألاسكا'
      expect(data.romanize_string(arabic_text)).not_to be_empty
      expect(data.romanize_string(arabic_text)).to eq('alaska')
    end

    it 'romanizes Persian text with language code' do
      persian_text = 'ایران'
      expect(data.romanize_string(persian_text, lcode: 'fas')).to eq('iran')
    end

    it 'romanizes Japanese text' do
      japanese_text = 'ちょっとまってください'
      expect(data.romanize_string(japanese_text)).to eq('chottomattekudasai')
    end

    it 'romanizes Korean text' do
      korean_text = '서울'
      expect(data.romanize_string(korean_text)).to eq('seoul')
    end

    it 'romanizes Greek text with language code' do
      greek_text = 'Μπανγκαλόρ'
      expect(data.romanize_string(greek_text, lcode: 'ell')).to eq('Bangalore')
    end

    it 'romanizes Ukrainian text with language code' do
      ukrainian_text = 'Зеленський'
      expect(data.romanize_string(ukrainian_text, lcode: 'ukr')).to eq('Zelensky')
    end

    it 'romanizes Hindi text with language code' do
      hindi_text = 'यह एक अच्छा अनुवाद है.'
      expect(data.romanize_string(hindi_text, lcode: 'hin')).to eq('yah ek acchaa anuvaad hai.')
    end

    it 'romanizes Malayalam text with language code' do
      malayalam_text = 'കേരളം'
      expect(data.romanize_string(malayalam_text, lcode: 'mal')).to include('keeralam')
    end

    it 'handles Unicode escape notation when enabled' do
      input = '\\u03C0\\u03B9' # πι in Unicode escape notation
      expect(data.romanize_string(input, decode_unicode: true)).to eq('pi')
    end
  end

  describe 'different output formats' do
    let(:persian_text) { 'ایران' }

    it 'returns a string for format: str' do
      result = data.romanize_string(persian_text, lcode: 'fas', rom_format: Uroman::Data::ROM_FORMAT_STR)
      expect(result).to be_a(String)
      expect(result).to eq('iran')
    end

    it 'returns an array of edges for format: edges' do
      result = data.romanize_string(persian_text, lcode: 'fas', rom_format: Uroman::Data::ROM_FORMAT_EDGES)
      expect(result).to be_an(Array)
      expect(result.all? { |edge| edge.is_a?(Uroman::Edge) }).to be true
      expect(result.map(&:txt).join).to eq('iran')
    end

    it 'returns edges with alternatives for format: alts' do
      result = data.romanize_string(persian_text, lcode: 'fas', rom_format: Uroman::Data::ROM_FORMAT_ALTS)
      expect(result).to be_an(Array)
      expect(result.all? { |edge| edge.is_a?(Uroman::Edge) }).to be true
    end

    it 'returns lattice with all edges for format: lattice' do
      result = data.romanize_string(persian_text, lcode: 'fas', rom_format: Uroman::Data::ROM_FORMAT_LATTICE)
      expect(result).to be_an(Array)
      expect(result.all? { |edge| edge.is_a?(Uroman::Edge) }).to be true
      # Lattice should have more edges than the basic path
      expect(result.length).to be >= 4 # 4 is the length of "iran"
    end
  end

  describe 'file romanization' do
    it 'romanizes a file' do
      # Create temp files for test
      input_file = Tempfile.new(['input', '.txt'])
      output_file = Tempfile.new(['output', '.txt'])

      begin
        # Write test content to input file
        input_content = "::lcode deu Grüße aus Bordeaux\n"
        input_file.write(input_content)
        input_file.flush

        # Romanize the file
        data.romanize_file(input_filename: input_file.path, output_filename: output_file.path)

        # Read the output
        output_content = File.read(output_file.path).strip
        expect(output_content).to eq("::lcode deu Gruesse aus Bordeaux")
      ensure
        input_file.close
        input_file.unlink
        output_file.close
        output_file.unlink
      end
    end

    it 'handles language code lines in files' do
      # Create temp files for test
      input_file = Tempfile.new(['input', '.txt'])
      output_file = Tempfile.new(['output', '.txt'])

      begin
        # Write test content with multiple language codes
        input_content = <<~TEXT
          ::lcode deu Grüße aus Bordeaux
          ::lcode tur İstanbul, Türkiye'de yer alan şehir ve ülkenin 81 ilinden biri.
        TEXT
        input_file.write(input_content)
        input_file.flush

        # Romanize the file
        data.romanize_file(input_filename: input_file.path, output_filename: output_file.path)

        # Read the output
        output_content = File.read(output_file.path).strip
        expected_output = <<~TEXT.strip
          ::lcode deu Gruesse aus Bordeaux
          ::lcode tur Istanbul, Tuerkiye'de yer alan shehir ve uelkenin 81 ilinden biri.
        TEXT
        expect(output_content).to eq(expected_output)
      ensure
        input_file.close
        input_file.unlink
        output_file.close
        output_file.unlink
      end
    end
  end

  describe 'special cases' do
    it 'handles numeric conversion correctly' do
      # Test Chinese numerals
      expect(data.romanize_string('三万一')).to eq('30001')
      expect(data.romanize_string('三万一千')).to eq('31000')
      expect(data.romanize_string('九')).to eq('9')
      expect(data.romanize_string('零')).to eq('0')
      expect(data.romanize_string('〇')).to eq('0')
    end

    it 'handles fractions correctly' do
      expect(data.romanize_string('¼')).to eq('1/4')
      expect(data.romanize_string('½')).to eq('1/2')
      expect(data.romanize_string('¾')).to eq('3/4')
    end

    it 'handles Braille correctly' do
      # "We hold these truths..." in Braille
      braille_text = '⠠⠺⠑⠀⠓⠕⠇⠙⠀⠘⠮⠀⠞⠗⠥⠹⠎'
      expect(data.romanize_string(braille_text)).to start_with('We hold these truths')
    end

    it 'preserves ASCII text' do
      ascii_text = 'Hello, world!'
      expect(data.romanize_string(ascii_text)).to eq(ascii_text)
    end
  end
end
