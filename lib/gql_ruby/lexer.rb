require "gql_ruby/lexer/version"
require 'gql_ruby/source_position'
require 'gql_ruby/lexer/token'
require 'gql_ruby/lexer/span'

module GqlRuby
  class Lexer
    class UnknownCharacterError < StandardError; end
    class UnexpectedCharacterError < StandardError; end
    class UnterminatedStringError < StandardError; end
    class UnknownCharacterInStringError < StandardError; end
    class UnknownEscapeSequennceError < StandardError; end
    class UnexpectedEndOfFileError < StandardError; end
    class InvalidNumberError < StandardError; end

    # @param [String] source GraphQL expression source code
    # @return [Lexer]

    attr_reader :iterator, :source, :length, :position, :reached_eof

    def initialize(source)
      @iterator = source.chars
      @source = source
      @length = length
      @position = GqlRuby::SourcePosition.new
      @reached_eof = false
    end

    def next
      return nil if reached_eof?

      scan_over_whitespace

      ch = iterator.first

      case ch
      when '{'
      else
        @reached_eof = true
        Span.zero_width(position, Token::EOF)
      end

    end

    def scan_over_whitespace
      while (ch = iterator.first) do
        case ch
        when "\t", " ", "\n", "\r", "," then next_char
        when "#"
          next_char
          while (ch = iterator.first) do
            if ["\n", "\r"].include?(ch)
              next_char
              break
            elsif ["\t", "\n", "\r"].include?(ch) || ch.ord >= " ".ord
              next_char
            else
              break
            end
          end
        else
          break
        end
      end
    end

    private

    def next_char
      next_ = iterator.shift
      return unless next_

      next_ == "\n" ? position.advance_line : position.advance_column
      next_
    end

    def reached_eof?
      reached_eof
    end
  end
end
