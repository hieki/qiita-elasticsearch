require "qiita/elasticsearch/date_token"
require "qiita/elasticsearch/filterable_token"
require "qiita/elasticsearch/hierarchal_token"
require "qiita/elasticsearch/matchable_token"
require "qiita/elasticsearch/int_token"
require "qiita/elasticsearch/range_token"

module Qiita
  module Elasticsearch
    class Tokenizer
      DEFAULT_DATE_FIELDS = []
      DEFAULT_DOWNCASED_FIELDS = []
      DEFAULT_FILTERABLE_FIELDS = []
      DEFAULT_HIERARCHAL_FIELDS = []
      DEFAULT_INT_FIELDS = []
      DEFAULT_DEFAULT_FIELDS = []
      EXTRA_DATE_FIELDS = %w(created updated)
      EXTRA_FILTERABLE_FIELDS = %w(created is sort updated)
      DEFAULT_MATCHABLE_OPTIONS = {}
      DEFAULT_FIELD_MAPPING = {}

      TOKEN_PATTERN = /
        (?<token_string>
          (?<minus>-)?
          (?:(?<field_name>\w+):)?
          (?:
            (?:"(?<quoted_term>.*?)(?<!\\)")
            |
            (?<term>\S+)
          )
        )
      /x

      # @param [Array<String>, nil] all_fields
      # @param [Array<String>, nil] date_fields
      # @param [Array<String>, nil] downcased_fields
      # @param [Array<String>, nil] filterable_fields
      # @param [Array<String>, nil] hierarchal_fields
      # @param [Array<String>, nil] int_fields
      # @param [Array<String>, nil] default_fields
      # @param [Hash, nil] matchable_options Optional search parameters for MatchableToken
      # @param [Hash, nil] field_mapping alias of fields
      # @param [String, nil] time_zone
      def initialize(all_fields: nil, date_fields: nil, downcased_fields: nil, filterable_fields: nil, hierarchal_fields: nil, int_fields: nil, default_fields: nil, time_zone: nil, matchable_options: nil, field_mapping: nil)
        @date_fields = (date_fields || DEFAULT_DATE_FIELDS) | EXTRA_DATE_FIELDS
        @downcased_fields = downcased_fields || DEFAULT_DOWNCASED_FIELDS
        @filterable_fields = (filterable_fields || DEFAULT_FILTERABLE_FIELDS) | EXTRA_FILTERABLE_FIELDS
        @hierarchal_fields = hierarchal_fields || DEFAULT_HIERARCHAL_FIELDS
        @int_fields = int_fields || DEFAULT_INT_FIELDS
        @default_fields = default_fields || DEFAULT_DEFAULT_FIELDS
        @matchable_options = matchable_options || DEFAULT_MATCHABLE_OPTIONS
        @field_mapping = field_mapping || DEFAULT_FIELD_MAPPING
        @all_fields = all_fields || aggregate_all_fields
        @time_zone = time_zone
      end

      # @param [String] query_string Raw query string
      # @return [Array<Qiita::Elasticsearch::Token>]
      def tokenize(query_string)
        query_string.scan(TOKEN_PATTERN).map do |token_string, minus, field_name, quoted_term, term|
          term ||= quoted_term
          if !field_name.nil? && !@all_fields.include?(field_name)
            term = "#{field_name}:#{term}"
            field_name = nil
          end
          token = token_class(field_name).new(
            downcased: @downcased_fields.include?(field_name),
            field_name: field_name,
            negative: !minus.nil?,
            quoted: !quoted_term.nil?,
            filter: @filterable_fields.include?(field_name),
            term: term,
            token_string: token_string,
          )
          token.options = @matchable_options if token.is_a?(MatchableToken)
          token.default_fields = @default_fields if token.is_a?(MatchableToken)
          token.field_mapping = @field_mapping if token.is_a?(MatchableToken)
          token.time_zone = @time_zone if token.is_a?(DateToken)
          token
        end
      end

      private

      def aggregate_all_fields
        fields = [
          @date_fields,
          @default_fields,
          @downcased_fields,
          @filterable_fields,
          @hierarchal_fields,
          @int_fields,
          @field_mapping.keys
        ].flatten.compact

        fields.map { |field| field.sub(/\^\d+\z/, "") }.uniq
      end

      def token_class(field_name)
        case
        when @date_fields.include?(field_name)
          DateToken
        when @int_fields.include?(field_name)
          IntToken
        when @hierarchal_fields.include?(field_name)
          HierarchalToken
        when @filterable_fields.include?(field_name)
          FilterableToken
        else
          MatchableToken
        end
      end
    end
  end
end
