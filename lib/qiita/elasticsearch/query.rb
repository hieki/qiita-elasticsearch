require "active_support/core_ext/object/try"
require "qiita/elasticsearch/nodes/null_node"
require "qiita/elasticsearch/nodes/or_separatable_node"
require "qiita/elasticsearch/tokenizer"

module Qiita
  module Elasticsearch
    class Query
      DEFAULT_SORT = [{ "created_at" => "desc" }, "_score"]

      SORTS_TABLE = {
        "created-asc" => [{ "created_at" => "asc" }, "_score"],
        "created-desc" => [{ "created_at" => "desc" }, "_score"],
        "likes-asc" => [{ "lgtms" => "asc" }, "_score"],
        "likes-desc" => [{ "lgtms" => "desc" }, "_score"],
        "related-asc" => ["_score"],
        "related-desc" => [{ "_score" => "desc" }],
        "stocks-asc" => [{ "stocks" => "asc" }, "_score"],
        "stocks-desc" => [{ "stocks" => "desc" }, "_score"],
        "updated-asc" => [{ "updated_at" => "asc" }, "_score"],
        "updated-desc" => [{ "updated_at" => "desc" }, "_score"],
      }

      # @param [Array<Qiita::Elasticsearch::Token>] tokens
      # @param [Hash] query_builder_options For building new query from this query
      def initialize(tokens, tokenizer)
        @tokens = tokens.freeze
        @tokenizer = tokenizer
      end

      # @param [String] field_name
      # @param [String] term
      # @return [Qiita::Elasticsearch::Query]
      # @example query.append_field_token(field_name: "tag", term: "Ruby")
      def append_field_token(field_name: nil, term: nil)
        if has_field_token?(field_name: field_name, term: term)
          self
        else
          new_token = @tokenizer.create_token(field_name: field_name, term: term)
          dup_with_tokens([*@tokens, new_token])
        end
      end

      # @param [String] field_name
      # @param [String] term
      # @return [Qiita::Elasticsearch::Query]
      # @example query.delete_field_token(field_name: "tag", term: "Ruby")
      def delete_field_token(field_name: nil, term: nil)
        dup_with_tokens(
          @tokens.reject do |token|
            (field_name.nil? || token.field_name == field_name) && (term.nil? || token.term == term)
          end
        )
      end

      # @param [String] field_name
      # @param [false, nil, true] positive
      # @param [String] term
      # @example query.has_field_token?(field_name: "tag", term: "Ruby")
      def has_field_token?(field_name: nil, positive: nil, term: nil)
        @tokens.any? do |token|
          (field_name.nil? || token.field_name == field_name) && (term.nil? || token.term == term) &&
            (positive.nil? || positive && token.positive? || !positive && token.negative?)
        end
      end

      # @return [Hash] query property for request body for Elasticsearch
      def query
        Nodes::OrSeparatableNode.new(@tokens).to_hash
      end

      # @return [Array] sort property for request body for Elasticsearch
      def sort
        SORTS_TABLE[sort_term] || DEFAULT_SORT
      end

      def sort_term
        term = @tokens.select(&:sort?).last.try(:term)
        term if SORTS_TABLE.key?(term)
      end

      # @return [Hash] request body for Elasticsearch
      def to_hash
        {
          "query" => query,
          "sort" => sort,
        }
      end

      # @return [String] query string generated from its tokens
      def to_s
        @tokens.join(" ")
      end

      # @return [String, nil] last positive type name in query string
      def type
        @tokens.select(&:type?).select(&:positive?).last.try(:type)
      end

      # @param [String] field_name
      # @param [String] term
      # @return [Qiita::Elasticsearch::Query]
      # @example query.update_field_token(field_name: "tag", term: "Ruby")
      def update_field_token(field_name: nil, term: nil)
        tokens = @tokens.reject { |token| token.field_name == field_name }
        new_token = @tokenizer.create_token(field_name: field_name, term: term)
        dup_with_tokens(tokens << new_token)
      end

      private

      # Build a new query from query string
      # @param [String] query_string
      # @return [Qiita::Elasticsearch::Query]
      # @example build_query("test tag:Ruby")
      def dup_with_tokens(tokens)
        self.class.new(tokens, @tokenizer)
      end
    end
  end
end
