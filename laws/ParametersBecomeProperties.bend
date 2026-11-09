# `oas/v3.1.0#parameter-object`: name is "REQUIRED. The name of the
# parameter"; required "Determines whether this parameter is mandatory. If
# the parameter location is "path", this property is REQUIRED and its value
# MUST be true"; schema is "The schema defining the type used for the
# parameter". A parameter whose `name` is a non-empty string and whose
# `schema` is an object or `true` is the input property of that name
# (laws/SchemasMappedToJsonSchema.bend's schema; its `description` the
# parameter's when that is a non-empty string, in its place or last), set in
# the place of a property of that name or last, and its name is added last
# to `required` when its `required` is `true`; any other parameter adds
# nothing. A schema with a description to set that is not an object is left
# as it is
import Base
import ezjson@1.2.0.0/main.bend as Json
import ezjson@1.2.0.0/src/value.bend as Value
import ../src/openapi.bend as Openapi

# LAW: a named parameter with a schema is the property of its name
law oas_param_put:
  for +name: String
  for +one: Value.Json
  for props: List<&2, Openapi.Mem()>
  for req: List<&2, String>
  {Openapi.input.param.of(Some{name}, True{}, one, Openapi.In{props, req})
    == Openapi.In{Openapi.put(props, name, Openapi.described(Openapi.schema(
      Json.get(one, "schema")), Openapi.full(Json.as_str(Json.get(one,
      "description"))))), Openapi.need(req, name, Openapi.is_true(Json.get(one,
      "required")))} : Openapi.In}

# LAW: a parameter with no name adds nothing
law oas_param_unnamed:
  for ok: Bool
  for one: Value.Json
  for st: Openapi.In
  {Openapi.input.param.of(None{}, ok, one, st) == st : Openapi.In}

# LAW: nor does one with no schema
law oas_param_unschemed:
  for name: Maybe<&2, String>
  for one: Value.Json
  for st: Openapi.In
  {Openapi.input.param.of(name, False{}, one, st) == st : Openapi.In}

# LAW: a required name is added last
law oas_need:
  for req: List<&2, String>
  for name: String
  {Openapi.need(req, name, True{}) == List.append(&2, String, req, [name])
    : List<&2, String>}

# LAW: any other is not
law oas_need_not:
  for req: List<&2, String>
  for name: String
  {Openapi.need(req, name, False{}) == req : List<&2, String>}

# LAW: a member none has goes last
law oas_put_last:
  for key: String
  for val: Value.Json
  {Openapi.put([], key, val) == [(key, val)] : List<&2, Openapi.Mem()>}

# LAW: a member takes the place of the first of its name
law oas_put_hit:
  for +k2: String
  for v2: Value.Json
  for rest: List<&2, Openapi.Mem()>
  for +key: String
  for +val: Value.Json
  for e: {String.eq(k2, key) == True{} : Bool}
  {Openapi.put((k2, v2) <> rest, key, val) == (key, val) <> rest
    : List<&2, Openapi.Mem()>}

# LAW: and passes one of another name
law oas_put_miss:
  for +k2: String
  for v2: Value.Json
  for +rest: List<&2, Openapi.Mem()>
  for +key: String
  for +val: Value.Json
  for e: {String.eq(k2, key) == False{} : Bool}
  {Openapi.put((k2, v2) <> rest, key, val) == (k2, v2) <> Openapi.put(rest,
    key, val) : List<&2, Openapi.Mem()>}

# LAW: an object schema takes the description
law oas_described:
  for +cs: Value.Json
  for desc: String
  {Openapi.described(Value.JObj{cs}, Some{desc})
    == Openapi.object(Openapi.put(Openapi.members(Value.JObj{cs}),
      "description", Json.str(desc))) : Value.Json}

# LAW: no description leaves a schema as it is
law oas_described_none:
  for val: Value.Json
  {Openapi.described(val, None{}) == val : Value.Json}
