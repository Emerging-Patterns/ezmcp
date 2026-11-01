# proofs of laws/SchemasMappedToJsonSchema.bend
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/main.bend as Json
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/openapi.bend as Openapi
import ../laws/SchemasMappedToJsonSchema.bend as Laws

def Laws.oas_number(typ, e):
  f = Equal.sym(Bool, Openapi.is_str(typ, "integer"), True{}, e)
  %f : {Bool.pick(Value.Json, _, Json.str("number"), typ) == Json.str("number")
    : Value.Json}
  {==}

def Laws.oas_number_other(typ, e):
  f = Equal.sym(Bool, Openapi.is_str(typ, "integer"), False{}, e)
  %f : {Bool.pick(Value.Json, _, Json.str("number"), typ) == typ : Value.Json}
  {==}

def Laws.oas_drop_last(_key):
  {==}

def Laws.oas_drop_hit(k2, v2, rest, key, e):
  f = Equal.sym(Bool, String.eq(k2, key), True{}, e)
  %f : {Openapi.drop.at(_, k2, v2, Openapi.drop(rest, key))
    == Openapi.drop(rest, key) : List<&2, Openapi.Mem()>}
  {==}

def Laws.oas_drop_miss(k2, v2, rest, key, e):
  f = Equal.sym(Bool, String.eq(k2, key), False{}, e)
  %f : {Openapi.drop.at(_, k2, v2, Openapi.drop(rest, key))
    == (k2, v2) <> Openapi.drop(rest, key) : List<&2, Openapi.Mem()>}
  {==}

def Laws.oas_typed_none(_ps, _nullable):
  {==}

def Laws.oas_typed(_ps, _typ):
  {==}

def Laws.oas_typed_null(_ps, _typ):
  {==}

def Laws.oas_null_name(_name):
  {==}

def Laws.oas_kids_object(ps, e):
  f = Equal.sym(Bool, Openapi.is_str(Openapi.value(ps, "type"), "object"),
    True{}, e)
  %f : {Openapi.kids.of(_, Openapi.is_str(Openapi.value(ps, "type"), "array"), ps)
    == Openapi.kids.props(Openapi.value(ps, "properties")) : Openapi.Kids}
  {==}

def Laws.oas_kids_array(ps, eo, ea):
  fo = Equal.sym(Bool, Openapi.is_str(Openapi.value(ps, "type"), "object"),
    False{}, eo)
  fa = Equal.sym(Bool, Openapi.is_str(Openapi.value(ps, "type"), "array"),
    True{}, ea)
  %fo : {Openapi.kids.of(_, Openapi.is_str(Openapi.value(ps, "type"), "array"), ps)
    == Openapi.kids.item(Openapi.value(ps, "items")) : Openapi.Kids}
  %fa : {Openapi.kids.array(_, ps) == Openapi.kids.item(Openapi.value(ps, "items"))
    : Openapi.Kids}
  {==}

def Laws.oas_kids_none(ps, eo, ea):
  fo = Equal.sym(Bool, Openapi.is_str(Openapi.value(ps, "type"), "object"),
    False{}, eo)
  fa = Equal.sym(Bool, Openapi.is_str(Openapi.value(ps, "type"), "array"),
    False{}, ea)
  %fo : {Openapi.kids.of(_, Openapi.is_str(Openapi.value(ps, "type"), "array"), ps)
    == Openapi.NoKids{} : Openapi.Kids}
  %fa : {Openapi.kids.array(_, ps) == Openapi.NoKids{} : Openapi.Kids}
  {==}

def Laws.oas_prop_map(_cs):
  {==}

def Laws.oas_prop_keep(_flag):
  {==}
