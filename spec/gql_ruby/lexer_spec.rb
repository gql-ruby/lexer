# frozen_string_literal: true

require 'pry'
require 'dry/monads'

RSpec.describe GqlRuby::Lexer do
  extend Dry::Monads[:maybe, :result]
  include Dry::Monads[:maybe, :result]

  it 'has a version number' do
    expect(described_class::VERSION).not_to be nil
  end

  it 'parses empty source' do
    actual = tokenize_to_array('')
    expected = [
      described_class::Span.zero_width(
        GqlRuby::SourcePosition.new,
        described_class::Token::EOF
      )
    ]
    expect(actual).to eq(expected)
  end

  it 'disallows control codes' do
    actual = described_class.new("\u0007").next
    expected = Some(Failure(
                      described_class::Span.zero_width(
                        GqlRuby::SourcePosition.new,
                        described_class::UnknownCharacterError.new("\u0007")
                      )
                    ))
    expect(actual).to eq(expected)
  end

  it 'skips whitespaces' do
    actual = tokenize_to_array(
      <<-GRAPHQL
        foo

      GRAPHQL
    )
    expected = [
      described_class::Span.new(
        start: GqlRuby::SourcePosition.new(8, 0, 8),
        finish: GqlRuby::SourcePosition.new(13, 2, 0),
        item: described_class::Token::Name('foo')
      ),
      described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(13, 2, 0),
        described_class::Token::EOF
      )
    ]
    expect(actual).to eq(expected)
  end

  it 'skips comments' do
    actual = tokenize_to_array(
      <<-GRAPHQL
      #comment
      foo#comment
      GRAPHQL
    )
    expected = [
      described_class::Span.new(
        start: GqlRuby::SourcePosition.new(21, 1, 6),
        finish: GqlRuby::SourcePosition.new(33, 2, 0),
        item: described_class::Token::Name('foo')
      ),
      described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(33, 2, 0),
        described_class::Token::EOF
      )
    ]
    expect(actual).to eq(expected)
  end

  it 'skips commas' do
    actual = tokenize_to_array(',,,foo,,,')
    expected = [
      described_class::Span.new(
        start: GqlRuby::SourcePosition.new(3, 0, 3),
        finish: GqlRuby::SourcePosition.new(9, 0, 9),
        item: described_class::Token::Name('foo')
      ),
      described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(9, 0, 9),
        described_class::Token::EOF
      )
    ]
    expect(actual).to eq(expected)
  end

  it 'shows proper error positions' do
    actual = described_class.new(
      <<-GRAPHQL
      ?

      GRAPHQL
    ).next
    expected = Some(Failure(
                      described_class::Span.zero_width(
                        GqlRuby::SourcePosition.new(6, 0, 6),
                        described_class::UnknownCharacterError.new('?')
                      )
                    ))
    expect(actual).to eq(expected)
  end

  context 'strings' do
    it 'parses simple string' do
      actual = tokenize_single('"simple"')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(8, 0, 8),
        item: described_class::Token::Scalar(described_class::Types::Strict::String['simple'])
      )
      expect(actual).to eq(expected)
    end

    it 'skips whitespaces' do
      actual = tokenize_single('" white space "')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(15, 0, 15),
        item: described_class::Token::Scalar(described_class::Types::Strict::String[' white space '])
      )
      expect(actual).to eq(expected)
    end

    it 'parses escaped quote' do
      actual = tokenize_single('"quote \""')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(10, 0, 10),
        item: described_class::Token::Scalar(described_class::Types::Strict::String['quote \"'])
      )
      expect(actual).to eq(expected)
    end

    it 'parses escaped control sequences' do
      actual = tokenize_single('"escaped \n\r\b\t\f"')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(20, 0, 20),
        item: described_class::Token::Scalar(described_class::Types::Strict::String['escaped \n\r\b\t\f'])
      )
      expect(actual).to eq(expected)
    end

    it 'parses slashes' do
      actual = tokenize_single('"slashes \\\\ \/"')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(15, 0, 15),
        item: described_class::Token::Scalar(described_class::Types::Strict::String['slashes \\\\ \/'])
      )
      expect(actual).to eq(expected)
    end

    it 'parses unicode' do
      actual = tokenize_single('"unicode \u1234\u5678\u90AB\uCDEF"')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(34, 0, 34),
        item: described_class::Token::Scalar(described_class::Types::Strict::String['unicode \u1234\u5678\u90AB\uCDEF'])
      )
      expect(actual).to eq(expected)
    end
  end

  context 'string errors' do
    it 'throws error for unterminated string' do
      actual = tokenize_error('"')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(1, 0, 1),
        described_class::UnterminatedStringError.new
      )
      expect(actual).to eq(expected)
    end

    it 'throws error for no end quote' do
      actual = tokenize_error('"no end quote')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(13, 0, 13),
        described_class::UnterminatedStringError.new
      )
      expect(actual).to eq(expected)
    end

    it 'throws error for unescaped control char' do
      actual = tokenize_error("\"contains unescaped \u0007 control char\"")
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(20, 0, 20),
        described_class::UnknownCharacterInStringError.new("\u0007")
      )
      expect(actual).to eq(expected)
    end

    it 'throws error for unexpected null-byte' do
      actual = tokenize_error("\"null-byte is not \u0000 end of file\"")
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(18, 0, 18),
        described_class::UnknownCharacterInStringError.new("\u0000")
      )
      expect(actual).to eq(expected)
    end

    it 'throws error for unexpected \\n' do
      actual = tokenize_error("\"multi\nline\"")
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(6, 0, 6),
        described_class::UnterminatedStringError.new
      )
      expect(actual).to eq(expected)
    end

    it 'throws error for unexpected \\r' do
      actual = tokenize_error("\"multi\rline\"")
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(6, 0, 6),
        described_class::UnterminatedStringError.new
      )
      expect(actual).to eq(expected)
    end

    it 'throws error on wrong \\z sequence' do
      actual = tokenize_error('"bad \z esc"')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(6, 0, 6),
        described_class::UnknownEscapeSequenceError.new('\z')
      )
      expect(actual).to eq(expected)
    end

    it 'throws error on wrong \\x sequence' do
      actual = tokenize_error('"bad \x esc"')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(6, 0, 6),
        described_class::UnknownEscapeSequenceError.new('\x')
      )
      expect(actual).to eq(expected)
    end

    it 'throws error on wrong \\u1 sequence' do
      actual = tokenize_error('"bad \u1 esc"')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(6, 0, 6),
        described_class::UnknownEscapeSequenceError.new('\u1')
      )
      expect(actual).to eq(expected)
    end

    it 'throws error on wrong \\u0XX1 sequence' do
      actual = tokenize_error('"bad \u0XX1 esc"')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(6, 0, 6),
        described_class::UnknownEscapeSequenceError.new('\u0XX1')
      )
      expect(actual).to eq(expected)
    end

    it 'throws error on wrong \\uXXXX sequence' do
      actual = tokenize_error('"bad \uXXXX esc"')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(6, 0, 6),
        described_class::UnknownEscapeSequenceError.new('\uXXXX')
      )
      expect(actual).to eq(expected)
    end

    it 'throws error on wrong \\uFXXX sequence' do
      actual = tokenize_error('"bad \uFXXX esc"')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(6, 0, 6),
        described_class::UnknownEscapeSequenceError.new('\uFXXX')
      )
      expect(actual).to eq(expected)
    end

    it 'throws error on wrong \\uXXXF sequence' do
      actual = tokenize_error('"bad \uXXXF esc"')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(6, 0, 6),
        described_class::UnknownEscapeSequenceError.new('\uXXXF')
      )
      expect(actual).to eq(expected)
    end

    it 'throws error on unterminated "' do
      actual = tokenize_error('"unterminated in string \"')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(26, 0, 26),
        described_class::UnterminatedStringError.new
      )
      expect(actual).to eq(expected)
    end

    it 'throws error on unterminated \\' do
      actual = tokenize_error('"unterminated \\')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(15, 0, 15),
        described_class::UnterminatedStringError.new
      )
      expect(actual).to eq(expected)
    end
  end

  context 'numbers' do
    it 'parses simple number' do
      actual = tokenize_single('4')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(1, 0, 1),
        item: described_class::Token::Scalar(described_class::Types::Strict::Integer[4])
      )
      expect(actual).to eq(expected)
    end

    it 'parses negative number' do
      actual = tokenize_single('-4')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(2, 0, 2),
        item: described_class::Token::Scalar(described_class::Types::Strict::Integer[-4])
      )
      expect(actual).to eq(expected)
    end

    it 'parses start of digits range' do
      actual = tokenize_single('0')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(1, 0, 1),
        item: described_class::Token::Scalar(described_class::Types::Strict::Integer[0])
      )
      expect(actual).to eq(expected)
    end

    it 'parses end of digits range' do
      actual = tokenize_single('9')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(1, 0, 1),
        item: described_class::Token::Scalar(described_class::Types::Strict::Integer[9])
      )
      expect(actual).to eq(expected)
    end

    it 'parses float with 0 fraction part' do
      actual = tokenize_single('4.0')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(3, 0, 3),
        item: described_class::Token::Scalar(described_class::Types::Strict::Float[4.0])
      )
      expect(actual).to eq(expected)
    end

    it 'parses float with non-0 fraction part' do
      actual = tokenize_single('4.123')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(5, 0, 5),
        item: described_class::Token::Scalar(described_class::Types::Strict::Float[4.123])
      )
      expect(actual).to eq(expected)
    end

    it 'parses negative float with non-0 fraction part' do
      actual = tokenize_single('-4.123')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(6, 0, 6),
        item: described_class::Token::Scalar(described_class::Types::Strict::Float[-4.123])
      )
      expect(actual).to eq(expected)
    end

    it 'parses float with non-0 fraction part and 0 int part' do
      actual = tokenize_single('0.123')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(5, 0, 5),
        item: described_class::Token::Scalar(described_class::Types::Strict::Float[0.123])
      )
      expect(actual).to eq(expected)
    end

    it 'parses float with lower-case e' do
      actual = tokenize_single('123e4')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(5, 0, 5),
        item: described_class::Token::Scalar(described_class::Types::Strict::Float[123e4])
      )
      expect(actual).to eq(expected)
    end

    it 'parses float with upper-case e' do
      actual = tokenize_single('123E4')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(5, 0, 5),
        item: described_class::Token::Scalar(described_class::Types::Strict::Float[123E4])
      )
      expect(actual).to eq(expected)
    end

    it 'parses float with lower-case negative e' do
      actual = tokenize_single('123e-4')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(6, 0, 6),
        item: described_class::Token::Scalar(described_class::Types::Strict::Float[123e-4])
      )
      expect(actual).to eq(expected)
    end

    it 'parses float with lower-case positive e' do
      actual = tokenize_single('123e+4')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(6, 0, 6),
        item: described_class::Token::Scalar(described_class::Types::Strict::Float[123e+4])
      )
      expect(actual).to eq(expected)
    end

    it 'parses negative float with lower-case e' do
      actual = tokenize_single('-1.123e4')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(8, 0, 8),
        item: described_class::Token::Scalar(described_class::Types::Strict::Float[-1.123e4])
      )
      expect(actual).to eq(expected)
    end

    it 'parses negative float with upper-case e' do
      actual = tokenize_single('-1.123E4')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(8, 0, 8),
        item: described_class::Token::Scalar(described_class::Types::Strict::Float[-1.123E4])
      )
      expect(actual).to eq(expected)
    end

    it 'parses negative float with lower-case negative e' do
      actual = tokenize_single('-1.123e-4')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(9, 0, 9),
        item: described_class::Token::Scalar(described_class::Types::Strict::Float[-1.123e-4])
      )
      expect(actual).to eq(expected)
    end

    it 'parses negative float with lower-case positive e' do
      actual = tokenize_single('-1.123e+4')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(9, 0, 9),
        item: described_class::Token::Scalar(described_class::Types::Strict::Float[-1.123e+4])
      )
      expect(actual).to eq(expected)
    end

    it 'parses negative float with 2-symbol positive e' do
      actual = tokenize_single('-1.123e45')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(9, 0, 9),
        item: described_class::Token::Scalar(described_class::Types::Strict::Float[-1.123e45])
      )
      expect(actual).to eq(expected)
    end
  end

  context 'numbers errors' do
    it 'throws error for 00' do
      actual = tokenize_error('00')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(1, 0, 1),
        described_class::UnexpectedCharacterError.new('0')
      )
      expect(actual).to eq(expected)
    end

    it 'throws error for +1' do
      actual = tokenize_error('+1')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(0, 0, 0),
        described_class::UnknownCharacterError.new('+')
      )
      expect(actual).to eq(expected)
    end

    it 'throws error for 1.' do
      actual = tokenize_error('1.')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(2, 0, 2),
        described_class::UnexpectedEndOfFileError.new
      )
      expect(actual).to eq(expected)
    end

    it 'throws error for .123' do
      actual = tokenize_error('.123')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(0, 0, 0),
        described_class::UnexpectedCharacterError.new('.')
      )
      expect(actual).to eq(expected)
    end

    it 'throws error for 1.A' do
      actual = tokenize_error('1.A')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(2, 0, 2),
        described_class::UnexpectedCharacterError.new('A')
      )
      expect(actual).to eq(expected)
    end

    it 'throws error for -A' do
      actual = tokenize_error('-A')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(1, 0, 1),
        described_class::UnexpectedCharacterError.new('A')
      )
      expect(actual).to eq(expected)
    end

    it 'throws error for 1.0e' do
      actual = tokenize_error('1.0e')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(4, 0, 4),
        described_class::UnexpectedEndOfFileError.new
      )
      expect(actual).to eq(expected)
    end

    it 'throws error for 1.0eA' do
      actual = tokenize_error('1.0eA')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(4, 0, 4),
        described_class::UnexpectedCharacterError.new('A')
      )
      expect(actual).to eq(expected)
    end
  end

  context 'punctuation' do
    it 'parses !' do
      actual = tokenize_single('!')
      expected = described_class::Span.single_width(
        GqlRuby::SourcePosition.new(0, 0, 0),
        described_class::Token::EXCLAMATION
      )
      expect(actual).to eq(expected)
    end

    it 'parses $' do
      actual = tokenize_single('$')
      expected = described_class::Span.single_width(
        GqlRuby::SourcePosition.new(0, 0, 0),
        described_class::Token::DOLLAR
      )
      expect(actual).to eq(expected)
    end

    it 'parses (' do
      actual = tokenize_single('(')
      expected = described_class::Span.single_width(
        GqlRuby::SourcePosition.new(0, 0, 0),
        described_class::Token::PAREN_OPEN
      )
      expect(actual).to eq(expected)
    end

    it 'parses )' do
      actual = tokenize_single(')')
      expected = described_class::Span.single_width(
        GqlRuby::SourcePosition.new(0, 0, 0),
        described_class::Token::PAREN_CLOSE
      )
      expect(actual).to eq(expected)
    end

    it 'parses [' do
      actual = tokenize_single('[')
      expected = described_class::Span.single_width(
        GqlRuby::SourcePosition.new(0, 0, 0),
        described_class::Token::BRACKET_OPEN
      )
      expect(actual).to eq(expected)
    end

    it 'parses ]' do
      actual = tokenize_single(']')
      expected = described_class::Span.single_width(
        GqlRuby::SourcePosition.new(0, 0, 0),
        described_class::Token::BRACKET_CLOSE
      )
      expect(actual).to eq(expected)
    end

    it 'parses {' do
      actual = tokenize_single('{')
      expected = described_class::Span.single_width(
        GqlRuby::SourcePosition.new(0, 0, 0),
        described_class::Token::CURLY_OPEN
      )
      expect(actual).to eq(expected)
    end

    it 'parses }' do
      actual = tokenize_single('}')
      expected = described_class::Span.single_width(
        GqlRuby::SourcePosition.new(0, 0, 0),
        described_class::Token::CURLY_CLOSE
      )
      expect(actual).to eq(expected)
    end

    it 'parses :' do
      actual = tokenize_single(':')
      expected = described_class::Span.single_width(
        GqlRuby::SourcePosition.new(0, 0, 0),
        described_class::Token::COLON
      )
      expect(actual).to eq(expected)
    end

    it 'parses =' do
      actual = tokenize_single('=')
      expected = described_class::Span.single_width(
        GqlRuby::SourcePosition.new(0, 0, 0),
        described_class::Token::EQUALS
      )
      expect(actual).to eq(expected)
    end

    it 'parses @' do
      actual = tokenize_single('@')
      expected = described_class::Span.single_width(
        GqlRuby::SourcePosition.new(0, 0, 0),
        described_class::Token::AT
      )
      expect(actual).to eq(expected)
    end

    it 'parses |' do
      actual = tokenize_single('|')
      expected = described_class::Span.single_width(
        GqlRuby::SourcePosition.new(0, 0, 0),
        described_class::Token::PIPE
      )
      expect(actual).to eq(expected)
    end

    it 'parses ...' do
      actual = tokenize_single('...')
      expected = described_class::Span.new(
        start: GqlRuby::SourcePosition.new(0, 0, 0),
        finish: GqlRuby::SourcePosition.new(3, 0, 3),
        item: described_class::Token::ELLIPSIS
      )
      expect(actual).to eq(expected)
    end
  end

  context 'punctuation errors' do
    it 'throws error on unfinished ...' do
      actual = tokenize_error('..')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(2, 0, 2),
        described_class::UnexpectedEndOfFileError.new
      )
      expect(actual).to eq(expected)
    end

    it 'throws error on ?' do
      actual = tokenize_error('?')
      expected = described_class::Span.zero_width(
        GqlRuby::SourcePosition.new(0, 0, 0),
        described_class::UnknownCharacterError.new('?')
      )
      expect(actual).to eq(expected)
    end
  end

  def tokenize_to_array(source)
    tokens = []
    lexer = described_class.new(source)
    loop do
      case t = lexer.next
      when Some(Dry::Monads::Result::Success)
        value = t.flatten.value!
        tokens.push(value)
        break if value.item == described_class::Token::EOF
      when Some(Dry::Monads::Result::Failure)
        value = t.flatten.failure
        line = value.start.line
        col = value.start.col
        item = value.item.inspect
        raise StandardError, "Error happened on line #{line}, col #{col} - #{item}"
      when Dry::Monads::Maybe::None
        raise 'EOF before EndOfFile'
      end
    end
    tokens
  end

  def tokenize_single(source)
    tokens = tokenize_to_array(source)
    expect(tokens.length).to eq(2)
    expect(tokens.last.item).to eq(described_class::Token::EOF)
    tokens.first
  end

  def tokenize_error(source)
    lexer = described_class.new(source)
    loop do
      case t = lexer.next
      when Some(Dry::Monads::Result::Success)
        value = t.flatten.value!
        raise "Error has not been raised for #{source}" if value.item == described_class::Token::EOF
      when Some(Dry::Monads::Result::Failure)
        return t.flatten.failure
      when Dry::Monads::Maybe::None
        raise "Error has not been raised for #{source}"
      end
    end
  end
end
