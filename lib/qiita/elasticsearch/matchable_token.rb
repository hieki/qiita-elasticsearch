require "qiita/elasticsearch/token"

module Qiita
  module Elasticsearch
    class MatchableToken < Token
      RELATIVE_BEST_FIELDS_QUERY_WEIGHT = 0.5

      attr_writer :default_fields
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
          "fields" => matchable_fields,
          "query" => @term,
          "type" => type,
        }
        query.merge!(options)
      end

      def matchable_fields
        if field_name
          target_fields
        elsif @default_fields && !@default_fields.empty?
          @default_fields
        else
          ["_all"]
        end
      end

      def target_fields
        @target_fields ||= field_aliases.empty? ? [field_name] : field_aliases
      end

      def field_aliases
        @field_aliases ||= Array(field_mapping[field_name])
      end
    end
  end
end
