# frozen_string_literal: true

require_relative 'uroman/version'
require_relative 'uroman/util'
require_relative 'uroman/dict'
require_relative 'uroman/edge'
require_relative 'uroman/num_edge'
require_relative 'uroman/lattice'
require_relative 'uroman/data'

module Uroman
  extend self

  def romanize_string(input, **args)
    data.romanize_string(input, **args)
  end

  private

  def data
    @data ||= Data.new
  end
end
