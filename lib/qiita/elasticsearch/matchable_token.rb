require "qiita/elasticsearch/token"

module Qiita
  module Elasticsearch
    class MatchableToken < Token
      RELATIVE_BEST_FIELDS_QUERY_WEIGHT = 0.5

      attr_writer :default_fields
      attr_accessor :exact_match_fields
      attr_accessor :field_mapping

      # @return [Hash]
      def to_hash
        if quoted?
          build_multi_match_query(type: "phrase")
        else
          {
            "bool" => {
              "should" => [
                build_multi_match_query(type: "phrase"),
                build_multi_match_query(type: "best_fields", boost: RELATIVE_BEST_FIELDS_QUERY_WEIGHT),
              ],
            },
          }
        end
      end

      private

      # @return [Hash]
      def build_multi_match_query(type: nil, boost: 1)
        { "multi_match" => build_query(boost, type) }
      end

      def build_query(boost, type)
        query = {
          "boost" => boost,
          "fields" => matchable_fields(type),
          "query" => @term,
          "type" => type,
        }
        query.merge!(options)
      end

      def matchable_fields(type)
        type == "phrase" ? matchable_phrase_query_fields : target_non_phrase_query_fields
      end

      def matchable_phrase_query_fields
        if field_name
          target_fields_for_phrase_query
        elsif exact_match_fields && !exact_match_fields.empty?
          exact_match_fields
        else
          default_query_fields
        end
      end

      def target_non_phrase_query_fields
        if field_name
          target_fields_for_non_phrase_query
        else
          default_query_fields
        end
      end

      def default_query_fields
        if @default_fields && !@default_fields.empty?
          @default_fields
        else
          ["_all"]
        end
      end

      def target_fields_for_phrase_query
        if !field_mapping.key?(field_name)
          @target_fields_for_phrase_query ||= [field_name]
        elsif exact_match_fields.empty?
          @target_fields_for_phrase_query ||= Array(field_mapping[field_name])
        else
          @target_fields_for_phrase_query ||= generate_exact_match_fields
        end
      end

      def target_fields_for_non_phrase_query
        @target_fields ||= field_aliases.empty? ? [field_name] : field_aliases
      end

      def field_aliases
        @field_aliases ||= field_mapping.key?(field_name) ? Array(field_mapping[field_name]) : [field_name]
      end

      def generate_exact_match_fields
        exact_match_field_names = exact_match_fields.map { |field| field.gsub(/^(.+)\^.+$/, '\1') }
        Array(field_mapping[field_name]).select do |field|
          field if exact_match_field_names.include?(field.gsub(/^(.+)\^.+$/, '\1'))
        end
      end
    end
  end
end
