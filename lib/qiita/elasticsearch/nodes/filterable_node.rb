require "qiita/elasticsearch/nodes/filter_node"
require "qiita/elasticsearch/nodes/query_node"

module Qiita
  module Elasticsearch
    module Nodes
      class FilterableNode
        # @param [Array<Qiita::Elasticsearch::Tokens>] tokens
        def initialize(tokens)
          @tokens = tokens
        end

        def to_hash
          if filter_tokens.empty?
            QueryNode.new(not_filter_tokens).to_hash
          else
            {
              "bool" => {
                "filter" => FilterNode.new(filter_tokens).to_hash,
                "must" => QueryNode.new(not_filter_tokens).to_hash,
              }.reject do |_key, value|
                value.empty?
              end,
            }
          end
        end

        private

        def filter_tokens
          @filter_tokens ||= @tokens.select(&:filter?)
        end

        def not_filter_tokens
          @not_filter_tokens ||= @tokens.reject(&:filter?)
        end
      end
    end
  end
end
