# frozen_string_literal: true

require 'json'

module Uroman
  # This class defines edges that span part of a sentence with a specific romanization.
  # There might be multiple edges for a given span. The edges in turn are part of the
  # romanization lattice.
  class Edge
    attr_accessor :start, :finish, :txt, :type

    def initialize(start, finish, txt, annotation = nil)
      @start = start
      @finish = finish
      @txt = txt
      @type = annotation
    end

    def to_s
      "[#{@start}-#{@finish}] #{@txt} (#{@type})"
    end

    def inspect
      to_s
    end

    def to_json(*_args)
      [@start, @finish, @txt, @type].to_json
    end

    def self.json_str(rom_result)
      return rom_result if rom_result.is_a?(String)

      "[#{rom_result.map { |edge| edge.is_a?(Edge) ? edge.to_json : edge.to_s }.join(',')}]"
    end
  end
end
