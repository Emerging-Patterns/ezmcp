# `oas/v3.0.3#schema-object`: nullable "A true value adds "null" to the
# allowed type specified by the type keyword, only if type is explicitly
# defined within the same Schema Object", and `nullable`, `example`, `xml`,
# `externalDocs`, `deprecated`, `readOnly` and `writeOnly` are OpenAPI's own
# fields; `server/tools#tool`: the input schema is JSON Schema. A Schema
# Object becomes an input schema member by member, in order: those seven
# fields are left out, `type` `integer` becomes `number`
# (openapi-mcp-generator's), `nullable` true makes an explicit `type` admit
# `null` (a name as an array of it and `"null"`, an array of names with
# `"null"` added when it lacks it), and every other member is kept as it is.
# When the `type` is `"object"` the properties' schemas are mapped the same
# way (a boolean schema kept, any other value left out), and when it is
# `"array"` the items' schema is
import Base
import ezjson@1.2.0.0/main.bend as Json
import ezjson@1.2.0.0/src/value.bend as Value
import ../src/openapi.bend as Openapi

# LAW: integer is number
law oas_number:
  for +typ: Value.Json
  for e: {Openapi.is_str(typ, "integer") == True{} : Bool}
  {Openapi.number(typ) == Json.str("number") : Value.Json}

# LAW: any other type is as it is
law oas_number_other:
  for +typ: Value.Json
  for e: {Openapi.is_str(typ, "integer") == False{} : Bool}
  {Openapi.number(typ) == typ : Value.Json}

# LAW: dropping from no members leaves none
law oas_drop_last:
  for key: String
  {Openapi.drop([], key) == [] : List<&2, Openapi.Mem()>}

# LAW: a member of the name is left out
law oas_drop_hit:
  for +k2: String
  for v2: Value.Json
  for rest: List<&2, Openapi.Mem()>
  for +key: String
  for e: {String.eq(k2, key) == True{} : Bool}
  {Openapi.drop((k2, v2) <> rest, key) == Openapi.drop(rest, key)
    : List<&2, Openapi.Mem()>}

# LAW: and any other kept, in order
law oas_drop_miss:
  for +k2: String
  for v2: Value.Json
  for rest: List<&2, Openapi.Mem()>
  for +key: String
  for e: {String.eq(k2, key) == False{} : Bool}
  {Openapi.drop((k2, v2) <> rest, key) == (k2, v2) <> Openapi.drop(rest, key)
    : List<&2, Openapi.Mem()>}

# LAW: a schema with no type keeps its members
law oas_typed_none:
  for ps: List<&2, Openapi.Mem()>
  for nullable: Bool
  {Openapi.typed.of(ps, None{}, nullable) == ps : List<&2, Openapi.Mem()>}

# LAW: a type is mapped in its place
law oas_typed:
  for ps: List<&2, Openapi.Mem()>
  for +typ: Value.Json
  {Openapi.typed.of(ps, Some{typ}, False{})
    == Openapi.put(ps, "type", Openapi.number(typ)) : List<&2, Openapi.Mem()>}

# LAW: and admits null when nullable
law oas_typed_null:
  for ps: List<&2, Openapi.Mem()>
  for +typ: Value.Json
  {Openapi.typed.of(ps, Some{typ}, True{})
    == Openapi.put(ps, "type", Openapi.with.null(Openapi.number(typ)))
    : List<&2, Openapi.Mem()>}

# LAW: a type name admitting null is it and "null"
law oas_null_name:
  for +name: String
  {Openapi.with.null(Value.JStr{name})
    == Json.arr([Value.JStr{name}, Json.str("null")]) : Value.Json}

# LAW: an object schema recurses into its properties
law oas_kids_object:
  for +ps: List<&2, Openapi.Mem()>
  for e: {Openapi.is_str(Openapi.value(ps, "type"), "object") == True{} : Bool}
  {Openapi.kids(ps) == Openapi.kids.props(Openapi.value(ps, "properties"))
    : Openapi.Kids}

# LAW: an array schema into its items
law oas_kids_array:
  for +ps: List<&2, Openapi.Mem()>
  for eo: {Openapi.is_str(Openapi.value(ps, "type"), "object") == False{} : Bool}
  for ea: {Openapi.is_str(Openapi.value(ps, "type"), "array") == True{} : Bool}
  {Openapi.kids(ps) == Openapi.kids.item(Openapi.value(ps, "items"))
    : Openapi.Kids}

# LAW: any other into nothing
law oas_kids_none:
  for +ps: List<&2, Openapi.Mem()>
  for eo: {Openapi.is_str(Openapi.value(ps, "type"), "object") == False{} : Bool}
  for ea: {Openapi.is_str(Openapi.value(ps, "type"), "array") == False{} : Bool}
  {Openapi.kids(ps) == Openapi.NoKids{} : Openapi.Kids}

# LAW: a property's object schema is mapped
law oas_prop_map:
  for cs: Value.Json
  {Openapi.prop.of(Value.JObj{cs}) == Openapi.PMap{} : Openapi.Prop}

# LAW: a boolean schema is kept
law oas_prop_keep:
  for flag: Bool
  {Openapi.prop.of(Value.JBool{flag}) == Openapi.PKeep{} : Openapi.Prop}
