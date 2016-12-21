require "qiita/elasticsearch/nodes/null_node"
require "qiita/elasticsearch/nodes/or_separatable_node"
require "qiita/elasticsearch/query"

module Qiita
  module Elasticsearch
    class QueryBuilder
      # @param [Array<String>, nil] all_fields
      # @param [Array<String>, nil] date_fields
      # @param [Array<String>, nil] default_fields
      # @param [Array<String>, nil] downcased_fields
      # @param [Hash, nil] field_mapping for field aliasing
      # @param [Array<String>, nil] filterable_fields
      # @param [Array<String>, nil] hierarchal_fields
      # @param [Array<String>, nil] int_fields
      # @param [Hash, nil] matchable_options
      # @param [String, nil] time_zone
      def initialize(all_fields: nil, date_fields: nil, default_fields: nil, downcased_fields: nil, field_mapping: nil, filterable_fields: nil, hierarchal_fields: nil, int_fields: nil, matchable_options: nil, time_zone: nil)
        @all_fields = all_fields
        @date_fields = date_fields
        @default_fields = default_fields
        @downcased_fields = downcased_fields
        @field_mapping = field_mapping
        @filterable_fields = filterable_fields
        @hierarchal_fields = hierarchal_fields
        @int_fields = int_fields
        @matchable_options = matchable_options
        @time_zone = time_zone
      end

      # @param [String] query_string Raw query string
      # @return [Qiita::Elasticsearch::Query]
      def build(query_string)
        Query.new(
          tokenizer.tokenize(query_string),
          default_fields: @default_fields,
          downcased_fields: @downcased_fields,
          filterable_fields: @filterable_fields,
          hierarchal_fields: @hierarchal_fields,
          int_fields: @int_fields,
          time_zone: @time_zone,
        )
      end

      private

      def tokenizer
        @tokenizer ||= Tokenizer.new(
          all_fields: @all_fields,
          date_fields: @date_fields,
          default_fields: @default_fields,
          downcased_fields: @downcased_fields,
          field_mapping: @field_mapping,
          filterable_fields: @filterable_fields,
          hierarchal_fields: @hierarchal_fields,
          int_fields: @int_fields,
          matchable_options: @matchable_options,
          time_zone: @time_zone,
        )
      end
    end
  end
end
