# frozen_string_literal: true

require 'dry/initializer'
require 'dry/equalizer'

module GqlRuby
  class Lexer
    class Span
      extend Dry::Initializer
      include Dry::Equalizer(:start, :finish, :item)

      option :start
      option :finish
      option :item

      class << self
        def zero_width(position, token)
          new(start: position, finish: position, item: token)
        end

        def single_width(position, token)
          finish = position.clone
          finish.advance_column
          new(start: position, finish: finish, item: token)
        end
      end
    end
  end
end
