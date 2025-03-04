# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe Uroman do
  describe 'version information' do
    it 'has a version number' do
      expect(Uroman::VERSION).not_to be nil
    end

    it 'has a last modification date' do
      expect(Uroman::LAST_MOD_DATE).not_to be nil
    end
  end
end
