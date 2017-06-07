module Gitlab
  module Elastic
    class SnippetProcessor
      def initialize(whole_document, snippet)
        @whole_document = whole_document
        @snippet = snippet
      end

      def startline
        index = @whole_document.rindex(clean_snippet)
        @whole_document[0, index].count("\n") + 1
      end

      # Returns the origin snippet without any highlight tags
      def clean_snippet
        snippet_processed.gsub(/gitlabelasticsearch→|←gitlabelasticsearch/, '')
      end

      # Returns highlighted terms
      def highlighted_terms
        snippet_processed.scan(/gitlabelasticsearch→(.*?)←gitlabelasticsearch/).flatten.uniq
      end

      private

      # Removes a first line if it does not have the highlight tags
      # It's needed because ES can return not the full first code line which is
      # unthinkable to keep as is.
      def snippet_processed
        @snippet_processed ||= @snippet.sub(/^((?!gitlabelasticsearch→).)*[\n\r]/, '')
      end
    end
  end
end
