# `oas/v3.1.0#path-templating`: "template expressions, delimited by curly
# braces ({}), to mark a section of a URL path as replaceable using path
# parameters"; `#parameter-locations`: path "the parameter value is actually
# part of the operation's URL", query "Parameters that are appended to the
# URL", header "Custom headers that are expected as part of the request";
# `#parameter-object`, style defaults "query - form; path - simple; header -
# simple", explode "When style is form, the default value is true". A call's
# request is built from each parameter whose argument is there and not null,
# in order: a path parameter's first `{name}` is replaced by its value's
# text percent-encoded as a path segment (ezhttp's `quote_component`); a
# query parameter adds `name=text`, an array one such pair for each item
# that is not null; a header parameter is a header field of its name in
# lower case and its text; a cookie parameter is not sent. A value's text is
# a string itself, a number its text, a boolean `true` or `false`, an array
# its items' texts joined by `,`, anything else its JSON. The target is the
# path, then `?` and the pairs form-encoded when there are any; the header
# fields are `Accept: application/json`, the header parameters', and
# `Content-Type` of the media type when there is a body; the body is the
# `requestBody` argument, when the operation has one and the argument is
# there and not null: its JSON for `application/json`, else a string as
# itself. A path that still holds a `{` is `Unfilled`
import Base
import ezjson@1.2.0.0/main.bend as Json
import ezjson@1.2.0.0/src/value.bend as Value
import ezhttp@0.23.0.0/src/http.bend as Http
import ezhttp@0.23.0.0/src/qs.bend as Qs
import ../src/openapi.bend as Openapi

# LAW: a call is its parameters put in the request, and its body
law oas_call:
  for name: String
  for description: String
  for input: Value.Json
  for method: String
  for +path: String
  for params: List<&2, Openapi.Param>
  for +mt: String
  for +args: Value.Json
  {Openapi.call(Openapi.Op{name, description, input, method, path, params, mt},
    args) == Openapi.call.of(method, mt, Openapi.body.arg(String.is_empty(mt),
    mt, args), Openapi.req.params(params, args, Openapi.Req{path, [], []}))
    : Openapi.Call}

# LAW: a path parameter is filled into the path
law oas_req_path:
  for +name: String
  for val: Value.Json
  for path: String
  for pairs: List<&2, Qs.Kv()>
  for hs: List<&2, Http.Header>
  {Openapi.req.put(Openapi.InPath{}, name, val, Openapi.Req{path, pairs, hs})
    == Openapi.Req{Openapi.fill(path, name, val), pairs, hs} : Openapi.Req}

# LAW: a query parameter's pairs are added to the query
law oas_req_query:
  for +name: String
  for val: Value.Json
  for path: String
  for pairs: List<&2, Qs.Kv()>
  for hs: List<&2, Http.Header>
  {Openapi.req.put(Openapi.InQuery{}, name, val, Openapi.Req{path, pairs, hs})
    == Openapi.Req{path, List.append(&2, Qs.Kv(), pairs, Openapi.query(name,
      val)), hs} : Openapi.Req}

# LAW: a header parameter is a header field of its name in lower case
law oas_req_header:
  for +name: String
  for val: Value.Json
  for path: String
  for pairs: List<&2, Qs.Kv()>
  for hs: List<&2, Http.Header>
  {Openapi.req.put(Openapi.InHeader{}, name, val, Openapi.Req{path, pairs, hs})
    == Openapi.Req{path, pairs, List.append(&2, Http.Header, hs,
      [Http.H{String.to_lower(name), Openapi.plain(val)}])} : Openapi.Req}

# LAW: a cookie parameter changes nothing
law oas_req_cookie:
  for +name: String
  for val: Value.Json
  for path: String
  for pairs: List<&2, Qs.Kv()>
  for hs: List<&2, Http.Header>
  {Openapi.req.put(Openapi.InCookie{}, name, val, Openapi.Req{path, pairs, hs})
    == Openapi.Req{path, pairs, hs} : Openapi.Req}

