# frozen_string_literal: true

require "test_helper"

class SnippetTest < ActiveSupport::TestCase
  Snippet = SearchablePg::Global::Snippet

  test "gives the first sentence holding a word that starts with a word typed, with each match marked" do
    text = "Turn the power on.\nBring every fader down before the power goes on. Then check the Faders again."
    assert_equal "Bring every <mark>fader</mark> down before the power goes on.", Snippet.call(text, "fade")
    assert_equal "Turn the <mark>power</mark> on.", Snippet.call(text, "power fader")
    assert_equal "Turn the power on.", Snippet.text(text, "power")
  end

  test "escapes everything but its own marks" do
    assert_equal "A &lt;script&gt;alert(1)&lt;/script&gt; &amp; <mark>fader</mark> note", Snippet.call("A <script>alert(1)</script> & fader note", "fader")
  end

  test "cuts a long sentence around the match, marking only the cut side" do
    snippet = Snippet.call("#{"word " * 60}fader #{"more " * 60}.", "fader")
    assert snippet.start_with?("…") && snippet.end_with?("…") && snippet.include?("<mark>fader</mark>")
    assert_operator snippet.delete_prefix("…").delete_suffix("…").gsub(%r{</?mark>}, "").length, :<=, Snippet::LENGTH
    assert Snippet.call("fader #{"word " * 60}.", "fader").start_with?("<mark>fader</mark>")
    assert Snippet.call("#{"word " * 60}end fader", "fader").end_with?("<mark>fader</mark>")
  end

  test "gives nothing when no sentence matches or nothing was typed" do
    assert_nil Snippet.call("Check the microphone.", "fader")
    assert_nil Snippet.call("Check the microphone.", " ")
    assert_nil Snippet.call(nil, "fader")
  end
end
