# frozen_string_literal: true

require "test_helper"

module PlatformosCheck
  module LanguageServer
    class TagCompletionProviderTest < Minitest::Test
      include CompletionProviderTestHelper

      def setup
        @provider = TagCompletionProvider.new
      end

      def test_can_complete?
        assert_can_complete(@provider, "{% ")
        assert_can_complete(@provider, "{%  ")
        assert_can_complete(@provider, "{% rend")
        assert_can_complete(@provider, "{% rend")
        assert_can_complete(@provider, "{% rend %}", -3)

        refute_can_complete(@provider, "{{  ")
        refute_can_complete(@provider, "{% if foo")
      end

      def test_completions
        assert_can_complete_with(@provider, "{% rend", "render")
        assert_can_complete_with(@provider, "{% comm", "comment")
      end

      def test_completions_with_tag_not_in_source_index
        tag_not_in_source_index = 'ifchanged'

        assert_includes(PlatformosLiquid::Tag::LABELS_NOT_IN_SOURCE_INDEX, tag_not_in_source_index)
        assert_can_complete_with(@provider, "{% ", tag_not_in_source_index)
      end

      def test_complete_block_ends
        assert_can_complete_with(@provider, "{% end", "endcomment")
        assert_can_complete_with(@provider, "{% endcomm", "endcomment")
      end
    end
  end
end
