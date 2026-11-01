# `oas/v3.1.0#request-body-object`: content is "REQUIRED. The content of the
# request body. The key is a media type or media type range"; required
# "Determines if the request body is required in the request. Defaults to
# false". A request body's media type is `application/json` when its content
# has a schema (an object or `true`) for it, else its content's first media
# type (openapi-mcp-generator's). With `application/json` the input property
# `requestBody` is that schema (laws/SchemasMappedToJsonSchema.bend),
# described by the body's `description`, else the schema's, else "The JSON
# request body."; with another media type it is a string schema, described
# by the body's `description`, else "Request body (content type: <type>)";
# it is required when the body's `required` is `true`. A body with no media
# type adds nothing. The input schema is an object schema of the properties
# in order, with `required` only when a name is required
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/openapi.bend as Openapi

# LAW: a body with a schema for application/json is sent as JSON
law oas_media_json:
  for +content: Value.Json
  for e: {Openapi.schema.ok(Json.get(Json.get(content, "application/json"),
    "schema")) == True{} : Bool}
  {Openapi.media(content) == "application/json" : String}

# LAW: else as its first media type
law oas_media_other:
  for +content: Value.Json
  for e: {Openapi.schema.ok(Json.get(Json.get(content, "application/json"),
    "schema")) == False{} : Bool}
  {Openapi.media(content) == Openapi.media.first(Openapi.members(content))
    : String}

# LAW: a body with no media type adds nothing
law oas_body_none:
  for rb: Value.Json
  for st: Openapi.In
  {Openapi.input.body(rb, "", st) == st : Openapi.In}

# LAW: a JSON body is its schema, described, required when the body is
law oas_body_json:
  for +rb: Value.Json
  for props: List<&2, Openapi.Mem()>
  for req: List<&2, String>
  {Openapi.input.body(rb, "application/json", Openapi.In{props, req})
    == Openapi.In{Openapi.put(props, "requestBody", Openapi.body.json(rb)),
      Openapi.need(req, "requestBody", Openapi.is_true(Json.get(rb,
      "required")))} : Openapi.In}

# LAW: any other body is a string
law oas_body_text:
  for +rb: Value.Json
  for +mt: String
  for props: List<&2, Openapi.Mem()>
  for req: List<&2, String>
  for none: {String.is_empty(mt) == False{} : Bool}
  for json: {String.eq(mt, "application/json") == False{} : Bool}
  {Openapi.input.body(rb, mt, Openapi.In{props, req})
    == Openapi.In{Openapi.put(props, "requestBody", Openapi.body.text(rb, mt)),
      Openapi.need(req, "requestBody", Openapi.is_true(Json.get(rb,
      "required")))} : Openapi.In}

# LAW: the input schema is an object schema of the properties
law oas_input:
  for props: List<&2, Openapi.Mem()>
  for req: List<&2, String>
  {Openapi.input.of(Openapi.In{props, req})
    == Openapi.object(List.append(&2, Openapi.Mem(), [("type", Json.str(
      "object")), ("properties", Openapi.object(props))], Openapi.required(req)))
    : Value.Json}

# LAW: with no required name there is no `required`
law oas_required_none:
  for req: List<&2, String>
  for e: {List.is_empty(&2, String, req) == True{} : Bool}
  {Openapi.required(req) == [] : List<&2, Openapi.Mem()>}

# LAW: else `required` lists them
law oas_required_some:
  for one: String
  for rest: List<&2, String>
  {Openapi.required(one <> rest)
    == [("required", Json.arr(Openapi.strs(one <> rest)))]
    : List<&2, Openapi.Mem()>}
