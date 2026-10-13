# frozen_string_literal: true

require "erb"

module SearchablePg
  module Global
    # The sentence of a text that matched a search: the first sentence holding
    # a word that starts with a word of the query, cut to about 160 characters
    # around it, HTML-escaped, with <mark> around each matching word. No
    # sentence matches when the record matched on its title alone, and then
    # there is no snippet.
    module Snippet
      LENGTH = 160

      def self.call(text, query)
        piece, pattern = find(text, query)
        mark(piece, pattern) if piece
      end

      # The same sentence as plain text, for a tool's output.
      def self.text(text, query) = find(text, query)&.first

      def self.find(text, query)
        words = SearchablePg.normalize(query).split.map { |word| Regexp.escape(word) }
        return if words.empty?
        pattern = /(?<![[:alnum:]])(?:#{words.join("|")})[[:alnum:]]*/i
        sentence = text.to_s.split(/\n+|(?<=[.!?])\s+/).find { |candidate| candidate.match?(pattern) }
        [cut(sentence, sentence.index(pattern)), pattern] if sentence
      end

      def self.cut(sentence, at)
        return sentence if sentence.length <= LENGTH
        start = [at - (LENGTH / 3), 0].max
        piece = sentence[start, LENGTH]
        "#{"…" if start.positive?}#{piece.strip}#{"…" if start + LENGTH < sentence.length}"
      end

      def self.mark(text, pattern)
        out = +""
        position = 0
        text.scan(pattern) do
          match = Regexp.last_match
          out << ERB::Util.html_escape(text[position...match.begin(0)]) << "<mark>" << ERB::Util.html_escape(match[0]) << "</mark>"
          position = match.end(0)
        end
        out << ERB::Util.html_escape(text[position..])
      end
      private_class_method :find, :cut, :mark
    end
  end
end
