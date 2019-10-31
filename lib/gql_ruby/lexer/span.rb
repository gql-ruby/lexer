require 'dry/initializer'

module GqlRuby
  class Lexer
    class Span
      extend Dry::Initializer
      include Comparable

      option :start
      option :finish
      option :item

      class << self
        def zero_width(position, token)
          new(start: position, finish: position, item: token)
        end
      end

      def ==(other)
        return false unless other.is_a?(self.class)

        @start == other.start && @finish == other.finish && @item == other.item
      end
    end
  end
end
