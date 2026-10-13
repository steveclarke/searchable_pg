# frozen_string_literal: true

module SearchablePg
  # Prepares a query for :every_word matching. Punctuation between words
  # becomes a space, so "(709) 555-0142" searches as the separate numbers a
  # projection holds and "ada.moss" as two words; a leading "+" goes, and the
  # country code "1" before a ten-digit number. Email addresses are left
  # whole. PostgreSQL would otherwise read "555-0142" as "555" and "-0142".
  module Normalize
    def self.call(query)
      query.to_s.squish.delete_prefix("+").split.map { |word|
        word.include?("@") ? word : word.gsub(%r{[-.,/()]+}, " ")
      }.join(" ").squish.sub(/\A1 ?(?=\d{3} ?\d{3} ?\d{4}\z)/, "")
    end
  end
end
