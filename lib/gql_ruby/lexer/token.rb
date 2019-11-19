require 'dry/initializer'
require 'dry/equalizer'

module GqlRuby
  class Lexer
    module Token
      EOF = :eof
      ELLIPSIS = :ellipsis
      EXCLAMATION = :exclamation
      DOLLAR = :dollar
      PAREN_OPEN = :paren_open
      PAREN_CLOSE = :paren_close
      BRACKET_OPEN = :bracket_open
      BRACKET_CLOSE = :bracket_close
      CURLY_OPEN = :curly_open
      CURLY_CLOSE = :curly_close
      COLON = :colon
      EQUALS = :equals
      AT = :at
      PIPE = :pipe

      class Name
        extend Dry::Initializer
        include Dry::Equalizer(:value)

        param :value
      end

      class Scalar
        extend Dry::Initializer
        include Dry::Equalizer(:value)

        param :value
      end

      def self.Name(name)
        Name.new(name)
      end

      def self.Scalar(value)
        Scalar.new(value)
      end
    end
  end
end
