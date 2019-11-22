# frozen_string_literal: true

require 'dry/initializer'
require 'dry/equalizer'

module GqlRuby
  class SourcePosition
    extend Dry::Initializer
    include Dry::Equalizer(:index, :line, :col)

    param :index, optional: true, default: -> { 0 }
    param :line, optional: true, default: -> { 0 }
    param :col, optional: true, default: -> { 0 }

    def advance_line
      @index += 1
      @line += 1
      @col = 0
    end

    def advance_column
      @index += 1
      @col += 1
    end
  end
end
