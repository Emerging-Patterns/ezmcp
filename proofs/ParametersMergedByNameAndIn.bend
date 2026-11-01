# proofs of laws/ParametersMergedByNameAndIn.bend
import Base
import 0xa81e161008ecc2f297c0a3065cb9b188/src/value.bend as Value
import ../src/openapi.bend as Openapi
import ../laws/ParametersMergedByNameAndIn.bend as Laws

def Laws.oas_merge_none(_ps):
  {==}

def Laws.oas_merge_one(_one, _rest, _ps):
  {==}

def Laws.oas_put_param_last(_new):
  {==}

def Laws.oas_put_param_same(old, rest, new, e):
  f = Equal.sym(Bool, Openapi.same(old, new), True{}, e)
  %f : {Openapi.params.put.at(_, old, rest, new,
    _u => Openapi.params.put(rest, new)) == new <> rest : List<&2, Value.Json>}
  {==}

def Laws.oas_put_param_other(old, rest, new, e):
  f = Equal.sym(Bool, Openapi.same(old, new), False{}, e)
  %f : {Openapi.params.put.at(_, old, rest, new,
    _u => Openapi.params.put(rest, new))
    == old <> Openapi.params.put(rest, new) : List<&2, Value.Json>}
  {==}

def Laws.oas_same(_left, _right):
  {==}
