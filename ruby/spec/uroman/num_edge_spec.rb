# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe Uroman::NumEdge do
  let(:data) { Uroman::Data.new }

  describe '#initialize' do
    it 'creates a basic NumEdge' do
      edge = Uroman::NumEdge.new(0, 1, '5', data)
      expect(edge.start).to eq(0)
      expect(edge.finish).to eq(1)
      expect(edge.txt).to eq('5')
      expect(edge.orig_txt).to eq('5')
    end

    it 'creates a NumEdge with active flag' do
      edge = Uroman::NumEdge.new(0, 1, '5', data, active: true)
      expect(edge.active).to be true
    end

    it 'initializes with default values' do
      edge = Uroman::NumEdge.new(0, 1, '5', data)
      expect(edge.value).to be_nil
      expect(edge.fraction).to be_nil
      expect(edge.num_base).to be_nil
      expect(edge.base_multiplier).to be_nil
      expect(edge.type).to be_nil
      expect(edge.script).to be_nil
      expect(edge.is_large_power).to be false
      expect(edge.n_decimals).to be_nil
      expect(edge.value_s).to be_nil
    end

    it 'gets values from num_props for single characters' do
      # Mock the num_props for a specific digit
      digit_props = {
        'value' => 5,
        'type' => 'digit',
        'base' => 1,
        'mult' => 5,
        'script' => 'Latin'
      }
      allow(data.num_props).to receive(:[]).with('5').and_return(digit_props)

      edge = Uroman::NumEdge.new(0, 1, '5', data)
      expect(edge.value).to eq(5)
      expect(edge.type).to eq('digit')
      expect(edge.num_base).to eq(1)
      expect(edge.base_multiplier).to eq(5)
      expect(edge.script).to eq('Latin')
    end
  end

  describe '#update' do
    let(:edge) { Uroman::NumEdge.new(0, 1, '5', data) }

    it 'updates edge values and returns the text' do
      result = edge.update(value: 5, e_type: 'digit')
      expect(edge.value).to eq(5)
      expect(edge.type).to eq('digit')
      expect(result).to eq('5')
    end

    it 'formats decimal values with n_decimals' do
      result = edge.update(value: 5.75, n_decimals: 2)
      expect(edge.value).to eq(5.75)
      expect(edge.n_decimals).to eq(2)
      expect(result).to eq('5.75')
    end

    it 'combines value and fraction' do
      fraction = Rational(1, 4)
      result = edge.update(value: 3, fraction: fraction)
      expect(edge.value).to eq(3)
      expect(edge.fraction).to eq(fraction)
      expect(result).to eq('3 1/4')
    end

    it 'formats the txt field correctly' do
      edge.update(value: 42, script: 'Latin', e_type: 'number')
      expect(edge.txt).to eq('42')
      expect(edge.type).to eq('number')
      expect(edge.script).to eq('Latin')
    end

    it 'falls back to orig_txt when all fields are empty' do
      edge.orig_txt = 'test'
      edge.update(value: nil)
      expect(edge.txt).to eq('test')
    end
  end

  describe '#to_s' do
    it 'formats a basic numeric edge' do
      edge = Uroman::NumEdge.new(0, 1, '5', data)
      edge.update(value: 5, e_type: 'digit')
      result = edge.to_s
      expect(result).to include('[0-1]')
      expect(result).to include('5')
      expect(result).to include('digit')
    end

    pending 'includes large power marker if applicable' do
      edge = Uroman::NumEdge.new(0, 1, '万', data)
      edge.update(value: 10000, is_large_power: true, e_type: 'base')
      result = edge.to_s
      expect(result).to include('LP')
    end

    it 'shows base multiplier when applicable' do
      edge = Uroman::NumEdge.new(0, 2, '42', data)
      edge.update(value: 42, num_base: 10, base_multiplier: 4.2)
      result = edge.to_s
      expect(result).to include('B:4.2*10')
    end

    it 'shows script when provided' do
      edge = Uroman::NumEdge.new(0, 1, '五', data)
      edge.update(value: 5, script: 'CJK')
      result = edge.to_s
      expect(result).to include('S:CJK')
    end

    pending 'indicates inactive edges' do
      edge = Uroman::NumEdge.new(0, 1, '5', data, active: false)
      result = edge.to_s
      expect(result).to include(' *')
    end
  end
end
