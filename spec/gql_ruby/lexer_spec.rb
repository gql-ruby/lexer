require 'pry'

RSpec.describe GqlRuby::Lexer do
  it "has a version number" do
    expect(GqlRuby::Lexer::VERSION).not_to be nil
  end

  context "tokenization" do
    let(:lexer) { described_class.new(source) }

    context "empty source" do
      let(:source) { "" }

      it "parses correct" do
        tokens = lexer_tokens(lexer)
        expect(tokens).to eq([
          described_class::Span.zero_width(
            GqlRuby::SourcePosition.new,
            described_class::Token::EOF
          )
        ])
      end
    end

    context "contains only comments" do
      let(:source) { "# some comment" }

      it "parses correct" do
        tokens = lexer_tokens(lexer)
        expect(tokens).to eq([
          described_class::Span.zero_width(
            GqlRuby::SourcePosition.new(index: 14, col: 14),
            described_class::Token::EOF
          )
        ])
      end
    end
  end

end

def lexer_tokens(lexer)
  tokens = []
  loop do
    token = lexer.next
    tokens << token
    break if token.item == described_class::Token::EOF
  end
  tokens
end
