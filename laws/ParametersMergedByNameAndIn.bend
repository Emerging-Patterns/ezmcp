# `oas/v3.1.0#path-item-object`, parameters: "These parameters can be
# overridden at the operation level, but cannot be removed there ... A
# unique parameter is defined by a combination of a name and location";
# `#operation-object`, parameters: "If a parameter is already defined at the
# Path Item, the new definition will override it but can never remove it."
# An operation's parameters are its Path Item's, then each of its own in
# turn: one with the name and location (`in`) of a parameter already there
# takes the place of the first such, and any other goes last
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/openapi.bend as Openapi

# LAW: an operation with no parameters of its own has its Path Item's
law oas_merge_none:
  for ps: List<&2, Value.Json>
  {Openapi.params.merge([], ps) == ps : List<&2, Value.Json>}

# LAW: each of an operation's parameters is put in turn
law oas_merge_one:
  for one: Value.Json
  for rest: List<&2, Value.Json>
  for ps: List<&2, Value.Json>
  {Openapi.params.merge(one <> rest, ps)
    == Openapi.params.merge(rest, Openapi.params.put(ps, one))
    : List<&2, Value.Json>}

# LAW: a parameter none is the same as goes last
law oas_put_param_last:
  for new: Value.Json
  {Openapi.params.put([], new) == [new] : List<&2, Value.Json>}

# LAW: a parameter takes the place of the first that is the same
law oas_put_param_same:
  for +old: Value.Json
  for rest: List<&2, Value.Json>
  for +new: Value.Json
  for e: {Openapi.same(old, new) == True{} : Bool}
  {Openapi.params.put(old <> rest, new) == new <> rest : List<&2, Value.Json>}

# LAW: and passes one that is not
law oas_put_param_other:
  for +old: Value.Json
  for +rest: List<&2, Value.Json>
  for +new: Value.Json
  for e: {Openapi.same(old, new) == False{} : Bool}
  {Openapi.params.put(old <> rest, new) == old <> Openapi.params.put(rest, new)
    : List<&2, Value.Json>}

# LAW: two parameters are the same when their names and locations are
law oas_same:
  for +left: Value.Json
  for +right: Value.Json
  {Openapi.same(left, right)
    == Bool.and(String.eq(Openapi.str.at(left, "name"),
      Openapi.str.at(right, "name")), String.eq(Openapi.str.at(left, "in"),
      Openapi.str.at(right, "in"))) : Bool}
