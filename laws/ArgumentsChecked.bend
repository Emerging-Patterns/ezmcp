# `server/tools#error-handling` (2025-03-26 and 2025-06-18): "Protocol
# Errors: Standard JSON-RPC errors for issues like ... Invalid arguments";
# `server/tools#security-considerations`: servers "MUST: Validate all tool
# inputs". `check` answers None for arguments that fit the input schema one
# level deep, else `Invalid arguments for tool '<name>': ` and what is
# wrong: the first name of `required` the arguments lack (`<name>:
# Required`), else the first property whose argument is there and is not of
# its schema's `type` (a type name, or one of an array of names, `integer` a
# number whose text is an integer), or of none of its `anyOf` alternatives'
# types, or none of its `enum` values; a schema with no `type` takes any
# value. The runner refuses such a call (laws/RefusedCallsAnswerErrors.bend)
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/openapi.bend as Openapi

# LAW: a call's arguments are checked for a missing name, then a bad value
law oas_check:
  for +name: String
  for description: String
  for +input: Value.Json
  for method: String
  for path: String
  for params: List<&2, Openapi.Param>
  for media: String
  for +args: Value.Json
  {Openapi.check(Openapi.Op{name, description, input, method, path, params,
    media}, args) == Openapi.check.of(name, Openapi.first(Openapi.missing(
    Json.items(Json.get(input, "required")), args), Openapi.bad(Openapi.members(
    Json.get(input, "properties")), args))) : Maybe<&2, String>}

# LAW: nothing wrong is none
law oas_check_ok:
  for name: String
  {Openapi.check.of(name, None{}) == None{} : Maybe<&2, String>}

# LAW: else what is wrong, for the tool
law oas_check_why:
  for name: String
  for why: String
  {Openapi.check.of(name, Some{why})
    == Some{"Invalid arguments for tool '" ++ name ++ "': " ++ why}
    : Maybe<&2, String>}

# LAW: no required names lack none
law oas_missing_none:
  for +args: Value.Json
  {Openapi.missing([], args) == None{} : Maybe<&2, String>}

# LAW: a required name the arguments lack is required
law oas_missing_hit:
  for +name: String
  for rest: List<&2, Value.Json>
  for +args: Value.Json
  for e: {Json.has(args, name) == False{} : Bool}
  {Openapi.missing(Value.JStr{name} <> rest, args) == Some{name ++ ": Required"}
    : Maybe<&2, String>}

# LAW: a schema with no type takes any value
law oas_typed_any:
  for +val: Value.Json
  {Openapi.typed(Value.JNull{}, val) == True{} : Bool}

# LAW: a string is of type string
law oas_kind_string:
  for str: String
  {Openapi.kind("string", Value.JStr{str}) == True{} : Bool}

# LAW: a number is of type number
law oas_kind_number_text:
  for raw: String
  {Openapi.kind("number", Value.JNum{raw}) == True{} : Bool}
