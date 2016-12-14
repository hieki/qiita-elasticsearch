require "qiita/elasticsearch/query_builder"

RSpec.describe Qiita::Elasticsearch::QueryBuilder do
  include Qiita::Elasticsearch::SpecHelper

  describe "#build" do
    let(:all_fields) do
    end

    let(:downcased_fields) do
    end

    let(:filterable_fields) do
    end

    let(:hierarchal_fields) do
    end

    let(:default_fields) do
    end

    let(:int_fields) do
    end

    let(:date_fields) do
    end

    let(:time_zone) do
    end

    let(:matchable_options) do
    end

    let(:field_mapping) do
    end

    let(:properties) do
      {
        all_fields: all_fields,
        date_fields: date_fields,
        default_fields: default_fields,
        downcased_fields: downcased_fields,
        field_mapping: field_mapping,
        filterable_fields: filterable_fields,
        hierarchal_fields: hierarchal_fields,
        int_fields: int_fields,
        matchable_options: matchable_options,
        time_zone: time_zone,
      }
    end

    let(:query) do
      query_builder.build(query_string)
    end

    let(:query_builder) do
      described_class.new(properties)
    end

    shared_examples_for "returns query to match anything" do
      it "returns query to match anything" do
        expect(query.to_hash).to eq(
          "query" => {
            "match_all" => {},
          },
          "sort" => [
            { "created_at" => "desc" },
            "_score",
          ],
        )
      end
    end

    context "with empty string" do
      let(:query_string) do
        ""
      end

      include_examples "returns query to match anything"
    end

    context "with no token" do
      let(:query_string) do
        " "
      end

      it "returns null query" do
        expect(query.to_hash).to eq query_builder.build("").to_hash
      end
    end

    context "with positive token" do
      let(:query_string) do
        "a"
      end

      it "returns combined match query" do
        expect(query.query.to_hash).to eq(build_combined_match_query(query: "a"))
      end
    end

    context "with matchable option" do
      let(:matchable_options) do
        {
          "operator" =>  "and"
        }
      end

      let(:query_string) do
        "a"
      end

      it "returns query with specified matchable option" do
        expect(query.query.to_hash).to eq(
          "bool" => {
            "should" => [
              {
                "multi_match" => {
                  "boost" => 1,
                  "fields" => ["_all"],
                  "query" => "a",
                  "type" => "phrase",
                  "operator" => "and"
                }
              },
              {
                "multi_match" => {
                  "boost" => 0.5,
                  "fields" => ["_all"],
                  "query" => "a",
                  "type" => "best_fields",
                  "operator" => "and"
                }
              }
            ]
          }
        )
      end
    end

    context "with double-quoted positive token" do
      let(:query_string) do
        '"a b"'
      end

      it "returns multi match query with phrase type" do
        expect(query.query.to_hash).to eq(
          "multi_match" => {
            "boost" => 1,
            "fields" => ["_all"],
            "query" => "a b",
            "type" => "phrase",
          },
        )
      end
    end

    context "with double-quoted negative token" do
      let(:query_string) do
        '-"a b"'
      end

      it "returns must_not query with phrase multi match query" do
        expect(query.query.to_hash).to eq(
          "filtered" => {
            "filter" => {
              "bool" => {
                "_cache" => true,
                "must_not" => [
                  {
                    "query" => {
                      "multi_match" => {
                        "boost" => 1,
                        "fields" => ["_all"],
                        "query" => "a b",
                        "type" => "phrase",
                      },
                    },
                  },
                ],
              },
            },
          },
        )
      end
    end

    context "with double-quoted token with default field names" do
      let(:default_fields) do
        ["title"]
      end

      let(:query_string) do
        '"a b"'
      end

      it "returns multi match query with phrase type" do
        expect(query.query.to_hash).to eq(
          "multi_match" => {
            "boost" => 1,
            "fields" => default_fields,
            "query" => "a b",
            "type" => "phrase",
          },
        )
      end
    end

    context "with negative token" do
      let(:query_string) do
        "-a"
      end

      it "returns bool query with must_not property" do
        expect(query.query.to_hash).to eq(
          "filtered" => {
            "filter" => {
              "bool" => {
                "_cache" => true,
                "must_not" => [
                  "query" => build_combined_match_query(query: "a"),
                ],
              },
            },
          },
        )
      end
    end

    context "with multiple positive tokens" do
      let(:query_string) do
        "a b"
      end

      it "returns AND query" do
        expect(query.query.to_hash).to eq(
          "bool" => {
            "must" => [
              build_combined_match_query(query: "a"),
              build_combined_match_query(query: "b"),
            ],
          },
        )
      end
    end

    context "with positive token and negative token" do
      let(:query_string) do
        "a -b"
      end

      it "returns bool query with must_not and should properties" do
        expect(query.query.to_hash).to eq(
          "filtered" => {
            "filter" => {
              "bool" => {
                "_cache" => true,
                "must_not" => [
                  "query" => build_combined_match_query(query: "b"),
                ],
              },
            },
            "query" => build_combined_match_query(query: "a"),
          },
        )
      end
    end

    context "with default_fields property" do
      let(:default_fields) do
        ["tag"]
      end

      let(:query_string) do
        "a"
      end

      it "returns multi_match query with phrase type" do
        expect(query.query.to_hash).to eq(build_combined_match_query(fields: default_fields, query: "a"))
      end
    end

    context "with filterable_fields property and token including field name" do
      let(:filterable_fields) do
        ["tag"]
      end

      let(:query_string) do
        "tag:a"
      end

      it "returns filtered query" do
        expect(query.query.to_hash).to eq(
          "filtered" => {
            "filter" => {
              "term" => {
                "tag" => "a",
              },
            },
          },
        )
      end
    end

    context "with token including non-filterable field name" do
      let(:query_string) do
        "title:foo"
      end

      context "and the field exists in all_fields" do
        let(:all_fields) do
          ["title"]
        end

        context "without field mapping" do
          it "returns match query for the field" do
            expect(query.query.to_hash).to eq(build_combined_match_query(fields: ["title"], query: "foo"))
          end
        end

        context "with field mapping for multiple aliases" do
          let(:field_mapping) do
            {
              "title" =>  ["title", "title.ngram"]
            }
          end

          it "returns match query for the corresponding field aliases" do
            expect(query.query.to_hash).to eq(build_combined_match_query(fields: ["title", "title.ngram"], query: "foo"))
          end
        end

        context "with field mapping for a single alias" do
          let(:field_mapping) do
            {
              "title" =>  "title.ngram"
            }
          end

          it "returns match query for the corresponding field aliases" do
            expect(query.query.to_hash).to eq(build_combined_match_query(fields: ["title.ngram"], query: "foo"))
          end
        end
      end

      context "and the field does not exist in all_fields" do
        let(:all_fields) do
          []
        end

        context "without field mapping" do
          it "returns match query for _all fields" do
            expect(query.query.to_hash).to eq(build_combined_match_query(fields: ["_all"], query: "title:foo"))
          end
        end

        context "with field mapping" do
          let(:field_mapping) do
            {
              "title" =>  ["title", "title.ngram"]
            }
          end

          it "returns match query for _all fields" do
            expect(query.query.to_hash).to eq(build_combined_match_query(fields: ["_all"], query: "title:foo"))
          end
        end
      end

      context "and all_fields is omitted" do
        let(:all_fields) do
        end

        context "without field mapping" do
          it "returns match query for _all fields" do
            expect(query.query.to_hash).to eq(build_combined_match_query(fields: ["_all"], query: "title:foo"))
          end
        end

        context "with field mapping" do
          let(:field_mapping) do
            {
              "title" =>  ["title", "title.ngram"]
            }
          end

          it "returns match query for the corresponding field aliases" do
            expect(query.query.to_hash).to eq(build_combined_match_query(fields: ["title", "title.ngram"], query: "foo"))
          end
        end
      end
    end

    context "with code filter" do
      let(:filterable_fields) do
        ["code"]
      end

      let(:query_string) do
        'code:"Foo::Bar"'
      end

      it "returns phrase match query" do
        expect(query.query.to_hash).to eq(
          "filtered" => {
            "filter" => {
              "query" => {
                "match_phrase" => {
                  "code" => "foo::bar",
                },
              },
            },
          },
        )
      end
    end

    context "with upcased field name" do
      let(:filterable_fields) do
        ["tag"]
      end

      let(:query_string) do
        "tag:A"
      end

      it "returns filtered query for upcased field name" do
        expect(query.query.to_hash).to eq(
          "filtered" => {
            "filter" => {
              "term" => {
                "tag" => "A",
              },
            },
          },
        )
      end
    end

    context "with downcased field name with downcased_fields option" do
      let(:downcased_fields) do
        ["tag"]
      end

      let(:filterable_fields) do
        ["tag"]
      end

      let(:query_string) do
        "tag:A"
      end

      it "returns filtered query for downcased field name" do
        expect(query.query.to_hash).to eq(
          "filtered" => {
            "filter" => {
              "term" => {
                "tag" => "a",
              },
            },
          },
        )
      end
    end

    context "with multiple field-named tokens" do
      let(:filterable_fields) do
        ["tag"]
      end

      let(:query_string) do
        "tag:a tag:b"
      end

      it "returns filtered query" do
        expect(query.query.to_hash).to eq(
          "filtered" => {
            "filter" => {
              "bool" => {
                "_cache" => true,
                "must" => [
                  {
                    "term" => {
                      "tag" => "a",
                    },
                  },
                  {
                    "term" => {
                      "tag" => "b",
                    },
                  },
                ],
              },
            },
          },
        )
      end
    end

    context "with escaped colon" do
      let(:filterable_fields) do
        ["tag"]
      end

      let(:query_string) do
        'tag\:a'
      end

      it "returns match query" do
        expect(query.query.to_hash).to eq(build_combined_match_query(query: 'tag\:a'))
      end
    end

    context "with token including unknown field name" do
      let(:query_string) do
        "tag:a"
      end

      it "returns match query" do
        expect(query.query.to_hash).to eq(build_combined_match_query(query: "tag:a"))
      end
    end

    context "with token including field name and minus" do
      let(:filterable_fields) do
        ["tag"]
      end

      let(:query_string) do
        "-tag:a"
      end

      it "returns filtered query with bool filter" do
        expect(query.query.to_hash).to eq(
          "filtered" => {
            "filter" => {
              "bool" => {
                "_cache" => true,
                "must_not" => [
                  {
                    "term" => {
                      "tag" => "a",
                    },
                  },
                ],
              },
            },
          },
        )
      end
    end

    context "with normal token and another token including known field name" do
      let(:filterable_fields) do
        ["tag"]
      end

      let(:query_string) do
        "a tag:b"
      end

      it "returns bool query with must and should properties" do
        expect(query.query.to_hash).to eq(
          "filtered" => {
            "filter" => {
              "term" => {
                "tag" => "b",
              },
            },
            "query" => build_combined_match_query(query: "a"),
          },
        )
      end
    end

    context "with tokens connected with OR token" do
      let(:query_string) do
        "a OR b"
      end

      it "returns bool query with should property" do
        expect(query.query.to_hash).to eq(
          "bool" => {
            "should" => [
              build_combined_match_query(query: "a"),
              build_combined_match_query(query: "b"),
            ],
          },
        )
      end
    end

    context "with only OR token" do
      let(:query_string) do
        "OR"
      end

      it "returns null query" do
        expect(query.to_hash).to eq query_builder.build("").to_hash
      end
    end

    context "with malformed OR token" do
      let(:query_string) do
        "OR a"
      end

      it "returns same query without OR token" do
        expect(query.to_hash).to eq query_builder.build("a").to_hash
      end
    end

    context "with downcased OR token" do
      let(:query_string) do
        "a or b"
      end

      it "treats both or and OR as OR token" do
        expect(query.to_hash).to eq query_builder.build("a OR b").to_hash
      end
    end

    context "with hierarchal field name" do
      let(:filterable_fields) do
        ["tag"]
      end

      let(:hierarchal_fields) do
        ["tag"]
      end

      let(:query_string) do
        "tag:a"
      end

      it "returns prefix query" do
        expect(query.query.to_hash).to eq(
          "filtered" => {
            "filter" => {
              "bool" => {
                "should" => [
                  {
                    "prefix" => {
                      "tag" => "a/",
                    },
                  },
                  {
                    "term" => {
                      "tag" => "a",
                    },
                  },
                ],
              },
            },
          },
        )
      end
    end

    context "with invalid int token" do
      let(:filterable_fields) do
        ["stocks"]
      end

      let(:int_fields) do
        ["stocks"]
      end

      let(:query_string) do
        "stocks:invalid"
      end

      it "returns null filtered query" do
        expect(query.query.to_hash).to eq(
          "filtered" => {
            "filter" => {
              "query" => {
                "ids" => {
                  "values" => [],
                },
              },
            },
          },
        )
      end
    end

    context "with negative invalid int token" do
      let(:filterable_fields) do
        ["stocks"]
      end

      let(:int_fields) do
        ["stocks"]
      end

      let(:query_string) do
        "-stocks:invalid"
      end

      include_examples "returns query to match anything"
    end

    context "with range field name" do
      let(:filterable_fields) do
        ["stocks"]
      end

      let(:int_fields) do
        ["stocks"]
      end

      context "and no range operand" do
        let(:query_string) do
          "stocks:100"
        end

        it "returns term filter" do
          expect(query.query.to_hash).to eq(
            "filtered" => {
              "filter" => {
                "term" => {
                  "stocks" => 100,
                },
              },
            },
          )
        end
      end

      context "and < operand" do
        let(:query_string) do
          "stocks:<100"
        end

        it "returns range filter" do
          expect(query.query.to_hash).to eq(
            "filtered" => {
              "filter" => {
                "range" => {
                  "stocks" => {
                    "lt" => 100,
                  },
                },
              },
            },
          )
        end
      end

      context "and > operand" do
        let(:query_string) do
          "stocks:>100"
        end

        it "returns range filter" do
          expect(query.query.to_hash).to eq(
            "filtered" => {
              "filter" => {
                "range" => {
                  "stocks" => {
                    "gt" => 100,
                  },
                },
              },
            },
          )
        end
      end

      context "and multiple operands" do
        let(:query_string) do
          "stocks:>=100 stocks:<=200"
        end

        it "returns two range filters within bool filter" do
          expect(query.query.to_hash).to eq(
            "filtered" => {
              "filter" => {
                "bool" => {
                  "_cache" => true,
                  "must" => [
                    {
                      "range" => {
                        "stocks" => {
                          "gte" => 100,
                        },
                      },
                    },
                    {
                      "range" => {
                        "stocks" => {
                          "lte" => 200,
                        },
                      },
                    },
                  ],
                },
              },
            },
          )
        end
      end
    end

    context "with invalid date token" do
      let(:query_string) do
        "created:invalid"
      end

      it "returns null filtered query" do
        expect(query.query.to_hash).to eq(
          "filtered" => {
            "filter" => {
              "query" => {
                "ids" => {
                  "values" => [],
                },
              },
            },
          },
        )
      end
    end

    context "with invalid date token and OR token" do
      let(:query_string) do
        "created:invalid OR Ruby"
      end

      it "returns query that matches Ruby" do
        expect(query.query.to_hash).to eq(
          "bool" => {
            "should" => [
              {
                "filtered" => {
                  "filter" => {
                    "query" => {
                      "ids" => {
                        "values" => [],
                      },
                    },
                  },
                },
              },
              build_combined_match_query(query: "Ruby"),
            ],
          },
        )
      end
    end

    context "with date field name" do
      context "and absolute date expression" do
        context "and no range operand" do
          context "and query is YYYY" do
            let(:query_string) do
              "created:2015"
            end

            it "returns range filter" do
              expect(query.query.to_hash).to eq(
                "filtered" => {
                  "filter" => {
                    "range" => {
                      "created_at" => {
                        "gte" => "2015-01-01",
                        "lt" => "2016-01-01"
                      }
                    },
                  },
                },
              )
            end
          end

          context "and query is YYYY-MM" do
            let(:query_string) do
              "created:2015-04"
            end

            it "returns range filter" do
              expect(query.query.to_hash).to eq(
                "filtered" => {
                  "filter" => {
                    "range" => {
                      "created_at" => {
                        "gte" => "2015-04-01",
                        "lt" => "2015-05-01"
                      }
                    },
                  },
                },
              )
            end
          end

          context "and query is YYYY-MM-DD" do
            let(:query_string) do
              "created:2015-04-17"
            end

            it "returns range filter" do
              expect(query.query.to_hash).to eq(
                "filtered" => {
                  "filter" => {
                    "range" => {
                      "created_at" => {
                        "gte" => "2015-04-17",
                        "lt" => "2015-04-18"
                      }
                    },
                  },
                },
              )
            end
          end

          context "and time_zone" do
            let(:time_zone) do
              "+09:00"
            end

            let(:query_string) do
              "created:2015-04-17"
            end

            it "returns range filter with time_zone" do
              expect(query.query.to_hash).to eq(
                "filtered" => {
                  "filter" => {
                    "range" => {
                      "created_at" => {
                        "gte" => "2015-04-17",
                        "lt" => "2015-04-18",
                        "time_zone" => time_zone,
                      }
                    },
                  },
                },
              )
            end
          end
        end

        context "and single operand" do
          let(:query_string) do
            "created:<2015-04"
          end

          it "returns range filter" do
            expect(query.query.to_hash).to eq(
              "filtered" => {
                "filter" => {
                  "range" => {
                    "created_at" => {
                      "lt" => "2015-04",
                    },
                  },
                },
              },
            )
          end

          context "and time_zone" do
            let(:time_zone) do
              "+09:00"
            end

            it "returns range filter with time_zone" do
              expect(query.query.to_hash).to eq(
                "filtered" => {
                  "filter" => {
                    "range" => {
                      "created_at" => {
                        "lt" => "2015-04",
                        "time_zone" => time_zone,
                      },
                    },
                  },
                },
              )
            end
          end
        end

        context "and multiple operands" do
          let(:query_string) do
            "created:>=2015-04-01 created:<=2015-04-17"
          end

          it "returns two range filters within bool filter" do
            expect(query.query.to_hash).to eq(
              "filtered" => {
                "filter" => {
                  "bool" => {
                    "_cache" => true,
                    "must" => [
                      {
                        "range" => {
                          "created_at" => {
                            "gte" => "2015-04-01",
                          },
                        },
                      },
                      {
                        "range" => {
                          "created_at" => {
                            "lte" => "2015-04-17",
                          },
                        },
                      },
                    ],
                  },
                },
              },
            )
          end
        end
      end

      context "and relative date expression" do
        context "and invalid type" do
          let(:query_string) do
            "created:-1h"
          end

          it "returns null filtered query" do
            expect(query.query.to_hash).to eq(
              "filtered" => {
                "filter" => {
                  "query" => {
                    "ids" => {
                      "values" => [],
                    },
                  },
                },
              },
            )
          end
        end

        context "and type without minus" do
          let(:query_string) do
            "created:1d"
          end

          it "returns null filtered query" do
            expect(query.query.to_hash).to eq(
              "filtered" => {
                "filter" => {
                  "query" => {
                    "ids" => {
                      "values" => [],
                    },
                  },
                },
              },
            )
          end
        end

        context "and abbreviated type" do
          context "and no range operand" do
            let(:query_string) do
              "created:-1d"
            end

            it "returns null filtered query" do
              expect(query.query.to_hash).to eq(
                "filtered" => {
                  "filter" => {
                    "query" => {
                      "ids" => {
                        "values" => [],
                      },
                    },
                  },
                },
              )
            end
          end

          context "and single operand" do
            let(:query_string) do
              "created:<-2d"
            end

            it "returns range filter" do
              expect(query.query.to_hash).to eq(
                "filtered" => {
                  "filter" => {
                    "range" => {
                      "created_at" => {
                        "lt" => "now-48h",
                      },
                    },
                  },
                },
              )
            end

            context "and time_zone" do
              let(:time_zone) do
                "+09:00"
              end

              it "return query ignoring time_zone" do
                expect(query.query.to_hash).to eq(
                  "filtered" => {
                    "filter" => {
                      "range" => {
                        "created_at" => {
                          "lt" => "now-48h",
                        },
                      },
                    },
                  },
                )
              end
            end
          end

          context "and multiple operands" do
            let(:query_string) do
              "created:>=-2d created:<=-1d"
            end

            it "returns two range filters within bool filter" do
              expect(query.query.to_hash).to eq(
                "filtered" => {
                  "filter" => {
                    "bool" => {
                      "_cache" => true,
                      "must" => [
                        {
                          "range" => {
                            "created_at" => {
                              "gte" => "now-48h",
                            },
                          },
                        },
                        {
                          "range" => {
                            "created_at" => {
                              "lte" => "now-24h",
                            },
                          },
                        },
                      ],
                    },
                  },
                },
              )
            end
          end
        end

        context "and expanted type" do
          context "and no range operand" do
            let(:query_string) do
              "created:-1day"
            end

            it "returns null filtered query" do
              expect(query.query.to_hash).to eq(
                "filtered" => {
                  "filter" => {
                    "query" => {
                      "ids" => {
                        "values" => [],
                      },
                    },
                  },
                },
              )
            end
          end

          context "and single operand" do
            let(:query_string) do
              "created:<-2days"
            end

            it "returns range filter" do
              expect(query.query.to_hash).to eq(
                "filtered" => {
                  "filter" => {
                    "range" => {
                      "created_at" => {
                        "lt" => "now-48h",
                      },
                    },
                  },
                },
              )
            end

            context "and time_zone" do
              let(:time_zone) do
                "+09:00"
              end

              it "return query ignoring time_zone" do
                expect(query.query.to_hash).to eq(
                  "filtered" => {
                    "filter" => {
                      "range" => {
                        "created_at" => {
                          "lt" => "now-48h",
                        },
                      },
                    },
                  },
                )
              end
            end
          end

          context "and multiple operands" do
            let(:query_string) do
              "created:>=-2days created:<=-1day"
            end

            it "returns two range filters within bool filter" do
              expect(query.query.to_hash).to eq(
                "filtered" => {
                  "filter" => {
                    "bool" => {
                      "_cache" => true,
                      "must" => [
                        {
                          "range" => {
                            "created_at" => {
                              "gte" => "now-48h",
                            },
                          },
                        },
                        {
                          "range" => {
                            "created_at" => {
                              "lte" => "now-24h",
                            },
                          },
                        },
                      ],
                    },
                  },
                },
              )
            end
          end
        end
      end
    end

    context "without sort token" do
      let(:query_string) do
        "Ruby"
      end

      it "returns default sort option" do
        expect(query.sort).to eq([{ "created_at" => "desc" }, "_score"])
      end
    end

    context "with sort:created-asc" do
      let(:query_string) do
        "sort:created-asc"
      end

      it "returns a Query object that has the specified sort option" do
        expect(query.sort).to eq(
          [
            {
              "created_at" => "asc",
            },
            "_score",
          ],
        )
      end
    end

    context "with sort:updated-asc" do
      let(:query_string) do
        "sort:updated-asc"
      end

      it "returns query to sort in updated order " do
        expect(query.sort).to eq(
          [
            {
              "updated_at" => "asc",
            },
            "_score",
          ],
        )
      end
    end

    context "with sort:updated-desc" do
      let(:query_string) do
        "sort:updated-desc"
      end

      it "returns query to sort in reverse updated order " do
        expect(query.sort).to eq(
          [
            {
              "updated_at" => "desc",
            },
            "_score",
          ],
        )
      end
    end

    context "with is:shared" do
      let(:query_string) do
        "is:coediting"
      end

      it "returns query to focus on shared articles" do
        expect(query.query).to eq(
          "filtered" => {
            "filter" => {
              "term" => {
                "edit_permission" => 2,
              },
            },
          },
        )
      end
    end

    context "with is:project" do
      let(:query_string) do
        "is:project"
      end

      it "returns query to focus on project type" do
        expect(query.query).to eq(
          "filtered" => {
            "filter" => {
              "type" => {
                "value" => "project",
              },
            },
          },
        )
      end
    end

    context "with -is:project" do
      let(:query_string) do
        "-is:project"
      end

      it "returns query to reject project type" do
        expect(query.query).to eq(
          "filtered" => {
            "filter" => {
              "bool" => {
                "_cache" => true,
                "must_not" => [
                  {
                    "type" => {
                      "value" => "project",
                    },
                  },
                ],
              },
            },
          },
        )
      end
    end

    context "with is:archived" do
      let(:query_string) do
        "is:archived"
      end

      it "returns query to select archived documents" do
        expect(query.query).to eq(
          "filtered" => {
            "filter" => {
              "term" => {
                "archived" => true,
              },
            },
          },
        )
      end
    end

    context "with -is:archived" do
      let(:query_string) do
        "-is:archived"
      end

      it "returns query to reject archived documents" do
        expect(query.query).to eq(
          "filtered" => {
            "filter" => {
              "bool" => {
                "_cache" => true,
                "must_not" => [
                  {
                    "term" => {
                      "archived" => true,
                    },
                  },
                ],
              },
            },
          },
        )
      end
    end

    context "with likes:>3" do
      let(:filterable_fields) do
        ["likes"]
      end

      let(:int_fields) do
        ["likes"]
      end

      let(:query_string) do
        "likes:>3"
      end

      it "returns query to filter by lgtms" do
        expect(query.query).to eq(
          "filtered" => {
            "filter" => {
              "range" => {
                "lgtms" => {
                  "gt" => 3,
                },
              },
            },
          },
        )
      end
    end

    context "with group:dev" do
      before do
        allow_any_instance_of(Qiita::Elasticsearch::FilterableToken).to receive(:group_ids)
          .and_return(dummy_group_ids)
      end

      let(:dummy_group_ids) do
        [1, 2, 3]
      end

      let(:filterable_fields) do
        ["group"]
      end

      let(:query_string) do
        "group:dev"
      end

      it "returns query to filter documents by their group_id values" do
        expect(query.query).to eq(
          "filtered" => {
            "filter" => {
              "terms" => {
                "execution" => "or",
                "group_id" => dummy_group_ids,
              },
            },
          },
        )
      end
    end
  end
end
