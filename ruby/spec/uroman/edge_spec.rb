# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe Uroman::Edge do
  describe '#initialize' do
    it 'creates a new edge with the given parameters' do
      edge = Uroman::Edge.new(0, 3, 'abc', 'test')
      expect(edge.start).to eq(0)
      expect(edge.finish).to eq(3)
      expect(edge.txt).to eq('abc')
      expect(edge.type).to eq('test')
    end

    it 'creates a new edge with nil annotation when not provided' do
      edge = Uroman::Edge.new(0, 3, 'abc')
      expect(edge.type).to be_nil
    end
  end

  describe '#to_s' do
    it 'returns a string representation of the edge' do
      edge = Uroman::Edge.new(0, 3, 'abc', 'test')
      expect(edge.to_s).to eq('[0-3] abc (test)')
    end
  end

  describe '#to_json' do
    it 'returns a JSON representation of the edge' do
      edge = Uroman::Edge.new(0, 3, 'abc', 'test')
      json = edge.to_json
      expect(json).to include('0')
      expect(json).to include('3')
      expect(json).to include('abc')
      expect(json).to include('test')
    end
  end

  describe '.json_str' do
    it 'returns the input when it is a string' do
      expect(Uroman::Edge.json_str('hello')).to eq('hello')
    end

    it 'returns a JSON string for an array of edges' do
      edge1 = Uroman::Edge.new(0, 2, 'ab', 'test1')
      edge2 = Uroman::Edge.new(2, 4, 'cd', 'test2')
      edges = [edge1, edge2]
      
      json_str = Uroman::Edge.json_str(edges)
      expect(json_str).to be_a(String)
      expect(json_str).to start_with('[')
      expect(json_str).to end_with(']')
      expect(json_str).to include('ab')
      expect(json_str).to include('cd')
    end
  end
end