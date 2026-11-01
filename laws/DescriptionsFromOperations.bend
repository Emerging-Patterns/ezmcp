# `oas/v3.1.0#operation-object`: summary is "A short summary of what the
# operation does", description "A verbose explanation of the operation
# behavior". A tool's description is the operation's `description` when that
# is a non-empty string, else its `summary` when that is, else `Executes
# <METHOD> <path>`, the method in upper case (openapi-mcp-generator's)
import Base
import ../src/openapi.bend as Openapi

# LAW: a non-empty description is the tool's
law oas_describe_desc:
  for +desc: String
  for summary: Maybe<&2, String>
  for +method: String
  for path: String
  for e: {String.is_empty(desc) == False{} : Bool}
  {Openapi.describe(Some{desc}, summary, method, path) == desc : String}

# LAW: else a non-empty summary is
law oas_describe_summary:
  for +summary: String
  for +method: String
  for path: String
  for e: {String.is_empty(summary) == False{} : Bool}
  {Openapi.describe(None{}, Some{summary}, method, path) == summary : String}

# LAW: else the method and path it runs are
law oas_describe_none:
  for +method: String
  for path: String
  {Openapi.describe(None{}, None{}, method, path)
    == "Executes " ++ String.to_upper(method) ++ " " ++ path : String}
