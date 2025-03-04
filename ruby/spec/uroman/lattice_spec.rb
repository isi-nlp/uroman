# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe Uroman::Lattice do
  let(:data) { Uroman::Data.new }
  let(:lattice) { Uroman::Lattice.new('test', data) }

  describe '#initialize' do
    it 'initializes with a string and data instance' do
      expect(lattice.s).to eq('test')
      expect(lattice.data).to eq(data)
      expect(lattice.max_vertex).to eq(4)
    end

    it 'initializes with an optional language code' do
      lat_with_lcode = Uroman::Lattice.new('test', data, 'eng')
      expect(lat_with_lcode.lcode).to eq('eng')
    end

    it 'checks for scripts in the input string' do
      # Mock chr_script_name to return a predictable value
      allow(data).to receive(:chr_script_name).and_return('Latin')
      
      lat = Uroman::Lattice.new('test', data)
      expect(lat.contains_script['Latin']).to be true
    end

    it 'detects Braille in the input string' do
      braille_text = '⠠⠺⠑'
      lat = Uroman::Lattice.new(braille_text, data)
      expect(lat.contains_script['Braille']).to be true
    end
  end

  describe '#add_edge' do
    it 'adds an edge to the lattice' do
      edge = Uroman::Edge.new(0, 2, 'te', 'test')
      lattice.add_edge(edge)
      
      expect(lattice.lattice[[0, 2]]).to include(edge)
      expect(lattice.lattice[[0, 'right']]).to include(2)
      expect(lattice.lattice[[2, 'left']]).to include(0)
    end
  end

  describe '#to_s' do
    it 'returns a string representation of the lattice' do
      edge1 = Uroman::Edge.new(0, 2, 'te', 'test1')
      edge2 = Uroman::Edge.new(2, 4, 'st', 'test2')
      lattice.add_edge(edge1)
      lattice.add_edge(edge2)
      
      expect(lattice.to_s).to include('[0-2] te (test1)')
      expect(lattice.to_s).to include('[2-4] st (test2)')
    end
  end

  describe '#is_at_start_of_word?' do
    let(:text_lattice) { Uroman::Lattice.new('ab cd', data) }
    
    it 'returns true for the first character' do
      expect(text_lattice.is_at_start_of_word?(0)).to be true
    end
    
    it 'returns false for a character in the middle of a word' do
      # Add edges to simulate word boundaries
      text_lattice.add_edge(Uroman::Edge.new(0, 2, 'ab', 'word'))
      expect(text_lattice.is_at_start_of_word?(1)).to be false
    end
    
    it 'returns true for a character after a space' do
      expect(text_lattice.is_at_start_of_word?(3)).to be true
    end
  end

  describe '#is_at_end_of_word?' do
    let(:text_lattice) { Uroman::Lattice.new('ab cd', data) }
    
    it 'returns true for the last character in a word' do
      # Add edges to simulate word boundaries
      text_lattice.add_edge(Uroman::Edge.new(0, 2, 'ab', 'word'))
      expect(text_lattice.is_at_end_of_word?(2)).to be true
    end
    
    it 'returns false for a character in the middle of a word' do
      expect(text_lattice.is_at_end_of_word?(1)).to be false
    end
  end

  describe 'edge handling' do
    let(:text) { 'hello' }
    let(:text_lattice) { Uroman::Lattice.new(text, data) }
    
    it 'can find the best edge in a span' do
      edge1 = Uroman::Edge.new(0, 2, 'he', 'rom')
      edge2 = Uroman::Edge.new(0, 2, 'He', 'ROM')
      text_lattice.add_edge(edge1)
      text_lattice.add_edge(edge2)
      
      best_edge = text_lattice.best_edge_in_span(0, 2)
      expect(best_edge).not_to be_nil
      expect(best_edge.txt).to match(/[hH]e/)
    end
    
    it 'can find the best right neighbor edge' do
      edge1 = Uroman::Edge.new(0, 2, 'he', 'rom')
      edge2 = Uroman::Edge.new(2, 4, 'll', 'rom')
      text_lattice.add_edge(edge1)
      text_lattice.add_edge(edge2)
      
      best_edge = text_lattice.best_right_neighbor_edge(0)
      expect(best_edge).to eq(edge1)
      
      best_edge = text_lattice.best_right_neighbor_edge(2)
      expect(best_edge).to eq(edge2)
    end
    
    it 'can find the best left neighbor edge' do
      edge1 = Uroman::Edge.new(0, 2, 'he', 'rom')
      edge2 = Uroman::Edge.new(2, 4, 'll', 'rom')
      text_lattice.add_edge(edge1)
      text_lattice.add_edge(edge2)
      
      best_edge = text_lattice.best_left_neighbor_edge(2)
      expect(best_edge).to eq(edge1)
      
      best_edge = text_lattice.best_left_neighbor_edge(4)
      expect(best_edge).to eq(edge2)
    end
    
    it 'can find the best romanization edge path' do
      edge1 = Uroman::Edge.new(0, 2, 'he', 'rom')
      edge2 = Uroman::Edge.new(2, 4, 'll', 'rom')
      edge3 = Uroman::Edge.new(4, 5, 'o', 'rom')
      text_lattice.add_edge(edge1)
      text_lattice.add_edge(edge2)
      text_lattice.add_edge(edge3)
      
      path = text_lattice.best_rom_edge_path(0, 5)
      expect(path).to eq([edge1, edge2, edge3])
    end
    
    it 'converts edge path to surface form' do
      edge1 = Uroman::Edge.new(0, 2, 'he', 'rom')
      edge2 = Uroman::Edge.new(2, 4, 'll', 'rom')
      edge3 = Uroman::Edge.new(4, 5, 'o', 'rom')
      
      surface = Uroman::Lattice.edge_path_to_surf([edge1, edge2, edge3])
      expect(surface).to eq('hello')
    end
  end
end