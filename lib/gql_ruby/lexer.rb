# frozen_string_literal: true

require 'gql_ruby/lexer/version'
require 'gql_ruby/source_position'
require 'gql_ruby/lexer/token'
require 'gql_ruby/lexer/span'
require 'gql_ruby/iterator'
require 'gql_ruby/lexer/types'

module GqlRuby
  class Lexer
    extend Dry::Initializer
    include Dry::Monads[:maybe, :result, :try]

    class UnknownCharacterError < StandardError; end
    class UnexpectedCharacterError < StandardError; end
    class UnterminatedStringError < StandardError; end
    class UnknownCharacterInStringError < StandardError; end
    class UnknownEscapeSequenceError < StandardError; end
    class UnexpectedEndOfFileError < StandardError; end
    class InvalidNumberError < StandardError; end

    param :source
    option :iterator, default: -> { GqlRuby::Iterator.new(source.chars) }
    option :length, default: -> { source.length }
    option :position, default: -> { GqlRuby::SourcePosition.new }
    option :reached_eof, default: -> { false }

    attr_reader :token

    def next
      return @token = None() if reached_eof

      scan_over_whitespace

      ch = iterator.peek.fmap { |_, char| char }

      value = case ch
              when Some('!') then Success(emit_single_char(Token::EXCLAMATION))
              when Some('$') then Success(emit_single_char(Token::DOLLAR))
              when Some('(') then Success(emit_single_char(Token::PAREN_OPEN))
              when Some(')') then Success(emit_single_char(Token::PAREN_CLOSE))
              when Some('[') then Success(emit_single_char(Token::BRACKET_OPEN))
              when Some(']') then Success(emit_single_char(Token::BRACKET_CLOSE))
              when Some('{') then Success(emit_single_char(Token::CURLY_OPEN))
              when Some('}') then Success(emit_single_char(Token::CURLY_CLOSE))
              when Some(':') then Success(emit_single_char(Token::COLON))
              when Some('=') then Success(emit_single_char(Token::EQUALS))
              when Some('@') then Success(emit_single_char(Token::AT))
              when Some('|') then Success(emit_single_char(Token::PIPE))
              when Some('&') then Success(emit_single_char(Token::AMP))
              when Some('.') then scan_ellipsis
              when Some('"') then scan_string
              when None()
                @reached_eof = true
                Success(
                  Span.zero_width(
                    position,
                    Token::EOF
                  )
                )
              else
                if number_start?(ch.value!)
                  scan_number
                elsif name_start?(ch.value!)
                  scan_name
                else
                  Failure(
                    Span.zero_width(
                      position,
                      UnknownCharacterError.new(ch.value!)
                    )
                  )
                end
              end

      @token = Maybe(value)
    end

    def emit_single_char(token)
      start_pos = position.clone
      value = next_char
      raise 'Internal error in lexer - EOF on emit_single_char' if value.failure?

      Span.single_width(start_pos, token)
    end

    def scan_over_whitespace
      while (value = peek_char).to_result.success?
        _, ch = value.value!

        if ["\t", ' ', "\n", "\r", ','].include?(ch)
          next_char
        elsif ch == '#'
          next_char
          while (value = peek_char).to_result.success?
            _, ch = value.value!
            is_line_break = source_char?(ch) && ["\n", "\r"].include?(ch)
            break unless is_line_break || source_char?(ch)

            next_char && break if is_line_break

            next_char if source_char?(ch)
          end
        else
          break
        end
      end
    end

    def next_char
      value = iterator.next
      return value if value == None()

      _, ch = value.value!
      ch == "\n" ? position.advance_line : position.advance_column
      value
    end

    def peek_char
      iterator.peek
    end

    def resolve_iterator
      iterator.peek.flatten
    end

    def source_char?(char)
      ["\t", "\n", "\r"].include?(char) || char >= ' '
    end

    def number_start?(char)
      ('0'..'9').include?(char) || char == '-'
    end

    def name_start?(char)
      ('A'..'Z').include?(char.upcase) || char == '_'
    end

    def name_cont?(char)
      ('0'..'9').include?(char) || name_start?(char)
    end

    def scan_ellipsis
      start_pos = position.clone
      start_value = peek_char

      3.times do
        value = next_char
        return Failure(Span.zero_width(position, UnexpectedEndOfFileError.new)) if value.to_result.failure?

        _, ch = value.value!
        return Failure(Span.zero_width(start_pos, UnexpectedCharacterError.new(start_value.value!.last))) if ch != '.'
      end

      Success(Span.new(start: start_pos, finish: position, item: Token::ELLIPSIS))
    end

    def scan_number
      start_pos = position.clone
      start_value = peek_char
      return Failure(Span.zero_width(position, UnexpectedEndOfFileError.new)) if start_value.to_result.failure?

      start_idx, = start_value.value!
      last_idx = start_idx
      last_char = '1'
      is_float = false

      end_idx = loop do
        break last_idx + 1 if (value = peek_char).to_result.failure?

        idx, ch = value.value!
        if ('0'..'9').include?(ch) || (ch == '-' && last_idx == start_idx)
          is_second_zero = (ch == '0' && last_char == '0' && last_idx == start_idx)
          return Failure(Span.zero_width(position, UnexpectedCharacterError.new('0'))) if is_second_zero

          next_char
          last_char = ch
        elsif last_char == '-'
          return Failure(Span.zero_width(position, UnexpectedCharacterError.new(ch)))
        else
          break idx
        end
        last_idx = idx
      end

      if (value = peek_char).to_result.success?
        new_start_idx, ch = value.value!
        if ch == '.'
          is_float = true
          last_idx = new_start_idx
          next_char
          end_idx = loop do
            value = peek_char
            if value.to_result.failure?
              return Failure(Span.zero_width(position, UnexpectedEndOfFileError.new)) if last_idx == new_start_idx

              break last_idx + 1
            end

            idx, ch = value.value!
            if ('0'..'9').include?(ch)
              next_char
            elsif last_idx == new_start_idx
              return Failure(Span.zero_width(position, UnexpectedCharacterError.new(ch)))
            else
              break idx
            end

            last_idx = idx
          end
        end
        if %w[e E].include?(ch)
          is_float = true
          next_char
          last_idx = new_start_idx

          end_idx = loop do
            value = peek_char
            if value.to_result.failure?
              return Failure(Span.zero_width(position, UnexpectedEndOfFileError.new)) if last_idx == new_start_idx

              break last_idx + 1
            end

            idx, ch = value.value!
            if ('0'..'9').include?(ch) || (last_idx == new_start_idx && ['-', '+'].include?(ch))
              next_char
            elsif last_idx == new_start_idx
              return Failure(Span.zero_width(position, UnexpectedCharacterError.new(ch)))
            else
              break idx
            end

            last_idx = idx
          end
        end
      end

      number = source[start_idx..end_idx - 1]
      end_pos = position

      type = is_float ? Types::Coercible::Float : Types::Coercible::Integer
      token = Token::Scalar(type[number])

      Success(Span.new(start: start_pos, finish: end_pos, item: token))
    end

    def scan_string
      start_pos = position.clone
      start_value = next_char
      return Failure(Span.zero_width(position, UnexpectedEndOfFileError.new)) if start_value.to_result.failure?

      start_idx, start_ch = start_value.value!
      return Failure(Span.zero_width(position, UnterminatedStringError.new)) if start_ch != '"'

      escaped = false
      old_pos = position.clone
      while (value = next_char).to_result.success?
        idx, ch = value.value!
        case ch
        when 'b', 'f', 'n', 'r', 't', '/' then escaped = false if escaped
        when 'u'
          if escaped
            escaped = false
            scan_value = scan_escaped_unicode(old_pos)
            return scan_value if scan_value.failure?
          end
        when '\\'
          escaped = !escaped
        when '"'
          unless escaped
            return Success(
              Span.new(
                start: start_pos,
                finish: position,
                item: Token::Scalar(Types::Strict::String[source[(start_idx + 1)...idx]])
              ))
          end
          escaped = false
        when "\n", "\r"
          return Failure(Span.zero_width(
                           old_pos,
                           UnterminatedStringError.new
                         ))
        else
          return Failure(Span.zero_width(old_pos, UnknownEscapeSequenceError.new("\\#{ch}"))) if escaped
          return Failure(Span.zero_width(old_pos, UnknownCharacterInStringError.new(ch))) unless source_char?(ch)
        end
        old_pos = position.clone
      end
      Failure(Span.zero_width(position, UnterminatedStringError.new))
    end

    def scan_escaped_unicode(start_pos)
      start_value = peek_char
      return Failure(Span.zero_width(position, UnterminatedStringError.new)) if start_value.to_result.failure?

      start_idx, = start_value.value!
      end_idx = start_idx
      len = 0

      4.times do
        value = next_char
        return Failure(Span.zero_width(position, UnterminatedStringError.new)) if value.to_result.failure?

        idx, ch = value.value!
        break unless alphanumeric?(ch)

        end_idx = idx
        len += 1
      end

      escape = source[start_idx..end_idx]
      return Failure(Span.zero_width(start_pos, UnknownEscapeSequenceError.new("\\u#{escape}"))) if len != 4

      # TODO: Add validation for proper unicode sequence
      codepoint = Try { Integer(escape, 16) }.to_result
      return Failure(Span.zero_width(start_pos, UnknownEscapeSequenceError.new("\\u#{escape}"))) if codepoint.failure?

      Success()
    end

    def alphanumeric?(char)
      Maybe(char =~ /[[:alnum:]]/).to_result.success?
    end

    def scan_name
      start_pos = position.clone
      start_value = next_char
      return Failure(Span.zero_width(position, UnexpectedEndOfFileError.new)) if start_value.to_result.failure?

      start_idx, = start_value.value!
      end_idx = start_idx
      while (value = peek_char).to_result.success?
        idx, ch = value.value!
        break unless name_cont?(ch)

        next_char
        end_idx = idx
      end

      Success(
        Span.new(
          start: start_pos,
          finish: position,
          item: Token::Name(source[start_idx..end_idx])
        )
      )
    end
  end
end
