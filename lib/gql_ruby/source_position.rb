require 'dry/initializer'

module GqlRuby
  class SourcePosition
    extend Dry::Initializer
    include Comparable

    option :index, optional: true, default: -> { 0 }
    option :line, optional: true, default: -> { 0 }
    option :col, optional: true, default: -> { 0 }

    def advance_line
      @index += 1
      @line += 1
      @col = 0
    end

    def advance_column
      @index += 1
      @col += 1
    end

    def ==(other)
      return false unless other.is_a?(self.class)

      index == other.index && line == other.line && col == other.col
    end
  end
end