# LAW: nor does a parameter with no argument
law oas_req_absent:
  for place: Openapi.Place
  for +name: String
  for sofar: Openapi.Req
  {Openapi.req.arg(None{}, place, name, sofar) == sofar : Openapi.Req}

# LAW: an argument that is not there is none
law oas_arg_absent:
  for +args: Value.Json
  for +name: String
  for e: {Json.has(args, name) == False{} : Bool}
  {Openapi.arg(args, name) == None{} : Maybe<&2, Value.Json>}

# LAW: nor is a null one
law oas_arg_null:
  for +args: Value.Json
  for +name: String
  for eh: {Json.has(args, name) == True{} : Bool}
  for en: {Json.get(args, name) == Value.JNull{} : Value.Json}
  {Openapi.arg(args, name) == None{} : Maybe<&2, Value.Json>}

# LAW: an array query parameter is a pair for each item
law oas_query_array:
  for +name: String
  for +cs: Value.Json
  {Openapi.query(name, Value.JArr{cs})
    == Openapi.query.items(name, Json.items(Value.JArr{cs}))
    : List<&2, Qs.Kv()>}

# LAW: but a null item
law oas_query_null:
  for +name: String
  for rest: List<&2, Value.Json>
  {Openapi.query.items(name, Value.JNull{} <> rest)
    == Openapi.query.items(name, rest) : List<&2, Qs.Kv()>}

# LAW: a string query parameter is one pair of it
law oas_query_str:
  for +name: String
  for str: String
  {Openapi.query(name, Value.JStr{str}) == [(name, str)] : List<&2, Qs.Kv()>}

# LAW: a number's text is its text
law oas_plain_num:
  for raw: String
  {Openapi.plain(Value.JNum{raw}) == raw : String}

# LAW: a path still holding a template expression is unfilled
law oas_unfilled:
  for method: String
  for +mt: String
  for +body: Maybe<&2, String>
  for +path: String
  for pairs: List<&2, Qs.Kv()>
  for hs: List<&2, Http.Header>
  for e: {String.contains(path, "{") == True{} : Bool}
  {Openapi.call.of(method, mt, body, Openapi.Req{path, pairs, hs})
    == Openapi.Unfilled{path} : Openapi.Call}

# LAW: else the request is sent, with its header fields in order
law oas_send:
  for method: String
  for +mt: String
  for +body: Maybe<&2, String>
  for +path: String
  for pairs: List<&2, Qs.Kv()>
  for hs: List<&2, Http.Header>
  for e: {String.contains(path, "{") == False{} : Bool}
  {Openapi.call.of(method, mt, body, Openapi.Req{path, pairs, hs})
    == Openapi.Send{method, path ++ Openapi.query.text(pairs), List.append(&2,
      Http.Header, Http.H{"Accept", "application/json"} <> hs, Openapi.ctype(mt,
      body)), body} : Openapi.Call}

# LAW: no pairs is no query string
law oas_query_text_none:
  for pairs: List<&2, Qs.Kv()>
  for e: {List.is_empty(&2, Qs.Kv(), pairs) == True{} : Bool}
  {Openapi.query.text(pairs) == "" : String}

# LAW: an operation with no body sends none
law oas_body_absent:
  for +mt: String
  for +args: Value.Json
  {Openapi.body.arg(True{}, mt, args) == None{} : Maybe<&2, String>}

# LAW: a JSON body is its JSON
law oas_body_sent:
  for val: Value.Json
  {Openapi.body.of("application/json", Some{val}) == Some{Json.print(val)}
    : Maybe<&2, String>}

# LAW: no body names no media type
law oas_ctype_none:
  for +mt: String
  {Openapi.ctype(mt, None{}) == [] : List<&2, Http.Header>}

# LAW: a body names its media type
law oas_ctype_body:
  for +mt: String
  for body: String
  {Openapi.ctype(mt, Some{body}) == [Http.H{"Content-Type", mt}]
    : List<&2, Http.Header>}
